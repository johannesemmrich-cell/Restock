#!/usr/bin/env python3
"""Strukturtest Issue #208: UI-Tests, die Community-Preise senden könnten, nutzen die Ersatz-Datenbank.
Prüft nur den Aufbau der Dateien; ob im echten UI-Lauf nichts an CloudKit geht, ist damit nicht gemessen."""
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
UITESTS = R / "RestockUITests"
DISCARD = "-discardCommunityPricesForUITests"
CLEAR = "-clearDiscardedCommunityPricesForUITests"


class DiscardCommunityPrices(unittest.TestCase):
    def test_every_sending_class_passes_the_discard_argument(self):
        offenders = []
        for f in sorted(UITESTS.glob("*.swift")):
            text = f.read_text()
            if ("-communityPricesNoticeShown" in text or "Weiter teilen" in text) and DISCARD not in text:
                offenders.append(f.name)
        self.assertEqual(offenders, [], f"ohne {DISCARD}: {offenders}")

    def test_every_class_with_discard_also_cleans_up(self):
        offenders = [f.name for f in sorted(UITESTS.glob("*.swift"))
                     if DISCARD in f.read_text() and CLEAR not in f.read_text()]
        self.assertEqual(offenders, [], f"ohne {CLEAR}: {offenders}")

    def test_the_four_known_classes_are_covered(self):
        for name in ("ReceiptReviewUITests", "ReceiptResolutionStatsUITests",
                     "DynamicTypeUITests", "CommunityShareNoticeUITests"):
            self.assertTrue(DISCARD in (UITESTS / f"{name}.swift").read_text(), f"{name} ohne {DISCARD}")

    def test_app_knows_the_cleanup_argument(self):
        self.assertTrue(CLEAR in (R / "SmartCart/SmartCartApp.swift").read_text(), "SmartCartApp kennt das Aufräum-Argument nicht")

    def test_service_knows_the_discard_argument(self):
        self.assertTrue(DISCARD in (R / "SmartCart/Services/CommunityPriceService.swift").read_text(), "CommunityPriceService kennt das Argument nicht")


if __name__ == "__main__":
    unittest.main(verbosity=1)
