#!/usr/bin/env python3
"""Strukturtest für asc-crashes.yml (Issue #242, Schnitt 2, Spec docs/specs/appstore/asc-crashes.md).
Liest nur Repo-Dateien; ob gpg und der Schlüsselentpacker auf dem Runner laufen, zeigen erst die Läufe auf main."""
import re
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
WF = R / ".github/workflows/asc-crashes.yml"
CI = R / ".github/workflows/ci.yml"
KEY = R / ".github/crash-recipient.asc"
DOC = R / "docs/testflight-setup.md"


def read(p):
    if not p.exists():
        raise AssertionError(f"{p.relative_to(R)} fehlt")
    return p.read_text()


def steps(wf):
    return [s for j in wf["jobs"].values() for s in j.get("steps", [])]


class Workflow(unittest.TestCase):
    def setUp(self):
        self.text = read(WF)
        self.wf = yaml.safe_load(self.text)
        self.on = self.wf.get("on", self.wf.get(True)) or {}

    def test_workflow_structure_dispatch_env_only_encrypted_upload(self):  # AC-16
        self.assertEqual(set(self.on), {"workflow_dispatch"})
        st = self.on["workflow_dispatch"]["inputs"]["selftest"]
        self.assertEqual((st["type"], st["default"]), ("boolean", False))
        self.assertEqual(set(self.on["workflow_dispatch"]["inputs"]), {"selftest"})
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        for s in steps(self.wf):
            self.assertNotIn("secrets.", s.get("run", ""), "Secrets nur über env")
        for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"):
            self.assertRegex(self.text, rf"{name}:\s*\$\{{\{{\s*secrets\.{name}\s*\}}\}}")
        ups = [s for s in steps(self.wf) if "upload-artifact" in s.get("uses", "")]
        self.assertGreaterEqual(len(ups), 1)
        for u in ups:
            w = u["with"]
            self.assertEqual(w["path"], "crashes.tar.gpg")
            self.assertEqual(w["retention-days"], 7)
            self.assertIn(w["name"], ("crashes", "crashes-selftest"))

    def test_workflow_unpacks_key_and_traps_cleanup(self):  # AC-17
        run = "\n".join(s.get("run", "") for s in steps(self.wf))
        self.assertIn("BEGIN PRIVATE KEY", run)
        self.assertIn("base64 -d", run)
        self.assertIn("chmod 600", run)
        self.assertIn("umask 077", run)
        self.assertRegex(run, r"trap .*EXIT")

    def test_workflow_skips_artifact_without_submissions(self):  # AC-18
        run = "\n".join(s.get("run", "") for s in steps(self.wf))
        self.assertIn("keine Absturzmeldungen", run)
        self.assertIn("gpg", run)
        self.assertIn("--recipient-file .github/crash-recipient.asc", run)
        self.assertIn("--encrypt", run)
        ups = [s for s in steps(self.wf) if "upload-artifact" in s.get("uses", "")]
        for u in ups:
            self.assertTrue(u.get("if"), "Upload nur bei vorhandenem Chiffrat")

    def test_workflow_selftest_replaces_fetch_and_uses_separate_artifact(self):  # AC-23
        fetch = [s for s in steps(self.wf) if "asc_crashes.py" in s.get("run", "")]
        self.assertEqual(len(fetch), 1)
        self.assertIn("selftest", fetch[0].get("if", "") + fetch[0]["run"])
        self.assertRegex(fetch[0].get("if", ""), r"!\s*inputs\.selftest|inputs\.selftest\s*==\s*(false|'false')|!\s*fromJSON")
        st = [s for s in steps(self.wf) if "openssl rand" in s.get("run", "") or "/dev/urandom" in s.get("run", "")]
        self.assertEqual(len(st), 1)
        self.assertNotIn("asc_crashes.py", st[0]["run"])
        self.assertIn("inputs.selftest", st[0].get("if", ""))
        names = [u["with"]["name"] for u in steps(self.wf) if "upload-artifact" in u.get("uses", "")]
        self.assertIn("crashes-selftest", " ".join(names) or "")
        self.assertIn("crashes", names)


class KeyAndDocs(unittest.TestCase):
    def test_recipient_is_public_key_and_docs_section_exists(self):  # AC-19
        k = read(KEY)
        self.assertIn("BEGIN PGP PUBLIC KEY BLOCK", k)
        self.assertNotIn("PRIVATE KEY", k)
        d = read(DOC)
        m = re.search(r"^#+ .*Absturzberichte abholen.*$", d, re.M)
        self.assertIsNotNone(m, "Abschnitt „Absturzberichte abholen“ fehlt")
        section = d[m.end():]
        self.assertIn("gh run download", section)
        self.assertIn("gpg --decrypt", section)


class Ci(unittest.TestCase):
    def test_ci_lists_workflow_test(self):  # AC-24
        ci = read(CI)
        m = re.search(r"Strukturtests \(Python\)\n\s+run: \|\n(.*?)\n\n", ci, re.S)
        self.assertIsNotNone(m)
        self.assertIn("scripts/test_asc_crashes_workflow.py", m.group(1))
        self.assertIn('python3 -I "$t"', m.group(1))


if __name__ == "__main__":
    unittest.main()
