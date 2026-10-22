#!/usr/bin/env python3
"""Strukturtest (Issue #208): Kein UI-Test sendet echte Community-Beiträge.

UI-Tests, die den Bon-Prüf-Screen säen (`-seedReceiptReview…ForUITests`) oder den Erst-Hinweis aufräumen
(`-clearCommunityPricesNoticeForUITests`), können „Speichern“ tippen und damit `CommunityPrice`-Records an die
CloudKit-Entwicklungsumgebung schicken (Fremddaten im Pool). Jede solche Datei muss deshalb das DEBUG-Launch-Argument
`-blockCommunityContributionsForUITests` setzen, mit dem `CommunityPriceService.shared` eine ablehnende Datenbank
bekommt. Der Argumentname muss in Dienst und Tests wortgleich sein."""
import re
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
UI_TESTS = R / "RestockUITests"
SERVICE = R / "SmartCart" / "Services" / "CommunityPriceService.swift"
ARGUMENT = "-blockCommunityContributionsForUITests"
TRIGGERS = re.compile(r'"-seedReceiptReview\w*ForUITests"|"-clearCommunityPricesNoticeForUITests"')


def files_needing_block(root: Path = UI_TESTS) -> list[Path]:
    return sorted(p for p in root.glob("*.swift") if TRIGGERS.search(p.read_text(encoding="utf-8")))


def violations(root: Path = UI_TESTS) -> list[str]:
    return [p.name for p in files_needing_block(root) if f'"{ARGUMENT}"' not in p.read_text(encoding="utf-8")]


class BlockCommunityContributionsTests(unittest.TestCase):
    def test_service_declares_argument(self):
        text = SERVICE.read_text(encoding="utf-8")
        self.assertIn(f'static let blockContributionsArgument = "{ARGUMENT}"', text)
        self.assertIn("BlockedCommunityPriceDatabase", text)

    def test_trigger_regex_matches_known_seeds(self):
        for seed in ("-seedReceiptReviewForUITests", "-seedReceiptReviewUnresolvedLineForUITests",
                     "-seedReceiptReviewWeightLineForUITests", "-clearCommunityPricesNoticeForUITests"):
            self.assertTrue(TRIGGERS.search(f'["{seed}"]'), seed)
        self.assertFalse(TRIGGERS.search('["-seedQuickAddAssignmentForUITests"]'))

    def test_every_receipt_saving_ui_test_blocks_contributions(self):
        needing = files_needing_block()
        self.assertGreaterEqual(len(needing), 4, [p.name for p in needing])
        self.assertEqual(violations(), [], f"UI-Testklassen ohne {ARGUMENT}")

    def test_violation_detected_in_sample(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            bad = Path(d) / "BadUITests.swift"
            bad.write_text('app.launchArguments += ["-seedReceiptReviewForUITests"]', encoding="utf-8")
            good = Path(d) / "GoodUITests.swift"
            good.write_text(f'app.launchArguments += ["-seedReceiptReviewForUITests", "{ARGUMENT}"]', encoding="utf-8")
            self.assertEqual(violations(Path(d)), ["BadUITests.swift"])


if __name__ == "__main__":
    unittest.main()
