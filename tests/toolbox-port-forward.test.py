#!/usr/bin/env python3
"""Check forwarding consent, listener checks, detached startup, and failure cleanup."""

from contextlib import redirect_stdout
import importlib.util
import io
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("toolbox_ssh", ROOT / "scripts/configure-toolbox-ssh.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ToolboxForwardTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.state = Path(self.directory.name) / "state"

    def ensure(self):
        with redirect_stdout(io.StringIO()):
            return helper.ensure_port_forward("test-tools", self.state, 15)

    def test_connection_refused_is_reported_as_missing(self):
        with patch.object(helper.socket, "create_connection", side_effect=ConnectionRefusedError):
            self.assertEqual(helper.ssh_listener_state(), "missing")

    def test_ssh_banner_is_required(self):
        for banner, expected in ((b"SSH-2.0-OpenSSH\r\n", "ssh"), (b"HTTP/1.1 200 OK\r\n", "occupied")):
            with self.subTest(banner=banner):
                connection = Mock()
                connection.__enter__ = Mock(return_value=connection)
                connection.__exit__ = Mock(return_value=False)
                connection.recv.return_value = banner
                with patch.object(helper.socket, "create_connection", return_value=connection):
                    self.assertEqual(helper.ssh_listener_state(), expected)

    def test_existing_listener_does_not_prompt_or_start_another_process(self):
        with patch.object(helper, "ssh_listener_state", return_value="ssh"), \
             patch("builtins.input") as prompt, \
             patch.object(helper, "start_port_forward") as start:
            self.assertTrue(self.ensure())
            prompt.assert_not_called()
            start.assert_not_called()

    def test_occupied_port_is_not_taken_over(self):
        with patch.object(helper, "ssh_listener_state", return_value="occupied"), \
             patch("builtins.input") as prompt, \
             patch.object(helper, "start_port_forward") as start:
            with self.assertRaisesRegex(RuntimeError, "occupied"):
                self.ensure()
            prompt.assert_not_called()
            start.assert_not_called()

    def test_declining_start_creates_no_files_or_process(self):
        with patch.object(helper, "ssh_listener_state", return_value="missing"), \
             patch("builtins.input", return_value="n"), \
             patch.object(helper, "start_port_forward") as start:
            self.assertFalse(self.ensure())
            start.assert_not_called()
            self.assertFalse(self.state.exists())

    def test_approved_start_uses_namespace_and_reports_readiness(self):
        with patch.object(helper, "ssh_listener_state", return_value="missing"), \
             patch("builtins.input", return_value="yes"), \
             patch.object(helper, "start_port_forward", return_value=(1234, self.state / "forward.log")) as start:
            output = io.StringIO()
            with redirect_stdout(output):
                self.assertTrue(helper.ensure_port_forward("test-tools", self.state, 15))
            start.assert_called_once_with("test-tools", self.state, 15, 2222)
            self.assertIn("PID 1234", output.getvalue())
            self.assertIn("will continue after this script exits", output.getvalue())

    def test_startup_detaches_and_requires_forward_log_and_ssh_banner(self):
        process = Mock(pid=1234)
        process.poll.return_value = None

        def spawned(command, **options):
            self.assertEqual(command, ["kubectl", "-n", "test-tools", "port-forward", "deploy/scone-toolbox", "2222:22"])
            self.assertIs(options["start_new_session"], True)
            self.assertEqual(options["stdin"], subprocess.DEVNULL)
            self.assertEqual(options["stderr"], subprocess.STDOUT)
            options["stdout"].write(b"Forwarding from 127.0.0.1:2222 -> 22\n")
            return process

        with patch.object(helper.subprocess, "Popen", side_effect=spawned), \
             patch.object(helper, "ssh_listener_state", return_value="ssh"), \
             patch.object(helper, "process_identity", return_value="original-process"):
            pid, log = helper.start_port_forward("test-tools", self.state, 15)
        self.assertEqual(pid, 1234)
        self.assertTrue(log.exists())
        recorded = json.loads(helper.forward_state_path(self.state, 2222).read_text())
        self.assertEqual(recorded["pid"], 1234)
        self.assertEqual(recorded["identity"], "original-process")
        self.assertEqual(recorded["command"], helper.forward_command("test-tools", 2222))
        process.terminate.assert_not_called()

    def save_state(self, pid=1234, port=2222):
        self.state.mkdir(parents=True, exist_ok=True)
        record = {
            "pid": pid, "identity": "original-process", "local_port": port,
            "command": helper.forward_command("test-tools", port), "log": "forward.log",
        }
        path = helper.forward_state_path(self.state, port)
        path.write_text(json.dumps(record))
        return path

    def test_tracked_forward_is_stopped_before_a_new_listener_is_checked(self):
        path = self.save_state()
        events = []
        def signal_sent(fd, signum):
            self.assertEqual((fd, signum), (42, signal.SIGTERM))
            events.append("stopped")
        def listener(port):
            self.assertEqual(events, ["stopped"])
            self.assertEqual(port, 2222)
            return "missing"
        with patch.object(helper, "process_identity", side_effect=["original-process", "original-process", None, None]), \
             patch.object(helper.os, "pidfd_open", return_value=42, create=True), \
             patch.object(helper.signal, "pidfd_send_signal", side_effect=signal_sent, create=True), \
             patch.object(helper.os, "close") as close, \
             patch.object(helper, "ssh_listener_state", side_effect=listener), \
             patch("builtins.input", return_value="yes"), \
             patch.object(helper, "start_port_forward", return_value=(4567, self.state / "new.log")) as start:
            self.assertTrue(self.ensure())
        self.assertFalse(path.exists())
        close.assert_called_once_with(42)
        start.assert_called_once_with("test-tools", self.state, 15, 2222)

    def test_reused_pid_or_dead_forward_is_not_signalled(self):
        for identity in ("different-process", None):
            with self.subTest(identity=identity):
                path = self.save_state()
                with patch.object(helper, "process_identity", return_value=identity), \
                     patch.object(helper.os, "kill") as kill, \
                     patch.object(helper.os, "pidfd_open", create=True) as opened, \
                     redirect_stdout(io.StringIO()):
                    helper.stop_tracked_forward(self.state, 2222)
                kill.assert_not_called()
                opened.assert_not_called()
                self.assertFalse(path.exists())

    def test_pid_changed_while_opening_handle_is_not_signalled(self):
        self.save_state()
        with patch.object(helper, "process_identity", side_effect=["original-process", "different-process"]), \
             patch.object(helper.os, "pidfd_open", return_value=42, create=True), \
             patch.object(helper.signal, "pidfd_send_signal", create=True) as send, \
             patch.object(helper.os, "close"):
            helper.stop_tracked_forward(self.state, 2222)
        send.assert_not_called()

    def test_invalid_state_cannot_stop_any_process(self):
        for record in ([], {"pid": -1}, {"pid": 1234, "command": ["sleep", "30"]}):
            self.state.mkdir(exist_ok=True)
            helper.forward_state_path(self.state, 2222).write_text(json.dumps(record))
            with patch.object(helper.os, "kill") as kill, \
                 patch.object(helper, "process_identity") as identity:
                with self.assertRaisesRegex(ValueError, "Invalid port-forward state"):
                    helper.stop_tracked_forward(self.state, 2222)
                kill.assert_not_called()
                identity.assert_not_called()

    def test_custom_port_is_used_for_connection_startup_and_state(self):
        connection = Mock()
        connection.__enter__ = Mock(return_value=connection)
        connection.__exit__ = Mock(return_value=False)
        connection.recv.return_value = b"SSH-2.0-OpenSSH\r\n"
        with patch.object(helper.socket, "create_connection", return_value=connection) as connect:
            self.assertEqual(helper.ssh_listener_state(2200), "ssh")
        connect.assert_called_once_with(("127.0.0.1", 2200), timeout=0.7)
        process = Mock(pid=1234)
        process.poll.return_value = None
        def spawned(command, **options):
            self.assertEqual(command[-1], "2200:22")
            options["stdout"].write(b"Forwarding from 127.0.0.1:2200 -> 22\n")
            return process
        with patch.object(helper.subprocess, "Popen", side_effect=spawned), \
             patch.object(helper, "process_identity", return_value="original-process"), \
             patch.object(helper, "ssh_listener_state", return_value="ssh") as listener:
            helper.start_port_forward("test-tools", self.state, 15, 2200)
        listener.assert_called_once_with(2200)
        self.assertTrue(helper.forward_state_path(self.state, 2200).exists())
        self.assertFalse(helper.forward_state_path(self.state, 2222).exists())

    def test_full_disk_preserves_prior_state_and_stops_untracked_child(self):
        path = self.save_state(pid=4567)
        original = path.read_bytes()
        process = Mock(pid=1234)
        process.poll.return_value = None
        def spawned(command, **options):
            options["stdout"].write(b"Forwarding from 127.0.0.1:2222 -> 22\n")
            return process
        with patch.object(helper.subprocess, "Popen", side_effect=spawned), \
             patch.object(helper, "process_identity", return_value="original-process"), \
             patch.object(helper, "ssh_listener_state", return_value="ssh"), \
             patch.object(helper.os, "fsync", side_effect=OSError("simulated full disk")):
            with self.assertRaisesRegex(OSError, "simulated full disk"):
                helper.start_port_forward("test-tools", self.state, 15)
        process.terminate.assert_called_once()
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(list(self.state.glob(".port-forward-*")), [])

    @unittest.skipUnless(hasattr(os, "mkfifo"), "A FIFO is required for the controlled process check")
    def test_recorded_real_process_is_stopped_and_state_is_removed(self):
        # cat blocks on our FIFO but carries the exact forwarding argv. This
        # exercises real PID identity and signals without contacting Kubernetes.
        fifo = Path(self.directory.name) / "fake-namespace"
        os.mkfifo(fifo)
        command = helper.forward_command(str(fifo), 2222)
        process = subprocess.Popen(command, executable="/bin/cat")
        try:
            self.state.mkdir()
            helper.save_forward_state(self.state, 2222, process.pid, command, self.state / "forward.log")
            with redirect_stdout(io.StringIO()):
                helper.stop_tracked_forward(self.state, 2222)
            self.assertEqual(process.wait(timeout=3), -signal.SIGTERM)
            self.assertFalse(helper.forward_state_path(self.state, 2222).exists())
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=3)

    def test_identity_checks_a_real_process_and_rejects_different_arguments(self):
        process = subprocess.Popen(["sleep", "30"])
        try:
            self.assertIsNotNone(helper.process_identity(process.pid, ["sleep", "30"]))
            self.assertIsNone(helper.process_identity(process.pid, ["sleep", "31"]))
        finally:
            process.terminate()
            process.wait(timeout=3)
        self.assertIsNone(helper.process_identity(process.pid, ["sleep", "30"]))

    def test_timeout_stops_only_the_new_process(self):
        process = Mock(pid=1234)
        process.poll.return_value = None
        with patch.object(helper.subprocess, "Popen", return_value=process), \
             patch.object(helper.time, "monotonic", side_effect=[0.0, 0.1, 0.3]), \
             patch.object(helper.time, "sleep"), \
             patch.object(helper, "ssh_listener_state", return_value="ssh") as listener:
            with self.assertRaisesRegex(RuntimeError, "Timed out"):
                helper.start_port_forward("test-tools", self.state, 0.2)
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=3)
        listener.assert_not_called()

    def test_early_exit_reports_failure(self):
        process = Mock()
        process.poll.return_value = 1
        with patch.object(helper.subprocess, "Popen", return_value=process):
            with self.assertRaisesRegex(RuntimeError, "port-forward exited"):
                helper.start_port_forward("test-tools", self.state, 15)
        process.terminate.assert_not_called()

    def test_non_interactive_cli_does_not_start_forwarding(self):
        config = Path(self.directory.name) / "config"
        config.write_text("Host scone-toolbox-k8s\n HostName 127.0.0.1\n Port 2222\n User root\n")
        arguments = ["configure-toolbox-ssh.py", "--config", str(config), "--ensure-forward", "--non-interactive"]
        with patch.object(helper.sys, "argv", arguments), \
             patch.object(helper, "ensure_port_forward") as ensure, \
             redirect_stdout(io.StringIO()) as output:
            self.assertEqual(helper.main(), 0)
            ensure.assert_not_called()
            self.assertIn("Start this port-forward", output.getvalue())


if __name__ == "__main__":
    unittest.main()
