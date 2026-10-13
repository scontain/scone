#!/usr/bin/env python3
"""Offer to configure the local SSH alias used by the Kubernetes toolbox."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time

ALIAS = "scone-toolbox-k8s"
DEFAULT_LOCAL_PORT = 2222
BEGIN = f"# >>> {ALIAS} >>>"
END = f"# <<< {ALIAS} <<<"


def inspect_config(path):
    """Read the effective SSH settings and locate an explicit alias, including Includes."""
    if not path.exists():
        return False, {}
    result = subprocess.run(
        ["ssh", "-G", "-v", "-F", str(path), "-o", "CanonicalizeHostname=no", ALIAS],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise ValueError(f"SSH could not parse {path}; the configuration was not changed.")
    settings = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.partition(" ")
        if separator and key in {"hostname", "port", "user", "hostkeyalias"}:
            settings[key] = value.strip()
    files = {path}
    for line in result.stderr.splitlines():
        marker = "Reading configuration data "
        if marker in line:
            files.add(Path(line.split(marker, 1)[1]))
    present = False
    for file in files:
        for line in file.read_text(errors="surrogateescape").splitlines():
            match = re.match(r"^\s*Host(?:\s+|=\s*)(.*)$", line, re.IGNORECASE)
            if match and ALIAS in [value.lower() for value in shlex.split(match[1], comments=True)]:
                present = True
    return present, settings


def correct(settings, local_port=DEFAULT_LOCAL_PORT):
    return (
        settings.get("hostname", "").lower() in {"127.0.0.1", "localhost", "::1"}
        and settings.get("port") == str(local_port)
        and settings.get("user") == "root"
        and settings.get("hostkeyalias") == ALIAS
    )


def remove_managed_block(content):
    """Remove only our marked block, preserving all other configuration bytes."""
    output = []
    inside = False
    for line in content.splitlines(keepends=True):
        if line.strip() == BEGIN.encode():
            if inside:
                raise ValueError("SSH configuration has nested toolbox markers; no changes made.")
            inside = True
        elif line.strip() == END.encode():
            if not inside:
                raise ValueError("SSH configuration has unmatched toolbox markers; no changes made.")
            inside = False
        elif not inside:
            output.append(line)
    if inside:
        raise ValueError("SSH configuration has an unfinished toolbox block; no changes made.")
    return b"".join(output)


def update_config(path, local_port=DEFAULT_LOCAL_PORT):
    """Fully stage and validate the update before atomically replacing the file."""
    destination = path.resolve(strict=True) if path.is_symlink() else path
    original = destination.read_bytes() if destination.exists() else b""
    mode = stat.S_IMODE(destination.stat().st_mode) if destination.exists() else 0o600
    remainder = remove_managed_block(original)
    # The first matching SSH setting wins. Reset to Host * before any original
    # global directives, so their scope remains unchanged for other hosts.
    managed = (
        f"{BEGIN}\n"
        f"Host {ALIAS}\n"
        "  HostName 127.0.0.1\n"
        f"  Port {local_port}\n"
        f"  HostKeyAlias {ALIAS}\n"
        "  User root\n"
        "  ServerAliveInterval 30\n"
        "  StrictHostKeyChecking accept-new\n"
        "Host *\n"
        f"{END}\n\n"
    ).encode()
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".scone-toolbox-ssh.", dir=destination.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(managed + remainder)
            output.flush()
            os.fchmod(output.fileno(), mode)
            os.fsync(output.fileno())
        present, settings = inspect_config(Path(temporary))
        if not present or not correct(settings, local_port):
            raise ValueError("The proposed SSH alias did not validate; no changes made.")
        current = destination.read_bytes() if destination.exists() else b""
        if current != original:
            raise ValueError("SSH configuration changed during setup; please run setup again.")
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def ssh_listener_state(local_port=DEFAULT_LOCAL_PORT):
    """Distinguish a missing listener from an occupied port and an SSH endpoint."""
    try:
        connection = socket.create_connection(("127.0.0.1", local_port), timeout=0.7)
    except ConnectionRefusedError:
        return "missing"
    except OSError as error:
        raise RuntimeError(f"Could not check local port {local_port}: {error}") from error
    with connection:
        try:
            greeting = connection.recv(1024)
        except OSError:
            return "occupied"
    return "ssh" if greeting.startswith(b"SSH-") else "occupied"


def forward_command(namespace, local_port):
    return ["kubectl", "-n", namespace, "port-forward", "deploy/scone-toolbox", f"{local_port}:22"]


def process_identity(pid, command):
    """Identify the command and its start time, so reused PIDs are never trusted."""
    if Path("/proc").is_dir():
        directory = Path("/proc") / str(pid)
        try:
            if directory.stat().st_uid != os.getuid():
                return None
            arguments = [os.fsdecode(part) for part in (directory / "cmdline").read_bytes().rstrip(b"\0").split(b"\0")]
            if arguments != command:
                return None
            # Fields after the final ')' start with field 3; starttime is field 22.
            started = (directory / "stat").read_text().rpartition(") ")[2].split()[19]
            boot = Path("/proc/sys/kernel/random/boot_id").read_text().strip()
            return f"{boot}:{started}"
        except (FileNotFoundError, ProcessLookupError):
            return None
    # macOS and other hosts without procfs can use the same command/start-time check.
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "uid=", "-o", "lstart=", "-o", "command="],
        capture_output=True, text=True, check=False, env={**os.environ, "LC_ALL": "C"},
    )
    fields = result.stdout.strip().split(None, 6)
    if result.returncode or len(fields) != 7 or fields[0] != str(os.getuid()) or fields[6] != " ".join(command):
        return None
    return " ".join(fields[1:6])


def forward_state_path(state_dir, local_port):
    return state_dir / f"port-forward-{local_port}.json"


def save_forward_state(state_dir, local_port, pid, command, log):
    identity = process_identity(pid, command)
    if identity is None:
        raise RuntimeError("Could not identify the new port-forward process; it will be stopped.")
    state = {"pid": pid, "identity": identity, "command": command, "local_port": local_port, "log": str(log)}
    descriptor, temporary = tempfile.mkstemp(prefix=".port-forward-", dir=state_dir)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(state, output)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, forward_state_path(state_dir, local_port))
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def stop_tracked_forward(state_dir, local_port):
    """Stop only a verified process recorded by this helper, never an unrelated listener."""
    path = forward_state_path(state_dir, local_port)
    try:
        state = json.loads(path.read_text())
    except FileNotFoundError:
        return
    if not isinstance(state, dict):
        raise ValueError(f"Invalid port-forward state in {path}; no process was stopped.")
    pid = state.get("pid")
    command = state.get("command")
    if (
        type(pid) is not int or pid <= 0 or pid == os.getpid()
        or not isinstance(command, list) or len(command) != 6
        or not isinstance(command[2], str)
        or command != forward_command(command[2], local_port)
        or state.get("local_port") != local_port
        or not isinstance(state.get("identity"), str)
    ):
        raise ValueError(f"Invalid port-forward state in {path}; no process was stopped.")
    descriptor = None
    try:
        if process_identity(pid, command) == state["identity"]:
            # A pidfd keeps Linux signals tied to this process even if its PID is reused.
            if hasattr(os, "pidfd_open") and hasattr(signal, "pidfd_send_signal"):
                descriptor = os.pidfd_open(pid)
            if process_identity(pid, command) == state["identity"]:
                def send(signum):
                    if descriptor is not None:
                        signal.pidfd_send_signal(descriptor, signum)
                    elif process_identity(pid, command) == state["identity"]:
                        os.kill(pid, signum)

                send(signal.SIGTERM)
                deadline = time.monotonic() + 3
                while process_identity(pid, command) == state["identity"] and time.monotonic() < deadline:
                    time.sleep(0.1)
                if process_identity(pid, command) == state["identity"]:
                    send(signal.SIGKILL)
                    deadline = time.monotonic() + 3
                    while process_identity(pid, command) == state["identity"] and time.monotonic() < deadline:
                        time.sleep(0.1)
                    if process_identity(pid, command) == state["identity"]:
                        raise RuntimeError(f"Could not stop the previous port-forward (PID {pid}).")
                print(f"Stopped the previous toolbox port-forward on local port {local_port} (PID {pid}).")
    except ProcessLookupError:
        pass
    finally:
        if descriptor is not None:
            os.close(descriptor)
    path.unlink(missing_ok=True)


def start_port_forward(namespace, state_dir, timeout, local_port=DEFAULT_LOCAL_PORT):
    """Start an independent kubectl process and verify its listener and SSH banner."""
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, filename = tempfile.mkstemp(prefix="port-forward-", suffix=".log", dir=state_dir)
    log = Path(filename)
    with os.fdopen(descriptor, "ab", buffering=0) as output:
        process = subprocess.Popen(
            forward_command(namespace, local_port),
            stdin=subprocess.DEVNULL,
            stdout=output,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    try:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f"kubectl port-forward exited; see {log}")
            if b"Forwarding from " in log.read_bytes() and ssh_listener_state(local_port) == "ssh":
                if process.poll() is None:
                    save_forward_state(state_dir, local_port, process.pid, forward_command(namespace, local_port), log)
                    return process.pid, log
            time.sleep(0.1)
        raise RuntimeError(f"Timed out waiting for toolbox SSH forwarding; see {log}")
    except BaseException:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        raise


def ensure_port_forward(namespace, state_dir, timeout, local_port=DEFAULT_LOCAL_PORT):
    stop_tracked_forward(state_dir, local_port)
    listener = ssh_listener_state(local_port)
    if listener == "ssh":
        print(f"An SSH listener is already reachable on local port {local_port}.")
        return True
    if listener == "occupied":
        raise RuntimeError(f"Local port {local_port} is occupied by a service that did not return an SSH banner.")
    print(f"No SSH listener is running on local port {local_port}. The alias needs a kubectl port-forward.")
    try:
        answer = input(f"Start SSH forwarding for the toolbox in namespace {namespace} in the background? [y/N] ")
    except EOFError:
        answer = ""
    if answer.strip().lower() not in {"y", "yes"}:
        return False
    print("Starting kubectl port-forward...", flush=True)
    pid, log = start_port_forward(namespace, state_dir, timeout, local_port)
    print(f"SSH forwarding is ready and will continue after this script exits (PID {pid}).")
    print(f"Port-forward log: {log}")
    print(f"To stop this forwarding process: kill {pid}")
    return True


def print_login(namespace, config, alias_ready, forward_ready=False, local_port=DEFAULT_LOCAL_PORT):
    print("\nTo log in to the SCONE toolbox:")
    if forward_ready:
        print(f"  Local port {local_port} is ready. Connect with:")
    else:
        print("  Start this port-forward in one terminal and keep it running:")
        print(f"    kubectl -n {shlex.quote(namespace)} port-forward deploy/scone-toolbox {local_port}:22")
        print("  Then connect from another terminal:")
    if alias_ready:
        default = Path.home() / ".ssh/config"
        option = "" if config == default else f"-F {shlex.quote(str(config))} "
        print(f"    ssh {option}{ALIAS}")
        print("  Or connect directly:")
    print(f"    ssh -o HostKeyAlias={ALIAS} -p {local_port} root@127.0.0.1")
    print("  Use the private key corresponding to the toolbox's configured SSH public key.")
    if forward_ready:
        print("  After the toolbox pod is replaced, rerun SSH setup to refresh the tracked forwarding process.")
    print(f"  After a trusted image upgrade changes host keys, remove the old key: ssh-keygen -R {ALIAS}")


def local_port_number(value):
    try:
        port = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("local port must be an integer from 1 to 65535") from error
    if not 1 <= port <= 65535:
        raise argparse.ArgumentTypeError("local port must be an integer from 1 to 65535")
    return port


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path.home() / ".ssh/config")
    parser.add_argument("--local-port", type=local_port_number, default=os.environ.get("TOOLBOX_SSH_PORT", str(DEFAULT_LOCAL_PORT)))
    parser.add_argument("--namespace", default=os.environ.get("CLI_NAMESPACE", "scone-tools"))
    parser.add_argument("--non-interactive", action="store_true", help="Report SSH setup without prompting or changing files")
    parser.add_argument("--ensure-forward", action="store_true", help="Refresh a tracked SSH port-forward and offer to start forwarding")
    parser.add_argument("--state-dir", type=Path, default=Path.home() / ".cache/scone-toolbox")
    parser.add_argument("--forward-timeout", type=float, default=15, help="Seconds to wait for a newly started SSH port-forward")
    args = parser.parse_args()
    config = args.config.expanduser().absolute()
    local_port = args.local_port
    alias_ready = False
    forward_ready = False
    status = 0
    try:
        present, settings = inspect_config(config)
        alias_ready = present and correct(settings, local_port)
        if alias_ready:
            print(f"SSH alias {ALIAS} already points to root@{settings['hostname']}:{local_port} with HostKeyAlias {ALIAS}.")
        else:
            action = "Correct" if present else "Add"
            if present:
                print(
                    f"SSH alias {ALIAS} currently resolves to "
                    f"{settings.get('user', '?')}@{settings.get('hostname', '?')}:{settings.get('port', '?')}."
                )
            if args.non_interactive:
                print(f"SSH alias needs setup; skipping changes in non-interactive mode ({config}).")
            else:
                try:
                    answer = input(f"{action} SSH alias {ALIAS} in {config} for root@127.0.0.1:{local_port} with HostKeyAlias {ALIAS}? [y/N] ")
                except EOFError:
                    answer = ""
                if answer.strip().lower() in {"y", "yes"}:
                    update_config(config, local_port)
                    alias_ready = True
                    print(f"SSH alias {ALIAS} configured in {config}.")
                else:
                    print("SSH configuration left unchanged.")
        if args.ensure_forward and not args.non_interactive:
            forward_ready = ensure_port_forward(args.namespace, args.state_dir.expanduser(), args.forward_timeout, local_port)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"SSH setup failed: {error}", file=sys.stderr)
        status = 1
    print_login(args.namespace, config, alias_ready, forward_ready, local_port)
    return status


if __name__ == "__main__":
    sys.exit(main())
