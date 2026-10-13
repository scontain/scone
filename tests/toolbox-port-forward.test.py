#!/usr/bin/env python3
"""Check forwarding consent, listener checks, detached startup, and failure cleanup."""

from contextlib import redirect_stdout
import importlib.util
import io
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
            start.assert_called_once_with("test-tools", self.state, 15)
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
             patch.object(helper, "ssh_listener_state", return_value="ssh"):
            pid, log = helper.start_port_forward("test-tools", self.state, 15)
        self.assertEqual(pid, 1234)
        self.assertTrue(log.exists())
        process.terminate.assert_not_called()

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
