#!/usr/bin/env python3
"""Strukturtest (Issue #259, Durchgang 2): Der Promo-Pool ist restlos aus dem Projekt entfernt.

Prüft AC-10 (keine Treffer, Dateien gelöscht), AC-11 (pbxproj), AC-12 (Symbole), AC-13 (Datenschutztext)
und AC-14 (Schlüssel) der Spec `docs/specs/views/offer-codes-einloesen.md`. Das CloudKit-Schema bleibt
bewusst unberührt (Typ `PromoCode` steht weiter in `docs/cloudkit/private-schema-aktuell.ckdb`)."""
import re
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
PATTERN = re.compile(r"promocode|promo-code|promo code", re.IGNORECASE)
SCAN = ["SmartCart", "RestockTests", "RestockUITests", "docs/appstore", "project.yml", "CLAUDE.md"]
SUFFIXES = {".swift", ".strings", ".md", ".yml", ".plist", ".xcprivacy", ".json"}
DELETED = [
    "SmartCart/Services/PromoCodeService.swift",
    "SmartCart/Views/Settings/PromoCodeAdminView.swift",
    "RestockTests/PromoCodeServiceTests.swift",
]
LOCALIZATION_KEY = re.compile(r'^"(settings\.promoCode\.|promoCode\.error\.)', re.MULTILINE)


def _files():
    for entry in SCAN:
        p = R / entry
        if p.is_file():
            yield p
        else:
            yield from (f for f in p.rglob("*") if f.is_file() and f.suffix in SUFFIXES)


class PromoRemovedTests(unittest.TestCase):
    def test_deleted_files_are_gone(self):  # AC-10
        for rel in DELETED:
            self.assertFalse((R / rel).exists(), f"{rel} existiert noch")

    def test_no_promo_mentions_in_sources(self):  # AC-10
        hits = []
        for f in _files():
            for n, line in enumerate(f.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
                if PATTERN.search(line):
                    hits.append(f"{f.relative_to(R)}:{n}")
        self.assertEqual(hits, [], "Promo-Reste: " + ", ".join(hits[:20]))

    def test_pbxproj_has_no_promo_reference(self):  # AC-11
        text = (R / "Restock.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        self.assertEqual(text.count("PromoCode"), 0)

    def test_premium_service_symbols_gone(self):  # AC-12
        for f in _files():
            if f.suffix != ".swift":
                continue
            text = f.read_text(encoding="utf-8", errors="ignore")
            for symbol in ("hasValidPromoCode", "setHasValidPromoCode"):
                self.assertNotIn(symbol, text, f"{symbol} in {f.relative_to(R)}")

    def test_privacy_texts_without_promo_paragraph(self):  # AC-13
        for rel in ("SmartCart/Views/Settings/LegalView.swift", "docs/appstore/datenschutz.md"):
            text = (R / rel).read_text(encoding="utf-8")
            self.assertNotRegex(text, r"(?i)promo-?codes?", rel)

    def test_localization_keys_removed_in_both_languages(self):  # AC-14
        counts = {}
        for lang in ("de", "en"):
            text = (R / f"SmartCart/Resources/{lang}.lproj/Localizable.strings").read_text(encoding="utf-8")
            self.assertIsNone(LOCALIZATION_KEY.search(text), f"{lang}: Promo-Schlüssel vorhanden")
            counts[lang] = text.count('" = "')
        self.assertEqual(counts["de"], counts["en"])
        # Vor dem Rückbau gemessen: 478 je Sprache, 7 Schlüssel entfallen.
        self.assertEqual(counts["de"], 478 - 7)


if __name__ == "__main__":
    unittest.main()
