#!/usr/bin/env python3
"""Legt eine Bon-Uebergabe mit GENAU EINER Position ("BTR") in den App-Gruppen-Speicher
des Simulators — derselbe Weg, den sonst die Teilen-Erweiterung geht.

Zweck: den reproduzierten Fehlerfall aus Issue #50 (Punkt 4) beim Benutzen der App am
Bildschirm zeigen, ohne scrollen zu muessen (der Simulator laeuft fensterlos, es gibt
keine Maus- oder Touch-Ereignisse). "BTR" loest sich ueber
ReceiptParserService.expandAbbreviations deterministisch zu "Butter" auf — vor dem Fix
blieb die Karte danach ohne markierte Zeile und zeigte weiter "BTR".

Keine Aenderung an App- oder Testcode.
"""
import json
import plistlib
import sqlite3
import uuid
from pathlib import Path

DEV = "8F696920-4B9A-40A7-96F0-7697BE887CC7"
GROUP_DIR = Path(
    f"/Users/hem/Library/Developer/CoreSimulator/Devices/{DEV}"
    "/data/Containers/Shared/AppGroup/1DCC318A-3AEB-4793-AA9F-2B25B14CB5CF"
)
GROUP = "group.com.johannesemmrich.SmartCart"
KEY = "pendingShareExtensionReceipt"

db = GROUP_DIR / "Library" / "Application Support" / "default.store"
con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
blob, name = con.execute("SELECT ZID, ZNAME FROM ZSTORE LIMIT 1").fetchone()
store_id = str(uuid.UUID(bytes=bytes(blob))).upper()
print(f"Laden: {name} / {store_id}")

payload = {
    "storeID": store_id,
    "storeConfidentlyDetected": True,
    "detectedTotal": 1.09,
    "rawLines": ["BTR"],
    "lines": [
        {
            "name": "BTR",
            "originalName": "BTR",
            "price": 1.09,
            "quantity": 1,
            "unit": "",
            "suggestions": [],
            "resolvedByAI": False,
        }
    ],
}

plist_path = GROUP_DIR / "Library" / "Preferences" / f"{GROUP}.plist"
prefs = plistlib.loads(plist_path.read_bytes())
prefs[KEY] = json.dumps(payload).encode("utf-8")
plist_path.write_bytes(plistlib.dumps(prefs, fmt=plistlib.FMT_BINARY))
print(f"Nutzlast gelegt: {len(prefs[KEY])} Bytes -> {plist_path}")
