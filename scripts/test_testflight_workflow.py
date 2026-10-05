#!/usr/bin/env python3
"""Strukturtest für testflight.yml (Issue #109, Stufe A der Spec docs/specs/ci/testflight-upload-workflow.md).
Prüft nur den Aufbau ohne Zugangsdaten; ob Signieren/Hochladen klappt, zeigt erst der Probelauf (Stufe B)."""
import plistlib, shutil, subprocess, unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
WF, CI = R / ".github/workflows/testflight.yml", R / ".github/workflows/ci.yml"
PLIST, DOC = R / "scripts/ExportOptions-testflight.plist", R / "docs/testflight-setup.md"
NOT_SCOPE = ("docs/specs/", "docs/briefings/", "docs/context/", "docs/artifacts/")
APP = ("SmartCart/", "SmartCartWidgets/", "RestockShareExtension/", "RestockTests/", "RestockUITests/", "Restock.xcodeproj/")
load = lambda p: yaml.safe_load(p.read_text()) or {}
steps = lambda wf: [s for j in (wf.get("jobs") or {}).values() for s in j.get("steps", [])]
git = lambda *a: subprocess.run(["git", *a], cwd=R, capture_output=True, text=True)


class Workflow(unittest.TestCase):
    def setUp(self):
        self.wf = load(WF)
        self.assertTrue(self.wf, "testflight.yml ist leer")
        self.on = self.wf.get("on", self.wf.get(True)) or {}

    def test_trigger_and_inputs(self):  # AC-2, AC-3
        self.assertEqual(set(self.on), {"workflow_dispatch"})
        i = self.on["workflow_dispatch"]["inputs"]
        self.assertEqual(i["dry_run"]["type"], "boolean")
        self.assertIn(i["dry_run"]["default"], (True, "true"))
        self.assertFalse(i["build_number"].get("required", False))

    def test_protection(self):  # AC-4
        for j in self.wf["jobs"].values():
            e = j["environment"]
            self.assertEqual(e.get("name") if isinstance(e, dict) else e, "testflight")
            self.assertEqual((j["timeout-minutes"], j["runs-on"]), (30, "macos-26"))
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        self.assertIs(self.wf["concurrency"]["cancel-in-progress"], False)

    def test_upload_guard(self):  # AC-5
        ex = [s for s in steps(self.wf) if "-exportArchive" in s.get("run", "")]
        self.assertEqual(len(ex), 1)
        self.assertTrue("refs/heads/main" in ex[0].get("if", "") and "dry_run" in ex[0]["if"])
        self.assertTrue([s for s in steps(self.wf) if s not in ex and "dry_run" in s.get("if", "")])

    def test_actions_and_secrets(self):  # AC-6, AC-7
        uses = [s["uses"] for s in steps(self.wf) if "uses" in s]
        self.assertTrue(uses and all(u.startswith("actions/") for u in uses), uses)
        for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"):
            self.assertIn(f"secrets.{n}", WF.read_text())
        self.assertFalse([s for s in steps(self.wf) if "secrets." in s.get("run", "")])

    def test_cleanup_always(self):  # AC-8
        self.assertTrue([s for s in steps(self.wf) if "always()" in s.get("if", "")
                         and "rm" in s.get("run", "") and ".p8" in s["run"]])

    def test_xcode_like_ci(self):  # AC-9
        sel = lambda w: [[l.strip() for l in s["run"].splitlines() if l.strip()] for s in steps(w)
                         if s.get("name") == "Select latest available Xcode"][:1]
        self.assertTrue(sel(self.wf))
        self.assertEqual(sel(self.wf), sel(load(CI)))
        runs = " ".join(s.get("run", "") for s in steps(self.wf))
        self.assertTrue("xcodebuild -version" in runs and "-showsdks" in runs)

    def test_archive_and_export(self):  # AC-10
        ar = [s["run"] for s in steps(self.wf) if "xcodebuild" in s.get("run", "") and " archive" in s["run"]]
        self.assertEqual(len(ar), 1)
        for f in ("-allowProvisioningUpdates", "-authenticationKeyPath", "-authenticationKeyID",
                  "-authenticationKeyIssuerID", "-skipMacroValidation", "generic/platform=iOS", "-configuration Release"):
            self.assertIn(f, ar[0])
        ex = [s["run"] for s in steps(self.wf) if "-exportArchive" in s.get("run", "")]
        self.assertIn("scripts/ExportOptions-testflight.plist", ex[0])


class ExportOptions(unittest.TestCase):
    def test_plist(self):  # AC-11
        o = plistlib.loads(PLIST.read_bytes())
        for k, v in (("method", "app-store-connect"), ("destination", "upload"), ("teamID", "XK87E2B3VR"),
                     ("signingStyle", "automatic"), ("uploadSymbols", True)):
            self.assertEqual(o.get(k), v, k)
        self.assertIsNot(o.get("manageAppVersionAndBuildNumber"), False)
        if shutil.which("plutil"):
            self.assertEqual(subprocess.run(["plutil", "-lint", str(PLIST)], capture_output=True).returncode, 0)


class Repository(unittest.TestCase):
    def test_ci_unchanged(self):  # AC-12
        out = git("diff", "--exit-code", "origin/main", "--", ".github/workflows/ci.yml")
        if out.returncode not in (0, 1):
            self.skipTest("origin/main nicht verfügbar")
        self.assertEqual(out.returncode, 0, "ci.yml wurde geändert")

    def test_documentation(self):  # AC-13
        for w in ("Admin", "Secrets", "Environment", "Rotation", "Rückfall", "nie dieselbe Build-Nummer"):
            self.assertIn(w, DOC.read_text())
        self.assertIn("docs/testflight-setup.md", (R / "CLAUDE.md").read_text())

    def test_scope(self):  # AC-14
        tracked = [l.split("\t") for l in git("diff", "--numstat", "origin/main").stdout.splitlines()]
        new = [l[3:] for l in git("status", "--porcelain", "-uall").stdout.splitlines() if l.startswith("??")]
        ok = lambda f: not f.startswith(NOT_SCOPE)
        files = sorted({f for _, _, f in tracked if ok(f)} | {f for f in new if ok(f)})
        lines = sum(int(a) + int(d) for a, d, f in tracked if ok(f) and a != "-")
        lines += sum(len((R / f).read_text().splitlines()) for f in new if ok(f))
        self.assertLessEqual(len(files), 5, files)
        self.assertFalse([f for f in files if f.startswith(APP)], files)
        self.assertLessEqual(lines, 250, f"{lines} Zeilen in {files}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
