#!/usr/bin/env python3
"""Drift- und Regeltest für den Preiskatalog (Issue #162).

`SmartCart/Models/PriceCatalogEntries.swift` ist erzeugt; die Quelle ist `data/price-catalog/catalog.json`. Dieser Test
prüft, dass die Swift-Datei dem Stand der JSON entspricht (sonst `scripts/build-price-catalog.py` laufen lassen), dass
jeder Eintrag Quelle und Stichtag trägt und dass keine zwei Einträge denselben Namen haben."""
import importlib.util
import json
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("build_price_catalog", R / "scripts" / "build-price-catalog.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class PriceCatalogBuildTests(unittest.TestCase):
    def setUp(self):
        self.catalog = build.load_catalog()

    def test_catalog_is_valid(self):
        self.assertEqual(build.validate(self.catalog), [])

    def test_generated_swift_matches_json(self):
        rendered = build.render(self.catalog, build.load_medians())
        self.assertEqual(build.OUTPUT.read_text(encoding="utf-8"), rendered,
                         "PriceCatalogEntries.swift weicht von catalog.json ab — scripts/build-price-catalog.py laufen lassen")

    def test_every_entry_has_source_and_date(self):
        for group in self.catalog["groups"]:
            for entry in group["entries"]:
                self.assertIn(entry["source"], self.catalog["sources"], entry["names"])
                self.assertRegex(entry["asOf"], r"^\d{4}-\d{2}$", entry["names"])

    def test_generated_sources_follow_pattern(self):
        import re
        text = build.OUTPUT.read_text(encoding="utf-8")
        sources = set(re.findall(r', "((?:hand|openprices-de)-\d{4}-\d{2})"\),', text))
        self.assertTrue(sources, "keine Quellen im erzeugten Swift gefunden")
        unknown = set(re.findall(r'\d+\.\d\d, "([^"]+)"\),', text)) - sources
        self.assertEqual(unknown, set())

    def test_validate_reports_collision_and_bad_range(self):
        bad = {"sources": {"hand": {}}, "groups": [{"name": "g", "entries": [
            {"names": ["milch"], "package": {"amount": 1, "unit": "stk"}, "price": {"low": 1, "typical": 2, "high": 3}, "source": "hand", "asOf": "2026-10"},
            {"names": ["milch"], "package": {"amount": 1, "unit": "stk"}, "price": {"low": 3, "typical": 2, "high": 1}, "source": "hand", "asOf": "2026-10"},
            {"names": ["Käse "], "package": {"amount": 0, "unit": "kg"}, "price": {"low": 1, "typical": 1, "high": 1}, "source": "x", "asOf": ""},
        ]}]}
        problems = "\n".join(build.validate(bad))
        for expected in ("kollidiert", "Spanne nicht aufsteigend", "nicht normalisiert", "Packung ungültig", "unbekannte Quelle", "Stichtag fehlt"):
            self.assertIn(expected, problems)

    def test_median_merge_rules(self):
        entry = {"names": ["mozzarella"], "package": {"amount": 125, "unit": "g"},
                 "price": {"low": 0.79, "typical": 1.09, "high": 1.79}, "source": "hand", "asOf": "2026-10"}
        stats = {"applied": 0, "too_few": 0, "outside_range": 0}
        medians = {"asOf": "2026-10", "minimumPrices": 5, "entries": {"mozzarella": {"count": 12, "medianPerPackage": 1.19}}}
        prices, source = build.merged_entry(entry, medians, {}, stats)
        self.assertEqual((prices["typical"], source), (1.19, "openprices-de-2026-10"))
        medians["entries"]["mozzarella"] = {"count": 12, "medianPerPackage": 2.50}
        prices, source = build.merged_entry(entry, medians, {}, stats)
        self.assertEqual((prices["typical"], source), (1.09, "hand-2026-10"))
        medians["entries"]["mozzarella"] = {"count": 2, "medianPerPackage": 1.19}
        prices, source = build.merged_entry(entry, medians, {}, stats)
        self.assertEqual(source, "hand-2026-10")
        self.assertEqual(stats, {"applied": 1, "too_few": 1, "outside_range": 1})

    def test_entry_count_matches_swift(self):
        total = sum(len(g["entries"]) for g in self.catalog["groups"])
        text = build.OUTPUT.read_text(encoding="utf-8")
        self.assertEqual(text.count("\n        e(["), total)
        self.assertGreaterEqual(total, 528)


if __name__ == "__main__":
    unittest.main()
