#!/usr/bin/env python3
"""Offer to configure the local SSH alias used by the Kubernetes toolbox."""

import argparse
import os
from pathlib import Path
import re
import shlex
import socket
import stat
import subprocess
import sys
import tempfile
import time

ALIAS = "scone-toolbox-k8s"
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
        if separator and key in {"hostname", "port", "user"}:
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


def correct(settings):
    return (
        settings.get("hostname", "").lower() in {"127.0.0.1", "localhost", "::1"}
        and settings.get("port") == "2222"
        and settings.get("user") == "root"
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


def update_config(path):
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
        "  Port 2222\n"
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
        if not present or not correct(settings):
            raise ValueError("The proposed SSH alias did not validate; no changes made.")
        current = destination.read_bytes() if destination.exists() else b""
        if current != original:
            raise ValueError("SSH configuration changed during setup; please run setup again.")
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def ssh_listener_state():
    """Distinguish a missing listener from an occupied port and an SSH endpoint."""
    try:
        connection = socket.create_connection(("127.0.0.1", 2222), timeout=0.7)
    except ConnectionRefusedError:
        return "missing"
    except OSError as error:
        raise RuntimeError(f"Could not check local port 2222: {error}") from error
    with connection:
        try:
            greeting = connection.recv(1024)
        except OSError:
            return "occupied"
    return "ssh" if greeting.startswith(b"SSH-") else "occupied"


def start_port_forward(namespace, state_dir, timeout):
    """Start an independent kubectl process and verify its listener and SSH banner."""
    state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, filename = tempfile.mkstemp(prefix="port-forward-", suffix=".log", dir=state_dir)
    log = Path(filename)
    with os.fdopen(descriptor, "ab", buffering=0) as output:
        process = subprocess.Popen(
            ["kubectl", "-n", namespace, "port-forward", "deploy/scone-toolbox", "2222:22"],
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
            if b"Forwarding from " in log.read_bytes() and ssh_listener_state() == "ssh":
                if process.poll() is None:
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


def ensure_port_forward(namespace, state_dir, timeout):
    listener = ssh_listener_state()
    if listener == "ssh":
        print("An SSH listener is already reachable on local port 2222.")
        return True
    if listener == "occupied":
        raise RuntimeError("Local port 2222 is occupied by a service that did not return an SSH banner.")
    print("No SSH listener is running on local port 2222. The alias needs a kubectl port-forward.")
    try:
        answer = input(f"Start SSH forwarding for the toolbox in namespace {namespace} in the background? [y/N] ")
    except EOFError:
        answer = ""
    if answer.strip().lower() not in {"y", "yes"}:
        return False
    print("Starting kubectl port-forward...", flush=True)
    pid, log = start_port_forward(namespace, state_dir, timeout)
    print(f"SSH forwarding is ready and will continue after this script exits (PID {pid}).")
    print(f"Port-forward log: {log}")
    print(f"To stop this forwarding process: kill {pid}")
    return True


def print_login(namespace, config, alias_ready, forward_ready=False):
    print("\nTo log in to the SCONE toolbox:")
    if forward_ready:
        print("  Local port 2222 is ready. Connect with:")
    else:
        print("  Start this port-forward in one terminal and keep it running:")
        print(f"    kubectl -n {shlex.quote(namespace)} port-forward deploy/scone-toolbox 2222:22")
        print("  Then connect from another terminal:")
    if alias_ready:
        default = Path.home() / ".ssh/config"
        option = "" if config == default else f"-F {shlex.quote(str(config))} "
        print(f"    ssh {option}{ALIAS}")
        print("  Or connect directly:")
    print("    ssh -p 2222 root@127.0.0.1")
    print("  Use the private key corresponding to the toolbox's configured SSH public key.")
    if forward_ready:
        print("  If the toolbox pod is replaced, restart forwarding with:")
        print(f"    kubectl -n {shlex.quote(namespace)} port-forward deploy/scone-toolbox 2222:22")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path.home() / ".ssh/config")
    parser.add_argument("--namespace", default=os.environ.get("CLI_NAMESPACE", "scone-tools"))
    parser.add_argument("--non-interactive", action="store_true", help="Report SSH setup without prompting or changing files")
    parser.add_argument("--ensure-forward", action="store_true", help="Offer to start a missing local SSH port-forward")
    parser.add_argument("--state-dir", type=Path, default=Path.home() / ".cache/scone-toolbox")
    parser.add_argument("--forward-timeout", type=float, default=15, help="Seconds to wait for a newly started SSH port-forward")
    args = parser.parse_args()
    config = args.config.expanduser().absolute()
    alias_ready = False
    forward_ready = False
    status = 0
    try:
        present, settings = inspect_config(config)
        alias_ready = present and correct(settings)
        if alias_ready:
            print(f"SSH alias {ALIAS} already points to root@{settings['hostname']}:2222.")
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
                    answer = input(f"{action} SSH alias {ALIAS} in {config} for root@127.0.0.1:2222? [y/N] ")
                except EOFError:
                    answer = ""
                if answer.strip().lower() in {"y", "yes"}:
                    update_config(config)
                    alias_ready = True
                    print(f"SSH alias {ALIAS} configured in {config}.")
                else:
                    print("SSH configuration left unchanged.")
        if args.ensure_forward and not args.non_interactive:
            forward_ready = ensure_port_forward(args.namespace, args.state_dir.expanduser(), args.forward_timeout)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"SSH setup failed: {error}", file=sys.stderr)
        status = 1
    print_login(args.namespace, config, alias_ready, forward_ready)
    return status


if __name__ == "__main__":
    sys.exit(main())
