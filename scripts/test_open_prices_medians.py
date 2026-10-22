#!/usr/bin/env python3
"""Test der Median-Berechnung (Issue #162) an einem synthetischen Datensatz; braucht kein Netz."""
import datetime as dt
import importlib.util
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("open_prices_medians", R / "scripts" / "open-prices-medians.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

TODAY = dt.date(2026, 10, 22)
ENTRIES = [
    {"name": "milch", "tag": "en:milks", "amount": 1.0, "unit": "stk"},
    {"name": "mozzarella", "tag": "en:mozzarella", "amount": 125.0, "unit": "g"},
]


def row(**kw):
    base = {"price": 1.0, "currency": "EUR", "date": "2026-09-01", "location_osm_address_country": "Deutschland",
            "price_is_discounted": False}
    base.update(kw)
    return base


class MedianTests(unittest.TestCase):
    def test_unit_entry_takes_package_price_and_median(self):
        rows = [row(category_tag="en:milks", price=p, price_per="UNIT") for p in (0.99, 1.09, 1.19, 1.29, 5.0)]
        result = mod.compute(rows, ENTRIES, 365, TODAY)
        self.assertEqual(result["entries"]["milch"]["count"], 5)
        self.assertEqual(result["entries"]["milch"]["medianPerPackage"], 1.19)

    def test_weight_entry_scales_kilogram_and_product_quantity(self):
        rows = [row(category_tag="en:mozzarella", price=8.0, price_per="KILOGRAM"),            # 8 €/kg → 1,00 € je 125 g
                row(product={"categories_tags": ["en:cheeses", "en:mozzarella"], "product_quantity": 250,
                             "product_quantity_unit": "g"}, price=2.40),                      # 2,40 € je 250 g → 1,20 €
                row(category_tag="en:mozzarella", price=1.5, price_per="UNIT")]              # Stückpreis ohne Gewicht → nicht vergleichbar
        result = mod.compute(rows, ENTRIES, 365, TODAY)
        self.assertEqual(result["entries"]["mozzarella"]["count"], 2)
        self.assertEqual(result["entries"]["mozzarella"]["medianPerPackage"], 1.1)

    def test_filters_country_currency_discount_date(self):
        rows = [row(category_tag="en:milks", location_osm_address_country="France"),
                row(category_tag="en:milks", currency="CHF"),
                row(category_tag="en:milks", price_is_discounted=True),
                row(category_tag="en:milks", date="2024-01-01"),
                row(category_tag="en:milks", price=0.01),
                row(category_tag="en:milks", price=1.11)]
        result = mod.compute(rows, ENTRIES, 365, TODAY)
        self.assertEqual(result["entries"]["milch"]["count"], 1)
        self.assertEqual(result["rowsSeen"], 6)

    def test_nested_location_country_code(self):
        rows = [row(category_tag="en:milks", location_osm_address_country=None, location={"osm_address_country_code": "DE"})]
        self.assertEqual(mod.compute(rows, ENTRIES, 365, TODAY)["entries"]["milch"]["count"], 1)

    def test_catalog_entries_with_tags_load(self):
        entries = mod.load_catalog_entries()
        self.assertGreaterEqual(len(entries), 150)
        self.assertTrue(all(e["tag"].startswith(("en:", "de:")) for e in entries))


if __name__ == "__main__":
    unittest.main()
