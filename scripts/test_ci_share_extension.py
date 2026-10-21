#!/usr/bin/env python3
"""Strukturtest für Issue #99, Paket 4: Teilen-Erweiterung (Fotos → Teilen → Restock) als blockierender CI-Job.
Prüft Aufbau und Gleichlauf von erzeugtem Bild, Skript und Unit-Test-Vorlage; ob der Weg auf dem Runner
durchläuft, zeigt der Lauf."""
import re
import unittest
from pathlib import Path
import yaml

R = Path(__file__).resolve().parent.parent
CI = R / ".github/workflows/ci.yml"
SCRIPT = R / "scripts/run-share-extension-uitest.sh"
IMAGE_SCRIPT = R / "scripts/make-test-receipt-image.swift"
UNIT = R / "RestockTests/ReceiptTextRecognizerTests.swift"


def items_and_total(text):
    block = re.search(r"items: \[\(name: String, price: String\)\] = \[(.*?)\]", text, re.S).group(1)
    items = re.findall(r'\("([^"]+)", "([^"]+)"\)', block)
    total = re.search(r"static let total = ([\d.]+)|let total = \"([\d,]+)\"", text)
    total = (total.group(1) or total.group(2)).replace(".", ",")
    return items, total


class ShareExtensionJob(unittest.TestCase):
    def setUp(self):
        self.jobs = yaml.safe_load(CI.read_text())["jobs"]
        self.job = self.jobs["share-extension"]
        self.steps = {s.get("name"): s for s in self.job["steps"]}
        self.run = self.steps["Photos → Share → Restock"]["run"]

    def test_is_a_blocking_parallel_job(self):
        self.assertNotIn("needs", self.job)
        self.assertNotIn("continue-on-error", self.job, "blockierend (PO 2026-10-21, Punkt 1)")
        self.assertEqual((self.job["runs-on"], self.job["timeout-minutes"]), ("macos-26", 45))

    def test_setup_steps_match_the_ui_test_job(self):
        ui = {s.get("name"): s for s in self.jobs["ui-test"]["steps"]}
        for name in ("Select latest available Xcode", "Pick newest available iPhone simulator", "Boot simulator", "Grant app permissions"):
            self.assertEqual(self.steps[name]["run"], ui[name]["run"], name)

    def test_runs_the_script_with_the_generated_image_and_signing_flags(self):
        self.assertIn("swift scripts/make-test-receipt-image.swift", self.steps["Generate test receipt image"]["run"])
        self.assertIn("bash scripts/run-share-extension-uitest.sh ${{ steps.sim.outputs.udid }}", self.run)
        self.assertIn('TEST_IMAGE="$RUNNER_TEMP/testbon.png"', self.run)
        for flag in ("-skipMacroValidation", "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGNING_ALLOWED=YES", "AD_HOC_CODE_SIGNING_ALLOWED=YES"):
            self.assertIn(flag, self.run)
        self.assertNotIn('CODE_SIGN_IDENTITY="-"', self.run, "Anführungszeichen würden per Wortaufteilung wörtlich an xcodebuild gehen")

    def test_expectations_match_the_generated_receipt(self):
        items, total = items_and_total(IMAGE_SCRIPT.read_text())
        self.assertIn(f"MIN_POSITIONS={len(items)}", self.run)
        self.assertIn(f"EXPECT_TOTAL={total}", self.run)


class GeneratedImageMatchesUnitTestTemplate(unittest.TestCase):
    def test_items_and_total_are_identical(self):
        self.assertEqual(items_and_total(IMAGE_SCRIPT.read_text()), items_and_total(UNIT.read_text()))
        self.assertEqual(len(items_and_total(UNIT.read_text())[0]), 18)

    def test_geometry_matches(self):
        s = IMAGE_SCRIPT.read_text()
        for needle in ("let width = 1206", "let height = 9000", "Menlo-Regular", "size: 40", "let gap: CGFloat = 66", "* 0.05", "* 0.93", "var y: CGFloat = 160"):
            self.assertIn(needle, s)


class ScriptIsCICapable(unittest.TestCase):
    def test_respects_developer_dir_and_extra_flags(self):
        s = SCRIPT.read_text()
        self.assertIn('XCODE_DEV="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"', s)
        self.assertNotIn("DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild", s)
        self.assertEqual(s.count('${XB_FLAGS[@]+"${XB_FLAGS[@]}"}'), 3, "build, showBuildSettings, test (bash 3.2 + set -u)")


if __name__ == "__main__":
    unittest.main(verbosity=1)
