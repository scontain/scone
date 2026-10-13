#!/usr/bin/env python3
"""Check consent, effective SSH options, and preservation of existing configuration."""

import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/configure-toolbox-ssh.py"
ALIAS = "scone-toolbox-k8s"
CORRECT = f"Host {ALIAS}\n  HostName 127.0.0.1\n  Port 2222\n  User root\n"
WRONG = f"Host {ALIAS}\n  HostName old.example\n  Port 22\n  User ubuntu\n"


@unittest.skipUnless(shutil.which("ssh"), "OpenSSH is required")
class ToolboxSshTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.config = self.work / ".ssh/config"

    def save(self, content):
        self.config.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.config.write_text(content)
        self.config.chmod(0o600)

    def run_helper(self, answer="", *options, environment=None):
        return subprocess.run(
            ["python3", str(HELPER), "--config", str(self.config), "--namespace", "ssh-test", *options],
            input=answer,
            capture_output=True,
            text=True,
            env=environment,
            check=False,
        )

    def effective(self, host=ALIAS):
        result = subprocess.run(
            ["ssh", "-G", "-F", str(self.config), host],
            input="", capture_output=True, text=True, check=True,
        )
        return dict(line.split(" ", 1) for line in result.stdout.splitlines() if " " in line)

    def assert_correct(self):
        settings = self.effective()
        self.assertEqual(settings["hostname"], "127.0.0.1")
        self.assertEqual(settings["port"], "2222")
        self.assertEqual(settings["user"], "root")

    def test_missing_alias_requires_consent(self):
        result = self.run_helper("n\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Add SSH alias", result.stdout)
        self.assertFalse(self.config.exists())
        self.assertIn("kubectl -n ssh-test port-forward deploy/scone-toolbox 2222:22", result.stdout)
        self.assertIn("ssh -p 2222 root@127.0.0.1", result.stdout)

    def test_approved_add_is_private_and_idempotent(self):
        result = self.run_helper("yes\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_correct()
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.config.parent.stat().st_mode), 0o700)
        original = self.config.read_bytes()
        mtime = self.config.stat().st_mtime_ns
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already points", result.stdout)
        self.assertNotIn("[y/N]", result.stdout)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual(self.config.stat().st_mtime_ns, mtime)

    def test_wrong_alias_declined_is_preserved(self):
        self.save(WRONG)
        original = self.config.read_bytes()
        result = self.run_helper("n\n")
        self.assertIn("Correct SSH alias", result.stdout)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertIn("ssh -p 2222 root@127.0.0.1", result.stdout)

    def test_correction_preserves_global_and_other_host_settings(self):
        original = (
            "# Preserve this comment: café\nServerAliveInterval 72\n"
            "Host *\n  Port 2200\n  User ubuntu\n"
            f"Host {ALIAS} shared-alias\n  HostName old.example\n  IdentityFile /example/key\n"
            "Host other\n  HostName other.example\n"
        )
        self.save(original)
        other = self.effective("other")
        shared = self.effective("shared-alias")
        result = self.run_helper("y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_correct()
        self.assertIn(original.encode(), self.config.read_bytes())
        self.assertEqual(self.effective("other"), other)
        self.assertEqual(self.effective("shared-alias"), shared)

    def test_included_correct_alias_is_recognized(self):
        included = self.work / "included.conf"
        included.write_text(CORRECT)
        self.save(f'Include "{included}"\n')
        original = self.config.read_bytes()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already points", result.stdout)
        self.assertEqual(self.config.read_bytes(), original)

    def test_included_wrong_alias_can_be_corrected_without_editing_include(self):
        included = self.work / "included.conf"
        included.write_text(WRONG)
        self.save(f'Include "{included}"\n')
        result = self.run_helper("y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Correct SSH alias", result.stdout)
        self.assertEqual(included.read_text(), WRONG)
        self.assert_correct()

    def test_non_interactive_and_eof_do_not_modify_configuration(self):
        self.save(WRONG)
        original = self.config.read_bytes()
        for options in (("--non-interactive",), ()):
            with self.subTest(options=options):
                result = self.run_helper("", *options)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.config.read_bytes(), original)
                self.assertIn("ssh -p 2222 root@127.0.0.1", result.stdout)

    def test_correct_localhost_alias_is_accepted(self):
        self.save(CORRECT.replace("127.0.0.1", "localhost"))
        original = self.config.read_bytes()
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("[y/N]", result.stdout)
        self.assertEqual(self.config.read_bytes(), original)

    def test_existing_managed_block_is_replaced_once(self):
        self.save(
            f"# >>> {ALIAS} >>>\n{WRONG}# <<< {ALIAS} <<<\n"
            "Host other\n  HostName other.example\n"
        )
        result = self.run_helper("y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_correct()
        self.assertEqual(self.config.read_text().count(f"# >>> {ALIAS} >>>"), 1)
        self.assertEqual(self.effective("other")["hostname"], "other.example")

    def test_invalid_configuration_is_preserved(self):
        self.save("InvalidSshDirective value\n" + WRONG)
        original = self.config.read_bytes()
        result = self.run_helper("y\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertIn("ssh -p 2222 root@127.0.0.1", result.stdout)

    def test_symlink_is_preserved(self):
        target = self.work / "target.conf"
        target.write_text(WRONG)
        target.chmod(0o600)
        self.config.parent.mkdir(mode=0o700)
        self.config.symlink_to(target)
        result = self.run_helper("y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.config.is_symlink())
        self.assert_correct()

    def test_full_disk_before_replace_preserves_existing_file(self):
        self.save(WRONG)
        original = self.config.read_bytes()
        fault = self.work / "fault"
        fault.mkdir()
        (fault / "sitecustomize.py").write_text(
            "import errno, os\n"
            "def full_disk(fd):\n"
            "    raise OSError(errno.ENOSPC, 'simulated full disk')\n"
            "os.fsync = full_disk\n"
        )
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(fault)
        result = self.run_helper("y\n", environment=environment)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("simulated full disk", result.stderr)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertEqual(list(self.config.parent.glob(".scone-toolbox-ssh.*")), [])
        self.assertIn("ssh -p 2222 root@127.0.0.1", result.stdout)


if __name__ == "__main__":
    unittest.main()
