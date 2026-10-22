#!/usr/bin/env python3
"""Preiskatalog (Issue #162): aus `data/price-catalog/catalog.json` (Handpflege) und optional
`data/price-catalog/open-prices-medians.json` (Mediane aus dem Open-Prices-Datensatz, erzeugt von
`scripts/open-prices-medians.py`) die Swift-Datei `SmartCart/Models/PriceCatalogEntries.swift` erzeugen.

Warum erzeugtes Swift statt einer JSON-Ressource im Bundle: `ShoppingItem.init` liest den Katalog synchron
in drei Prozessen (App, Widget, Teilen-Erweiterung); eine Bundle-Ressource müsste in drei Zielen registriert,
beim Start geparst und gegen Fehler abgesichert werden. Die Swift-Datei wird vom Compiler geprüft, kostet
zur Laufzeit nichts und bleibt byteweise reproduzierbar (`--check`).

Aufruf:
  scripts/build-price-catalog.py            schreibt die Swift-Datei
  scripts/build-price-catalog.py --check    vergleicht nur (Exit 1 bei Abweichung) — Drift-Test
  scripts/build-price-catalog.py --stats    druckt Zahlen je Gruppe und Quelle

Regeln beim Zusammenführen (je Eintrag ausgewiesen in `source`):
- Ohne Open-Prices-Median: Handwert, Quelle `hand-<asOf>`.
- Mit Median (Schlüssel = erster Name des Eintrags) und mindestens `minimumPrices` Preisen: der Median je
  Packung ersetzt den typischen Wert, wenn er innerhalb der Handspanne [low, high] liegt; dann Quelle
  `openprices-de-<asOf>`. Liegt er außerhalb, bleibt der Handwert und der Median steht nur in `--stats`
  (Ausreißer oder andere Packungsgröße; wird in der Spec gemessen, bevor die Quelle behauptet wird).
"""
import argparse
import json
import re
import sys
from pathlib import Path

R = Path(__file__).resolve().parent.parent
CATALOG = R / "data" / "price-catalog" / "catalog.json"
MEDIANS = R / "data" / "price-catalog" / "open-prices-medians.json"
OFF_CATEGORIES = R / "data" / "price-catalog" / "off-categories.json"
OUTPUT = R / "SmartCart" / "Models" / "PriceCatalogEntries.swift"

HEADER = """// Erzeugt von scripts/build-price-catalog.py aus data/price-catalog/catalog.json
// (und, falls vorhanden, open-prices-medians.json). NICHT von Hand ändern — Änderungen in der JSON
// vornehmen und das Skript laufen lassen; `scripts/build-price-catalog.py --check` ist der Drift-Test.
import Foundation

extension PriceCatalog {
    private static func e(_ names: [String], _ amount: Double, _ unit: String,
                          _ low: Double, _ typical: Double, _ high: Double, _ source: String,
                          off: String? = nil) -> PriceCatalogEntry {
        PriceCatalogEntry(names: names, packageAmount: amount, packageUnit: unit,
                          low: low, typical: typical, high: high, source: source, offCategory: off)
    }
"""

FOOTER = """
    /// Alle Einträge in Trefferreihenfolge; bei gleich langen Namen gewinnt der frühere Eintrag,
    /// deshalb stehen die Alt-Stichwörter vorn.
    static let entries: [PriceCatalogEntry] = [
%s
    ].flatMap { $0 }
}
"""


def load_catalog(path: Path = CATALOG) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_medians(path: Path = MEDIANS) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def load_off_categories(path: Path = OFF_CATEGORIES) -> dict:
    """Katalogname (erster Name) → OFF-Kategorie (`en:…`), Issue #184; leer, wenn die Datei fehlt."""
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8")).get("tags", {})


def number(value: float) -> str:
    """Packungsgröße: `125` bleibt `125`, `1.5` bleibt `1.5`."""
    if float(value) == int(value):
        return str(int(value))
    return repr(float(value))


def price(value: float) -> str:
    return f"{float(value):.2f}"


def swift_string(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def merged_entry(entry: dict, medians: dict, sources: dict, stats: dict) -> tuple[dict, str]:
    """Liefert (Preise, Quelle) nach den Regeln aus dem Modulkommentar."""
    prices = dict(entry["price"])
    hand_source = f"{entry['source']}-{entry['asOf']}"
    key = entry["names"][0]
    median = medians.get("entries", {}).get(key)
    if not median:
        return prices, hand_source
    minimum = medians.get("minimumPrices", 5)
    if median.get("count", 0) < minimum:
        stats["too_few"] += 1
        return prices, hand_source
    value = median["medianPerPackage"]
    if prices["low"] <= value <= prices["high"]:
        prices["typical"] = round(value, 2)
        stats["applied"] += 1
        return prices, f"openprices-de-{medians['asOf']}"
    stats["outside_range"] += 1
    return prices, hand_source


def render(catalog: dict, medians: dict, stats: dict | None = None, off_categories: dict | None = None) -> str:
    stats = stats if stats is not None else {"applied": 0, "too_few": 0, "outside_range": 0}
    off_categories = off_categories if off_categories is not None else {}
    lines = [HEADER]
    group_names = []
    for group in catalog["groups"]:
        group_names.append(group["name"])
        for doc in group.get("doc", []):
            lines.append(f"    /// {doc}")
        lines.append(f"    static let {group['name']}: [PriceCatalogEntry] = [")
        for entry in group["entries"]:
            prices, source = merged_entry(entry, medians, catalog.get("sources", {}), stats)
            names = ", ".join(swift_string(n) for n in entry["names"])
            off = off_categories.get(entry["names"][0])
            off_part = f", off: {swift_string(off)}" if off else ""
            lines.append(
                f"        e([{names}], {number(entry['package']['amount'])}, {swift_string(entry['package']['unit'])}, "
                f"{price(prices['low'])}, {price(prices['typical'])}, {price(prices['high'])}, {swift_string(source)}{off_part}),")
        lines.append("    ]")
        lines.append("")
    lines.pop()
    body = "\n".join(lines)
    listing = ",\n".join(f"        {name}" for name in group_names) + ","
    return body + FOOTER % listing


def validate(catalog: dict) -> list[str]:
    """Drift-Regeln: Quelle und Stichtag je Eintrag, Namen kleingeschrieben, keine zwei Einträge mit demselben Namen."""
    problems = []
    seen: dict[str, str] = {}
    for group in catalog["groups"]:
        for index, entry in enumerate(group["entries"]):
            where = f"{group['name']}#{index}"
            if not entry.get("source") or not entry.get("asOf"):
                problems.append(f"{where}: Quelle oder Stichtag fehlt")
            if entry["source"] not in catalog.get("sources", {}):
                problems.append(f"{where}: unbekannte Quelle {entry['source']!r}")
            p = entry["price"]
            if not (0 < p["low"] <= p["typical"] <= p["high"]):
                problems.append(f"{where}: Spanne nicht aufsteigend")
            if entry["package"]["unit"] not in ("g", "ml", "stk") or entry["package"]["amount"] <= 0:
                problems.append(f"{where}: Packung ungültig")
            for name in entry["names"]:
                if name != name.lower().strip() or "  " in name or not name:
                    problems.append(f"{where}: Name {name!r} nicht normalisiert")
                if name in seen:
                    problems.append(f"{where}: Name {name!r} kollidiert mit {seen[name]}")
                seen[name] = where
    return problems


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="nur vergleichen, nichts schreiben")
    parser.add_argument("--stats", action="store_true", help="Zahlen je Gruppe und Quelle drucken")
    args = parser.parse_args(argv)

    catalog = load_catalog()
    problems = validate(catalog)
    if problems:
        print("\n".join(problems))
        return 2
    medians = load_medians()
    off_categories = load_off_categories()
    unknown_off = sorted(set(off_categories) - {e["names"][0] for g in catalog["groups"] for e in g["entries"]})
    if unknown_off:
        print(f"off-categories.json nennt Namen ohne Katalogeintrag: {unknown_off}")
        return 2
    bad_tags = sorted(t for t in off_categories.values() if not re.fullmatch(r"[a-z]{2}:[a-z0-9-]+", t))
    if bad_tags:
        print(f"off-categories.json: ungültige Tags {bad_tags}")
        return 2
    stats = {"applied": 0, "too_few": 0, "outside_range": 0}
    text = render(catalog, medians, stats, off_categories)

    if args.stats:
        total = 0
        for group in catalog["groups"]:
            print(f"{group['name']:<18} {len(group['entries']):>4}")
            total += len(group["entries"])
        print(f"{'gesamt':<18} {total:>4}")
        print(f"Open-Prices-Mediane: übernommen {stats['applied']}, zu wenige Preise {stats['too_few']}, "
              f"außerhalb der Handspanne {stats['outside_range']}"
              + ("" if medians else " (keine Mediandatei)"))
        print(f"OFF-Kategorien (Issue #184): {len(off_categories)} Einträge mit Tag")
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != text:
            print(f"ABWEICHUNG: {OUTPUT.relative_to(R)} ist nicht der Stand aus catalog.json — "
                  f"scripts/build-price-catalog.py laufen lassen")
            return 1
        print("OK — PriceCatalogEntries.swift entspricht catalog.json")
        return 0
    OUTPUT.write_text(text, encoding="utf-8")
    print(f"geschrieben: {OUTPUT.relative_to(R)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
