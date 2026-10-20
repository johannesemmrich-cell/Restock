#!/usr/bin/env python3
"""Strukturtest für den CI-Anschluss von NotificationPermissionUITests (Issue #145, Durchgang 2).
Prüft nur den Aufbau von ci.yml; ob der Dialog auf dem Runner erscheint und bedienbar ist, zeigt der Lauf."""
import re
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
CI = R / ".github/workflows/ci.yml"
CLASS = "NotificationPermissionUITests"


class NotificationPermissionCI(unittest.TestCase):
    def setUp(self):
        self.job = yaml.safe_load(CI.read_text())["jobs"]["ui-test"]
        self.run = next(s for s in self.job["steps"] if s.get("name") == "Build and run UI tests")["run"]
        a, b = re.split(r"\n\s*else\s*\n", self.run.split("fi\n")[0], maxsplit=1)
        self.half_a, self.half_b = a, b

    def test_half_a_allows_and_selects_the_class(self):
        self.assertIn("TEST_RUNNER_RESTOCK_NOTIF_DECISION=allow", self.half_a)
        self.assertIn(f"-only-testing:RestockUITests/{CLASS}", self.half_a)

    def test_half_b_denies_and_runs_the_class_as_part_of_the_bundle(self):
        self.assertIn("TEST_RUNNER_RESTOCK_NOTIF_DECISION=deny", self.half_b)
        self.assertIn("-only-testing:RestockUITests\"", self.half_b)
        self.assertNotIn(f"-skip-testing:RestockUITests/{CLASS}", self.run)

    def test_class_is_not_a_heavy_class(self):
        self.assertNotIn(CLASS, self.job["env"]["HEAVY_CLASSES"], "HEAVY_CLASSES bleibt die einzige Quelle von A; die Klasse wird nur ergänzt")

    def test_decision_is_exported_before_xcodebuild(self):
        self.assertLess(self.run.index("TEST_RUNNER_RESTOCK_NOTIF_DECISION"), self.run.index("xcodebuild test"))
        self.assertEqual(self.run.count("export TEST_RUNNER_RESTOCK_NOTIF_DECISION="), 2)


if __name__ == "__main__":
    unittest.main(verbosity=1)
