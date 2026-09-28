#!/usr/bin/env python3
"""Legt die Bon-Übergabe (`ReceiptShareHandoff`) direkt in den App-Gruppen-Speicher des
Simulators — der Weg, den sonst die Teilen-Erweiterung geht.

Reproduziert Issue #50, Punkt 4 OHNE jede Änderung an App- oder Testcode: Die Nutzlast
entspricht der bestehenden UI-Test-Fixture plus EINER Zeile (`BTR`), bei der
`name == originalName && !resolvedByAI` gilt — genau die Konstellation, die die Fixture
per „Invariante 1 — Fixture-Determinismus" ausschließt und die auf einem echten Bon
alltäglich ist.
"""
import json
import plistlib
import sys
from pathlib import Path

GROUP = "group.com.johannesemmrich.SmartCart"
KEY = "pendingShareExtensionReceipt"

container = Path(sys.argv[1])
payload = Path(__file__).with_name("repro-payload.json")

plist_path = container / "Library" / "Preferences" / f"{GROUP}.plist"
data = plist_path.read_bytes()
prefs = plistlib.loads(data)

prefs[KEY] = json.dumps(json.loads(payload.read_text(encoding="utf-8"))).encode("utf-8")
plist_path.write_bytes(plistlib.dumps(prefs, fmt=plistlib.FMT_BINARY))

print(f"Nutzlast gelegt: {len(prefs[KEY])} Bytes -> {plist_path}")
