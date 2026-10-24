#!/usr/bin/env python3
"""B1-Nachweis für #175 (AC-9, AC-9a bis AC-9d): prüft docs/appstore/{de,en,datenschutz}.md.

Aufruf aus dem Repo-Wurzelordner: python3 docs/artifacts/feat-175-b1-store-texte/check_b1.py
Exit 0 nur, wenn alle Prüfungen bestehen. Der dauerhafte Test folgt in B2 (scripts/test_asc_texts.py).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FIELDS = ["name", "subtitle", "keywords", "promotional_text", "description", "support_url", "privacy_url"]
FORBIDDEN = ["nachkauf", "erinnerung", "replenish", "reminder", "open prices", "ki-preis", "ai price",
             "was ist neu", "what's new"]
KEYWORD_FORBIDDEN = ["einkaufsliste", "shopping list", "restock"]
PRIVACY_URL = "https://emmrich-business.com/datenschutz"
EULA_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
SUPPORT_URL = "https://emmrich-business.com/support.html"

failures = []
lines = []


def check(ok, text):
    lines.append(("ok   " if ok else "FAIL ") + text)
    if not ok:
        failures.append(text)


def sections(text):
    parts = re.split(r"^## (.+)$", text, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts), 2)]


def check_store_file(lang):
    path = ROOT / "docs/appstore" / f"{lang}.md"
    check(path.exists(), f"{lang}: Datei {path.relative_to(ROOT)} existiert")
    if not path.exists():
        return None
    secs = sections(path.read_text(encoding="utf-8"))
    check([h for h, _ in secs] == FIELDS, f"{lang}: Überschriften genau {FIELDS} (gefunden {[h for h, _ in secs]})")
    values = dict(secs)
    for field in FIELDS:
        check(bool(values.get(field)), f"{lang}: {field} nicht leer")
    name, sub = values.get("name", ""), values.get("subtitle", "")
    promo, desc, kw = values.get("promotional_text", ""), values.get("description", ""), values.get("keywords", "")
    check(2 <= len(name) <= 30, f"{lang}: name {len(name)} Zeichen (2–30)")
    check(len(sub) <= 30, f"{lang}: subtitle {len(sub)} Zeichen (≤ 30)")
    check(len(promo) <= 170, f"{lang}: promotional_text {len(promo)} Zeichen (≤ 170)")
    check(len(desc) <= 4000, f"{lang}: description {len(desc)} Zeichen (≤ 4000)")
    check(len(kw.encode("utf-8")) <= 100, f"{lang}: keywords {len(kw.encode('utf-8'))} Bytes, {len(kw)} Zeichen (≤ 100 Bytes)")
    words = [w.strip() for w in kw.split(",")]
    check(all(len(w) > 2 for w in words), f"{lang}: jedes Schlüsselwort > 2 Zeichen")
    check(not any(f in kw.lower() for f in KEYWORD_FORBIDDEN), f"{lang}: Schlüsselwörter ohne {KEYWORD_FORBIDDEN}")
    whole = path.read_text(encoding="utf-8").lower()
    found = [f for f in FORBIDDEN if f in whole]
    check(not found, f"{lang}: keine verbotenen Begriffe (gefunden {found})")
    check(PRIVACY_URL in desc and EULA_URL in desc, f"{lang}: Beschreibung nennt Datenschutz- und EULA-URL")
    check(values.get("support_url") == SUPPORT_URL, f"{lang}: support_url = {SUPPORT_URL}")
    return values.get("privacy_url")


def normalized(block):
    return [re.sub(r"\s+", " ", l).strip() for l in block.splitlines() if l.strip()]


def check_privacy_page():
    path = ROOT / "docs/appstore/datenschutz.md"
    check(path.exists(), "datenschutz: Datei docs/appstore/datenschutz.md existiert")
    if not path.exists():
        return
    secs = dict(sections(path.read_text(encoding="utf-8")))
    check("Deutsch" in secs and "English" in secs, "datenschutz: Abschnitte ## Deutsch und ## English")
    swift = (ROOT / "SmartCart/Views/Settings/LegalView.swift").read_text(encoding="utf-8")
    legal = re.search(r'privacyPolicy = """\n(.*?)\n"""', swift, flags=re.S).group(1)
    check(normalized(secs.get("Deutsch", "")) == normalized(legal), "datenschutz: Deutsch wortgleich mit LegalView.privacyPolicy")
    english = secs.get("English", "").lower()
    check("german version" in english and "prevail" in english, "datenschutz: English nennt die deutsche Fassung als maßgeblich")


privacy = [check_store_file(lang) for lang in ("de", "en")]
check(privacy[0] == privacy[1] == PRIVACY_URL, f"privacy_url in beiden Dateien = {PRIVACY_URL}")
check_privacy_page()

out = "\n".join(lines) + f"\n\n{len(lines) - len(failures)} ok, {len(failures)} FAIL\n"
print(out)
(Path(__file__).parent / "laengen.txt").write_text(out, encoding="utf-8")
sys.exit(1 if failures else 0)
