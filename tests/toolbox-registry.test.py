#!/usr/bin/env python3
"""Check registry Secret updates and the Docker login that consumes them."""

from contextlib import redirect_stderr, redirect_stdout
import base64
import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("toolbox_registry", ROOT / "scripts/reconcile-toolbox-registry.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ToolboxRegistryTest(unittest.TestCase):
    registry = "example.invalid:5443"
    username = "selected-user"
    token = "token' \" $literal; $(touch SHOULD_NOT_EXIST)\nsecond\\line"

    def secrets(self):
        return helper.registry_secrets("test-tools", self.registry, self.username, self.token)

    def test_pull_secrets_and_startup_use_identical_credentials(self):
        items = {item["metadata"]["name"]: item for item in self.secrets()["items"]}
        self.assertEqual(set(items), {"scone-registry", "sconeapps", "scone-registry-env"})
        for name, item in items.items():
            self.assertEqual(item["metadata"]["namespace"], "test-tools")
            if name == "scone-registry-env":
                self.assertEqual(item["type"], "Opaque")
                continue
            self.assertEqual(item["type"], "kubernetes.io/dockerconfigjson")
            config = json.loads(base64.b64decode(item["data"][".dockerconfigjson"]))
            self.assertEqual(set(config["auths"]), {self.registry})
            entry = config["auths"][self.registry]
            self.assertEqual(entry["username"], self.username)
            self.assertEqual(entry["password"], self.token)
            self.assertEqual(base64.b64decode(entry["auth"]).decode(), f"{self.username}:{self.token}")

    def main_with(self, result):
        values = {"REGISTRY": self.registry, "REGISTRY_USER": self.username, "REGISTRY_TOKEN": self.token}
        output, errors = io.StringIO(), io.StringIO()
        with patch.dict(helper.os.environ, values), \
             patch.object(helper.sys, "argv", ["reconcile-toolbox-registry.py", "--namespace", "test-tools"]), \
             patch.object(helper.subprocess, "run", return_value=result) as run, \
             redirect_stdout(output), redirect_stderr(errors):
            status = helper.main()
        return status, run, output.getvalue(), errors.getvalue()

    def test_update_uses_stdin_without_putting_credentials_in_arguments(self):
        status, run, output, errors = self.main_with(Mock(returncode=0))
        self.assertEqual(status, 0, errors)
        args, options = run.call_args
        self.assertEqual(args, (["kubectl", "apply", "-f", "-"],))
        self.assertEqual(json.loads(options["input"]), self.secrets())
        self.assertNotIn(self.token, output + errors)
        self.assertNotIn(self.username, output + errors)

    def test_update_failure_does_not_echo_secret_payloads(self):
        payload = json.dumps(self.secrets())
        status, run, output, errors = self.main_with(Mock(returncode=1, stdout=payload, stderr=payload))
        self.assertEqual(status, 1)
        run.assert_called_once()
        self.assertIn("Could not update registry secrets", errors)
        self.assertNotIn(self.token, output + errors)
        self.assertNotIn(base64.b64encode(self.token.encode()).decode(), output + errors)
        self.assertNotIn(payload, output + errors)

    def test_empty_credentials_fail_before_contacting_kubernetes(self):
        with patch.dict(helper.os.environ, {"REGISTRY": self.registry, "REGISTRY_USER": self.username, "REGISTRY_TOKEN": ""}), \
             patch.object(helper.sys, "argv", ["reconcile-toolbox-registry.py", "--namespace", "test-tools"]), \
             patch.object(helper.subprocess, "run") as run, redirect_stderr(io.StringIO()):
            self.assertEqual(helper.main(), 1)
        run.assert_not_called()

    def login_from_startup_secret(self, include_registry=True):
        item = self.secrets()["items"][-1]
        environment = base64.b64decode(item["data"]["scone-registry-env"]).decode()
        if not include_registry:
            environment = "\n".join(environment.splitlines()[1:]) + "\n"
        # Run only the actual login block, avoiding sshd and kubeconfig setup.
        entrypoint = (ROOT / "docker-entrypoint.sh").read_text()
        start = entrypoint.index('if [[ -n "${REGISTRY_TOKEN:-}"')
        end = entrypoint.index("\nfi", start) + len("\nfi")
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            credentials = work / "startup.env"
            credentials.write_text(environment)
            docker = work / "docker"
            docker.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, pathlib, sys\n"
                "pathlib.Path(os.environ['MOCK_LOGIN']).write_text(json.dumps({'args': sys.argv[1:], 'password': sys.stdin.read()}))\n"
            )
            docker.chmod(0o700)
            inherited = {**os.environ, "PATH": str(work) + os.pathsep + os.environ["PATH"], "MOCK_LOGIN": str(work / "login.json")}
            inherited.pop("REGISTRY", None)
            result = subprocess.run(
                ["bash", "-euo", "pipefail", "-c", f"source {shlex.quote(str(credentials))}\n{entrypoint[start:end]}"],
                env=inherited, cwd=work, capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((work / "SHOULD_NOT_EXIST").exists())
            self.assertNotIn(self.token, result.stdout + result.stderr)
            return json.loads((work / "login.json").read_text())

    def test_entrypoint_logs_in_with_selected_registry_and_literal_token(self):
        login = self.login_from_startup_secret()
        self.assertEqual(login["args"], ["login", self.registry, "--username", self.username, "--password-stdin"])
        self.assertEqual(login["password"], self.token + "\n")

    def test_entrypoint_accepts_legacy_secret_without_registry(self):
        login = self.login_from_startup_secret(include_registry=False)
        self.assertEqual(login["args"][1], "registry.scontain.com")
        self.assertEqual(login["password"], self.token + "\n")


if __name__ == "__main__":
    unittest.main()
