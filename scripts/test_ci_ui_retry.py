#!/usr/bin/env python3
"""Strukturtest für die UI-Test-Wiederholung in ci.yml (Issue #173, Fassung 2 vom 2026-10-21): Nach einem
roten ersten Lauf werden NUR die fehlgeschlagenen Testfälle einmal erneut gestartet (test-without-building),
nie die ganze Auswahl. Prüft Aufbau und den Kennungs-Parser; ob xcodebuild auf dem Runner mitspielt, zeigt
erst ein Lauf mit Sporadik."""
import json
import sys
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
CI = R / ".github/workflows/ci.yml"
sys.path.insert(0, str(R / "scripts"))
from ci_failed_ui_tests import failed_test_identifiers  # noqa: E402


class UITestRetry(unittest.TestCase):
    def setUp(self):
        self.job = yaml.safe_load(CI.read_text())["jobs"]["ui-test"]
        self.steps = self.job["steps"]
        self.run = next(s for s in self.steps if s.get("name") == "Build and run UI tests")["run"]

    def test_repeats_only_failed_tests_without_rebuilding(self):
        code = "\n".join(l for l in self.run.splitlines() if not l.strip().startswith("#"))
        for flag in ("-retry-tests-on-failure", "-test-iterations", "-test-repetition-relaunch-enabled"):
            self.assertNotIn(flag, code, "Fassung 1 wiederholte die ganze Auswahl (Lauf 39563379941)")
        self.assertIn("run_ui_tests test UITestResults.xcresult", self.run)
        self.assertIn("python3 scripts/ci_failed_ui_tests.py", self.run)
        self.assertIn('RETRY+=("-only-testing:RestockUITests/$TEST")', self.run)
        self.assertIn("run_ui_tests test-without-building UITestRetry.xcresult", self.run)
        self.assertEqual(self.run.count("xcodebuild "), 1, "ein Aufruf in der Funktion, beide Läufe gehen durch sie")

    def test_green_first_run_ends_and_red_without_failed_tests_stays_red(self):
        self.assertIn('if [ "$FIRST_STATUS" -eq 0 ]; then\n  exit 0', self.run)
        self.assertIn('if [ -z "$FAILED" ]', self.run)
        self.assertIn('exit "$FIRST_STATUS"', self.run)

    def test_unit_tests_repeat_nothing(self):
        unit = yaml.safe_load(CI.read_text())["jobs"]["test"]
        unit_runs = " ".join(s.get("run", "") for s in unit["steps"])
        for flag in ("-retry-tests-on-failure", "test-without-building", "ci_failed_ui_tests"):
            self.assertNotIn(flag, unit_runs, "Unit-Tests wiederholen nichts: dort ist Rot ein echter Fehler")

    def test_no_test_skipped_or_disabled(self):
        text = CI.read_text()
        self.assertNotIn("-skip-testing:RestockUITests/StoreSetupUITests", text)
        self.assertNotIn("-skip-testing:RestockUITests/QuickAddAssignmentUITests", text)
        self.assertNotIn("continue-on-error", text)

    def test_summary_step_always_and_never_fails_and_shows_retry(self):
        summary = [s for s in self.steps if "GITHUB_STEP_SUMMARY" in s.get("run", "")]
        self.assertEqual(len(summary), 1)
        self.assertEqual(summary[0].get("if"), "always()")
        self.assertIn("xcresulttool get test-results summary", summary[0]["run"])
        self.assertIn("||", summary[0]["run"], "Zusammenfassung darf den Job nie rot machen")
        self.assertIn("UITestRetry.xcresult", summary[0]["run"])
        names = [s.get("name") for s in self.steps]
        self.assertLess(names.index("Build and run UI tests"), names.index(summary[0]["name"]))
        self.assertLess(names.index(summary[0]["name"]), names.index("Upload xcresult on failure"))
        upload = next(s for s in self.steps if s.get("name") == "Upload xcresult on failure")
        self.assertIn("UITestRetry.xcresult", upload["with"]["path"])


class FailedTestParser(unittest.TestCase):
    """Form der `xcresulttool get test-results tests --compact`-Ausgabe (Xcode 16+): Baum aus testNodes."""

    def tree(self):
        return {
            "devices": [{"deviceName": "iPhone 17"}],
            "testNodes": [{
                "name": "Restock", "nodeType": "Test Plan", "result": "Failed", "children": [{
                    "name": "RestockUITests", "nodeType": "Unit test bundle", "result": "Failed", "children": [
                        {"name": "DataResetUITests", "nodeType": "Test Suite", "result": "Failed", "children": [
                            {"name": "testAppUsableAfterEmergencyReset()", "nodeType": "Test Case", "result": "Failed",
                             "nodeIdentifier": "DataResetUITests/testAppUsableAfterEmergencyReset()",
                             "children": [{"name": "Asynchronous wait failed", "nodeType": "Failure Message", "result": "Failed"}]},
                            {"name": "testEmergencyPathDeletesStoresAndShowsNoticeOnce()", "nodeType": "Test Case", "result": "Passed",
                             "nodeIdentifier": "DataResetUITests/testEmergencyPathDeletesStoresAndShowsNoticeOnce()"},
                        ]},
                        {"name": "DynamicTypeUITests", "nodeType": "Test Suite", "result": "Failed", "children": [
                            {"name": "testResolutionStatsHeaderGesamtFitsAtLargestAccessibilitySize()", "nodeType": "Test Case", "result": "Failed"},
                            {"name": "testSkipped()", "nodeType": "Test Case", "result": "Skipped"},
                        ]},
                    ]}]}]}

    def test_collects_failed_cases_with_and_without_identifier(self):
        self.assertEqual(failed_test_identifiers(self.tree()), [
            "DataResetUITests/testAppUsableAfterEmergencyReset",
            "DynamicTypeUITests/testResolutionStatsHeaderGesamtFitsAtLargestAccessibilitySize",
        ])

    def test_green_tree_and_empty_input_give_nothing(self):
        self.assertEqual(failed_test_identifiers({"testNodes": [{"name": "Restock", "nodeType": "Test Plan", "result": "Passed", "children": []}]}), [])
        self.assertEqual(failed_test_identifiers({}), [])

    def test_cli_prints_one_identifier_per_line(self):
        import subprocess
        out = subprocess.run([sys.executable, "-I", str(R / "scripts/ci_failed_ui_tests.py")],
                             input=json.dumps(self.tree()), capture_output=True, text=True, check=True).stdout
        self.assertEqual(out.split(), ["DataResetUITests/testAppUsableAfterEmergencyReset",
                                       "DynamicTypeUITests/testResolutionStatsHeaderGesamtFitsAtLargestAccessibilitySize"])
        bad = subprocess.run([sys.executable, "-I", str(R / "scripts/ci_failed_ui_tests.py")], input="nicht json", capture_output=True, text=True)
        self.assertEqual((bad.returncode, bad.stdout), (0, ""), "ohne JSON keine Kennung, kein Absturz")


if __name__ == "__main__":
    unittest.main(verbosity=1)
