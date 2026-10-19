#!/usr/bin/env python3
"""Strukturtest für cloudkit-schema.yml (Issue #169, Spec docs/specs/ci/cloudkit-schema-workflow.md).
Prüft nur den Aufbau ohne Token; ob cktool auf dem Runner den Token aus der Pipe liest, zeigt erst der erste Lauf."""
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
WF, CI, DOC = R / ".github/workflows/cloudkit-schema.yml", R / ".github/workflows/ci.yml", R / "docs/testflight-setup.md"
load = lambda p: yaml.safe_load(p.read_text()) or {}
steps = lambda job: job.get("steps", [])
runs = lambda job: " ".join(s.get("run", "") for s in steps(job))


class Workflow(unittest.TestCase):
    def setUp(self):
        self.wf = load(WF)
        self.on = self.wf.get("on", self.wf.get(True)) or {}
        self.export, self.imp = self.wf["jobs"]["export"], self.wf["jobs"]["import-development"]

    def test_trigger_and_mode(self):  # AC-1
        self.assertEqual(set(self.on), {"workflow_dispatch"})
        mode = self.on["workflow_dispatch"]["inputs"]["mode"]
        self.assertEqual((mode["type"], mode["default"], mode["options"]), ("choice", "export", ["export", "import-development"]))

    def test_protection(self):  # AC-2
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        self.assertIs(self.wf["concurrency"]["cancel-in-progress"], False)
        for j in self.wf["jobs"].values():
            self.assertEqual((j["runs-on"], j["timeout-minutes"]), ("macos-26", 15))
        self.assertEqual(self.imp["environment"], "cloudkit")
        self.assertIn("import-development", self.imp["if"])
        self.assertEqual(self.imp["needs"], "export")
        self.assertNotIn("environment", self.export)

    def test_import_only_from_main(self):  # AC-3
        guard = [s for s in steps(self.imp) if "refs/heads/main" in s.get("if", "")]
        self.assertEqual(len(guard), 1)
        self.assertEqual(steps(self.imp).index(guard[0]), 0, "Hauptzweig-Prüfung muss der erste Schritt sein")
        self.assertIn("exit 1", guard[0]["run"])

    def test_never_writes_production(self):  # AC-4
        text = WF.read_text()
        self.assertNotIn("reset-schema", text)
        for line in text.splitlines():
            if "import-schema" in line or "validate-schema" in line:
                self.assertNotIn("production", line)
        for job in (self.export, self.imp):
            for s in steps(job):
                run = s.get("run", "")
                if "import-schema" in run:
                    self.assertIs(job, self.imp)
                    self.assertIn("--environment development", run)
        self.assertNotIn("import-schema", runs(self.export))
        self.assertIn("--environment production", runs(self.export).replace('"$ENVIRONMENT"', "production") if "for ENVIRONMENT in development production" in runs(self.export) else runs(self.export))

    def test_token_handling(self):  # AC-5
        text = WF.read_text()
        self.assertIn("secrets.CLOUDKIT_MANAGEMENT_TOKEN", text)
        self.assertNotIn("ASC_", text)
        for job in (self.export, self.imp):
            save = [s for s in steps(job) if "save-token" in s.get("run", "")]
            self.assertEqual(len(save), 1)
            self.assertEqual(save[0]["env"], {"CLOUDKIT_MANAGEMENT_TOKEN": "${{ secrets.CLOUDKIT_MANAGEMENT_TOKEN }}"})
            self.assertIn("--type management", save[0]["run"])
            self.assertFalse([s for s in steps(job) if "secrets." in s.get("run", "")])
            self.assertFalse([l for l in runs(job).splitlines() if "echo" in l and "CLOUDKIT_MANAGEMENT_TOKEN" in l and "fehlt" not in l])
            remove = [s for s in steps(job) if "remove-token" in s.get("run", "")]
            self.assertEqual(len(remove), 1)
            self.assertIn("always()", remove[0].get("if", ""))
            self.assertIs(steps(job)[-1], remove[0], "Token-Entfernung muss der letzte Schritt sein")

    def test_export_compares_and_uploads(self):  # AC-6
        run = runs(self.export)
        for needle in ("export-schema", "development", "production", "GITHUB_STEP_SUMMARY", "diff -u", "docs/cloudkit/private-schema-aktuell.ckdb"):
            self.assertIn(needle, run + " " + yaml.safe_dump(self.wf.get("env", {})))
        uses = [s["uses"] for j in self.wf["jobs"].values() for s in steps(j) if "uses" in s]
        self.assertTrue(uses and all(u.startswith("actions/") for u in uses), uses)
        self.assertTrue([s for s in steps(self.export) if s.get("uses", "").startswith("actions/upload-artifact")])
        self.assertTrue([s for s in steps(self.imp) if s.get("uses", "").startswith("actions/download-artifact")])
        self.assertIn("Deploy Schema Changes", runs(self.imp))

    def test_xcode_like_ci(self):  # AC-7
        sel = lambda w: [[l.strip() for l in s["run"].splitlines() if l.strip()] for j in w["jobs"].values() for s in steps(j)
                         if s.get("name") == "Select latest available Xcode"]
        ours, ci = sel(self.wf), sel(load(CI))
        self.assertEqual(len(ours), 2)
        self.assertTrue(ci and all(o == ci[0] for o in ours))

    def test_documented(self):  # AC-8
        doc = DOC.read_text()
        for needle in ("cloudkit-schema.yml", "CLOUDKIT_MANAGEMENT_TOKEN", "import-development", "Environment `cloudkit`"):
            self.assertIn(needle, doc)
        self.assertIn("cloudkit-schema.yml", (R / "CLAUDE.md").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=1)
