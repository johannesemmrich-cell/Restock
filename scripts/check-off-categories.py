#!/usr/bin/env python3
"""Prüft `data/price-catalog/off-categories.json` gegen die Kategorien-Taxonomie von Open Food Facts (Issue #184).

Lädt https://static.openfoodfacts.org/data/taxonomies/categories.json (groß, ~30 MB; mit `--taxonomy <datei>` eine
lokale Kopie), prüft jeden Tag auf Existenz (auch als Synonym/Übersetzung aufgelöst) und schreibt bei vollem Erfolg
`verified: true` und `verifiedAt` in die Datei. Braucht Netz; aus der Cloud-Umgebung war der Host am 2026-10-22 gesperrt.

Aufruf: scripts/check-off-categories.py [--taxonomy categories.json] [--write]
"""
import argparse
import datetime as dt
import json
import sys
import urllib.request
from pathlib import Path

R = Path(__file__).resolve().parent.parent
FILE = R / "data" / "price-catalog" / "off-categories.json"
TAXONOMY_URL = "https://static.openfoodfacts.org/data/taxonomies/categories.json"


def load_taxonomy(path: str | None) -> dict:
    if path:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    with urllib.request.urlopen(TAXONOMY_URL, timeout=120) as response:  # noqa: S310 — feste URL
        return json.load(response)


def resolve(tag: str, taxonomy: dict, synonyms: dict) -> str | None:
    """Kanonische Kennung für `tag`, falls vorhanden; sonst Treffer über englische Synonyme/Namen."""
    if tag in taxonomy:
        return tag
    lang, _, value = tag.partition(":")
    for canonical, entry in taxonomy.items():
        names = entry.get("name", {})
        if names.get(lang, "").lower().replace(" ", "-") == value:
            return canonical
        for syn in (entry.get("synonyms", {}) or {}).get(lang, []) or []:
            if syn.lower().replace(" ", "-") == value:
                return canonical
    return synonyms.get(tag)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--taxonomy", help="lokale Kopie von categories.json statt Download")
    parser.add_argument("--write", action="store_true", help="bei Erfolg verified/verifiedAt in die Datei schreiben")
    args = parser.parse_args(argv)

    doc = json.loads(FILE.read_text(encoding="utf-8"))
    taxonomy = load_taxonomy(args.taxonomy)
    print(f"Taxonomie: {len(taxonomy)} Kategorien")
    unknown, renamed = [], {}
    for name, tag in doc["tags"].items():
        canonical = resolve(tag, taxonomy, {})
        if canonical is None:
            unknown.append((name, tag))
        elif canonical != tag:
            renamed[name] = canonical
    for name, canonical in renamed.items():
        print(f"UMBENENNEN {name}: {doc['tags'][name]} → {canonical}")
    for name, tag in unknown:
        print(f"UNBEKANNT  {name}: {tag}")
    print(f"geprüft {len(doc['tags'])}, umzubenennen {len(renamed)}, unbekannt {len(unknown)}")
    if args.write:
        for name, canonical in renamed.items():
            doc["tags"][name] = canonical
        if not unknown:
            doc["verified"] = True
            doc["verifiedAt"] = dt.date.today().isoformat()
        FILE.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("geschrieben:", FILE.relative_to(R))
    return 1 if unknown else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
