#!/usr/bin/env python3
"""Strukturtest für Issue #99, Paket 1: Release-Build-Job in ci.yml (Punkt 5) und iPhone-only im Projekt (Punkt 3).
Prüft nur den Aufbau; ob der Release-Build auf dem Runner durchläuft, zeigt der Lauf."""
import re
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
CI = R / ".github/workflows/ci.yml"
PBX = R / "Restock.xcodeproj/project.pbxproj"


class ReleaseBuildJob(unittest.TestCase):
    def setUp(self):
        self.jobs = yaml.safe_load(CI.read_text())["jobs"]
        self.job = self.jobs["release-build"]
        self.build = next(s for s in self.job["steps"] if s.get("name") == "Build Release for simulator")["run"]

    def test_builds_release_for_simulator_without_tests(self):
        self.assertIn("xcodebuild build", self.build)
        self.assertIn("-configuration Release", self.build)
        self.assertIn("generic/platform=iOS Simulator", self.build)
        self.assertNotIn("xcodebuild test", self.build)
        self.assertNotIn("-only-testing", self.build)

    def test_runs_in_parallel_with_the_other_jobs(self):
        self.assertNotIn("needs", self.job, "eigener Job, keine Abhängigkeit: läuft parallel zu test und ui-test")
        self.assertEqual((self.job["runs-on"], self.job["timeout-minutes"]), ("macos-26", 30))

    def test_xcode_step_matches_the_other_jobs(self):
        pick = lambda j: next(s for s in self.jobs[j]["steps"] if s.get("name") == "Select latest available Xcode")["run"]
        self.assertEqual(pick("release-build"), pick("test"))

    def test_signing_settings_match_the_test_job(self):
        unit = next(s for s in self.jobs["test"]["steps"] if s.get("name") == "Build and test")["run"]
        for flag in ("CODE_SIGN_IDENTITY=\"-\"", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGNING_ALLOWED=YES", "AD_HOC_CODE_SIGNING_ALLOWED=YES", "-skipMacroValidation"):
            self.assertIn(flag, self.build)
            self.assertIn(flag, unit)


class IPhoneOnly(unittest.TestCase):
    def test_every_target_is_iphone_only(self):
        families = re.findall(r"TARGETED_DEVICE_FAMILY = ([^;]+);", PBX.read_text())
        self.assertGreaterEqual(len(families), 10, "alle Konfigurationen von App, Widget, Erweiterung und Tests")
        self.assertEqual(set(families), {"1"}, "Release 1.0 nur fürs iPhone (PO 2026-10-12, Issue #99 Punkt 3)")


if __name__ == "__main__":
    unittest.main(verbosity=1)
