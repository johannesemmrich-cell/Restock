#!/usr/bin/env python3
"""Strukturtest für .github/workflows/asc-check.yml (Issue #276): nur lesend, Secrets nur im env, keine Ausdrücke im Skript."""
import re, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github/workflows/asc-check.yml"


class AscCheckWorkflow(unittest.TestCase):
    def setUp(self):
        import yaml
        self.wf = yaml.safe_load(WF.read_text(encoding="utf-8"))
        self.job = self.wf["jobs"]["asc-check"]
        self.runs = "\n".join(s.get("run", "") for s in self.job["steps"])

    def test_dispatch_only_read_permissions_secrets_in_env(self):
        on = self.wf.get("on", self.wf.get(True))
        self.assertEqual(set(on), {"workflow_dispatch"})
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        self.assertEqual({k for k, v in self.job["env"].items() if "secrets." in v}, {"ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"})
        self.assertNotIn("${{", self.runs)

    def test_runs_only_read_script_sections_and_no_upload(self):
        self.assertEqual(re.findall(r"scripts/(\w+)\.py", self.runs), ["asc_check"])
        self.assertIn("for S in status build review submission; do", self.runs)
        self.assertFalse([s for s in self.job["steps"] if "upload-artifact" in s.get("uses", "")])
        self.assertNotIn("--all", self.runs)

    def test_key_is_private_and_removed(self):
        self.assertIn("umask 077", self.runs)
        self.assertIn("chmod 600", self.runs)
        self.assertIn("trap 'rm -f \"$KEY\"' EXIT", self.runs)

    def test_ci_lists_this_test(self):
        self.assertIn("scripts/test_asc_check_workflow.py", (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
