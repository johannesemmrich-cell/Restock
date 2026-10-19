#!/usr/bin/env python3
"""Strukturtest für die UI-Test-Wiederholung in ci.yml (Issue #173). Prüft nur den Aufbau; ob xcodebuild
die Wiederholung auf dem Runner wie erwartet ausführt, zeigt erst der nächste Lauf mit Sporadik."""
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
CI = R / ".github/workflows/ci.yml"


class UITestRetry(unittest.TestCase):
    def setUp(self):
        self.job = yaml.safe_load(CI.read_text())["jobs"]["ui-test"]
        self.steps = self.job["steps"]
        self.run = next(s for s in self.steps if s.get("name") == "Build and run UI tests")["run"]

    def test_retry_flags_on_ui_tests_only(self):
        for flag in ("-retry-tests-on-failure", "-test-iterations 2", "-test-repetition-relaunch-enabled YES"):
            self.assertIn(flag, self.run)
        unit = yaml.safe_load(CI.read_text())["jobs"]["test"]
        unit_runs = " ".join(s.get("run", "") for s in unit["steps"])
        self.assertNotIn("-retry-tests-on-failure", unit_runs, "Unit-Tests wiederholen nichts: dort ist Rot ein echter Fehler")

    def test_no_test_skipped_or_disabled(self):
        text = CI.read_text()
        self.assertNotIn("-skip-testing:RestockUITests/StoreSetupUITests", text)
        self.assertNotIn("-skip-testing:RestockUITests/QuickAddAssignmentUITests", text)
        self.assertNotIn("continue-on-error", text)

    def test_summary_step_always_and_never_fails(self):
        summary = [s for s in self.steps if "xcresulttool" in s.get("run", "")]
        self.assertEqual(len(summary), 1)
        self.assertEqual(summary[0].get("if"), "always()")
        self.assertIn("GITHUB_STEP_SUMMARY", summary[0]["run"])
        self.assertIn("||", summary[0]["run"], "Zusammenfassung darf den Job nie rot machen")
        names = [s.get("name") for s in self.steps]
        self.assertLess(names.index("Build and run UI tests"), names.index(summary[0]["name"]))
        self.assertLess(names.index(summary[0]["name"]), names.index("Upload xcresult on failure"))


if __name__ == "__main__":
    unittest.main(verbosity=1)
