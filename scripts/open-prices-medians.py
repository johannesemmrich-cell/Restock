#!/usr/bin/env python3
"""Mediane aus dem Open-Prices-Datensatz für den Preiskatalog (Issue #162, zweite Quelle).

Quelle: täglicher Parquet-Export von Open Prices (Hugging Face `openfoodfacts/open-prices`, Lizenz ODbL →
Namensnennung in `LegalView`, Abschnitt „Quellen“). Der Export wird NICHT eingecheckt; dieses Skript liest ihn
lokal (`--prices prices.parquet`) oder lädt ihn (`--download`, braucht Netz zu huggingface.co).

Zuordnung Katalog ↔ Datensatz über die OFF-Kategorie je Katalogeintrag (`data/price-catalog/off-categories.json`):
ein Preis zählt für einen Eintrag, wenn `category_tag` des Preises (Ware ohne Barcode) oder eine der
`product.categories_tags` des Produkts (Barcode-Ware) die Kategorie des Eintrags enthält. Preise werden auf die
Packung des Katalogeintrags umgerechnet: Gewichts-/Volumenpackung über `price_per == KILOGRAM`/`LITER` bzw.
`product.product_quantity` (g/ml); Stückeinträge nehmen den Preis je Packung (`price_per == UNIT` oder Barcode-Ware).

Filter: Deutschland (`location_osm_address_country == "Deutschland"`/`Germany` oder `location.osm_address_country_code
== "DE"`), Währung EUR, Datum innerhalb `--days` (Standard 365), Preis 0,05–200 €, kein Rabattpreis. Je Eintrag Median,
p25, p75 und Anzahl; Ausgabe `data/price-catalog/open-prices-medians.json` (`asOf`, `minimumPrices`, `entries`).
Danach `scripts/build-price-catalog.py` laufen lassen (Merge-Regel dort: Median ersetzt den typischen Wert nur
innerhalb der Handspanne) und die Trefferzahlen in der Spec festhalten, bevor die Quelle behauptet wird.

Aufruf:
  scripts/open-prices-medians.py --prices /pfad/prices.parquet [--days 365] [--min 5] [--write]
  scripts/open-prices-medians.py --download --write
"""
import argparse
import datetime as dt
import json
import statistics
import sys
from pathlib import Path

R = Path(__file__).resolve().parent.parent
CATALOG = R / "data" / "price-catalog" / "catalog.json"
OFF = R / "data" / "price-catalog" / "off-categories.json"
OUT = R / "data" / "price-catalog" / "open-prices-medians.json"
HF_FILES = ["https://huggingface.co/datasets/openfoodfacts/open-prices/resolve/main/prices.parquet"]
COUNTRY_VALUES = {"deutschland", "germany", "de"}


def load_catalog_entries() -> list[dict]:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    tags = json.loads(OFF.read_text(encoding="utf-8"))["tags"]
    out = []
    for group in catalog["groups"]:
        for entry in group["entries"]:
            name = entry["names"][0]
            if name in tags:
                out.append({"name": name, "tag": tags[name], "amount": float(entry["package"]["amount"]),
                            "unit": entry["package"]["unit"]})
    return out


def first(row: dict, *keys, default=None):
    for key in keys:
        value = row.get(key)
        if value is not None and value == value:  # kein NaN
            return value
    return default


def is_germany(row: dict) -> bool:
    for key in ("location_osm_address_country", "location__osm_address_country", "location.osm_address_country",
                "location_osm_address_country_code", "location__osm_address_country_code", "location.osm_address_country_code"):
        value = row.get(key)
        if isinstance(value, str) and value.strip().lower() in COUNTRY_VALUES:
            return True
    location = row.get("location")
    if isinstance(location, dict):
        for key in ("osm_address_country", "osm_address_country_code"):
            value = location.get(key)
            if isinstance(value, str) and value.strip().lower() in COUNTRY_VALUES:
                return True
    return False


def product_tags(row: dict) -> set[str]:
    tags = set()
    tag = first(row, "category_tag")
    if isinstance(tag, str):
        tags.add(tag)
    product = row.get("product")
    if isinstance(product, dict):
        cats = product.get("categories_tags")
        if isinstance(cats, (list, tuple)):
            tags.update(str(c) for c in cats)
    cats = first(row, "product__categories_tags", "product.categories_tags")
    if isinstance(cats, (list, tuple)):
        tags.update(str(c) for c in cats)
    return tags


def price_per_package(row: dict, entry: dict) -> float | None:
    """Preis des Datensatzes auf die Katalogpackung umgerechnet; `None`, wenn nicht vergleichbar."""
    price = first(row, "price")
    if not isinstance(price, (int, float)) or price <= 0:
        return None
    per = first(row, "price_per", default="")
    per = str(per).upper() if per else ""
    product = row.get("product") if isinstance(row.get("product"), dict) else {}
    quantity = first(row, "product__product_quantity", "product.product_quantity") or product.get("product_quantity")
    quantity_unit = str(first(row, "product__product_quantity_unit", "product.product_quantity_unit")
                        or product.get("product_quantity_unit") or "").lower()
    if entry["unit"] in ("g", "ml"):
        if per in ("KILOGRAM", "LITER"):
            return float(price) * entry["amount"] / 1000.0
        if isinstance(quantity, (int, float)) and quantity > 0 and quantity_unit in ("g", "ml", ""):
            # Barcode-Ware mit Packungsgröße: Preis je Gramm/Milliliter × Katalogpackung
            return float(price) / float(quantity) * entry["amount"]
        return None
    # Stückeintrag: Packungspreis
    if per in ("", "UNIT") or isinstance(quantity, (int, float)):
        return float(price)
    return None


def compute(rows, entries: list[dict], days: int, today: dt.date) -> dict:
    by_tag: dict[str, list[dict]] = {}
    for entry in entries:
        by_tag.setdefault(entry["tag"], []).append(entry)
    cutoff = today - dt.timedelta(days=days)
    samples: dict[str, list[float]] = {e["name"]: [] for e in entries}
    seen = 0
    for row in rows:
        seen += 1
        if not is_germany(row):
            continue
        if str(first(row, "currency", default="EUR")).upper() != "EUR":
            continue
        if first(row, "price_is_discounted") is True:
            continue
        date = first(row, "date")
        if date is not None:
            try:
                d = date if isinstance(date, dt.date) else dt.date.fromisoformat(str(date)[:10])
            except ValueError:
                continue
            if d < cutoff:
                continue
        tags = product_tags(row)
        if not tags:
            continue
        for tag in tags & by_tag.keys():
            for entry in by_tag[tag]:
                value = price_per_package(row, entry)
                if value is not None and 0.05 <= value <= 200:
                    samples[entry["name"]].append(value)
    result = {}
    for name, values in samples.items():
        if not values:
            continue
        values.sort()
        q = statistics.quantiles(values, n=4) if len(values) >= 4 else [values[0], values[len(values) // 2], values[-1]]
        result[name] = {"count": len(values), "medianPerPackage": round(statistics.median(values), 2),
                        "p25": round(q[0], 2), "p75": round(q[2], 2)}
    return {"rowsSeen": seen, "entries": result}


def read_parquet_rows(path: Path):
    import pyarrow.parquet as pq  # erst hier, damit --help ohne pyarrow geht
    table = pq.read_table(path)
    for batch in table.to_batches(max_chunksize=50_000):
        for row in batch.to_pylist():
            yield row


def download(dest: Path) -> Path:
    import urllib.request
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / "prices.parquet"
    urllib.request.urlretrieve(HF_FILES[0], target)  # noqa: S310 — feste URL
    return target


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--prices", help="lokale prices.parquet")
    parser.add_argument("--download", action="store_true", help="prices.parquet von Hugging Face laden (ins Scratch-Verzeichnis)")
    parser.add_argument("--days", type=int, default=365)
    parser.add_argument("--min", type=int, default=5, help="minimumPrices für den Merge")
    parser.add_argument("--write", action="store_true", help="open-prices-medians.json schreiben")
    args = parser.parse_args(argv)
    if not args.prices and not args.download:
        parser.error("--prices oder --download")
    path = Path(args.prices) if args.prices else download(R / "build" / "open-prices")
    entries = load_catalog_entries()
    today = dt.date.today()
    result = compute(read_parquet_rows(path), entries, args.days, today)
    covered = len(result["entries"])
    enough = sum(1 for v in result["entries"].values() if v["count"] >= args.min)
    print(f"Zeilen gelesen: {result['rowsSeen']}, Katalogeinträge mit Tag: {len(entries)}, mit Preisen: {covered}, "
          f"mit ≥ {args.min} Preisen: {enough}")
    doc = {"source": "Open Prices (Open Food Facts), Parquet-Export, Deutschland, EUR, ODbL", "asOf": today.strftime("%Y-%m"),
           "days": args.days, "minimumPrices": args.min, "rowsSeen": result["rowsSeen"], "entries": result["entries"]}
    if args.write:
        OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=False) + "\n", encoding="utf-8")
        print("geschrieben:", OUT.relative_to(R))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
