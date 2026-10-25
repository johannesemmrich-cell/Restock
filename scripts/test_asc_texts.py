#!/usr/bin/env python3
"""Dauerhafter Texttest der Store-Texte (Issue #175, Durchgang B2b, AC-9 bis AC-9e und AC-21 der Spec
docs/specs/appstore/app-store-auftritt.md). Liest nur Repo-Dateien, ohne Netz; Logik aus
docs/artifacts/feat-175-b1-store-texte/check_b1.py plus Merkpunkt F001 der B1-Prüfung."""
import re, unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
FIELDS = ["name", "subtitle", "keywords", "promotional_text", "description", "support_url", "privacy_url"]
FORBIDDEN = ["nachkauf", "erinnerung", "replenish", "reminder", "open prices", "ki-preis", "ai price",
             "was ist neu", "what's new"]
KEYWORD_FORBIDDEN = ["einkaufsliste", "shopping list", "restock"]
PRIVACY_URL = "https://emmrich-business.com/datenschutz"
EULA_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
SUPPORT_URL = "https://emmrich-business.com/support.html"
INVISIBLE = {"​": "U+200B", " ": "U+00A0", "­": "U+00AD", "﻿": "U+FEFF", "\r": "CR"}
SPEC = R / "docs/specs/appstore/app-store-auftritt.md"
LABELS = {"name": "Name", "subtitle": "(?:Untertitel|Subtitle)", "keywords": "(?:Schlüsselwörter|Keywords)",
          "promotional_text": "(?:Werbetext|Promotional text)"}


def sections(text):
    parts = re.split(r"^## (.+)$", text, flags=re.M)
    return [(parts[i].strip(), parts[i + 1].strip()) for i in range(1, len(parts), 2)]


def store(lang):
    return dict(sections((R / f"docs/appstore/{lang}.md").read_text(encoding="utf-8")))


def normalized(block):
    return [re.sub(r"\s+", " ", l).strip() for l in block.splitlines() if l.strip()]


def spec_texts(heading):
    """Feldwerte aus dem Abschnitt „Texte“ der Spec (### Deutsch / ### English)."""
    spec = SPEC.read_text(encoding="utf-8")
    block = re.search(rf"^### {heading}\n(.*?)(?=^### )", spec, flags=re.M | re.S).group(1)
    got = {f: re.search(rf"^- \*\*{label} \(≤ [^)]*\):\*\* `([^`]+)`", block, flags=re.M).group(1)
           for f, label in LABELS.items()}
    got["description"] = re.search(r"```\n(.*?)\n```", block, flags=re.S).group(1).strip()
    return got


class AscTexts(unittest.TestCase):
    def test_sections_present_and_not_empty(self):  # AC-9
        for lang in ("de", "en"):
            secs = sections((R / f"docs/appstore/{lang}.md").read_text(encoding="utf-8"))
            self.assertEqual([h for h, _ in secs], FIELDS, lang)
            self.assertTrue(all(v for _, v in secs), lang)

    def test_field_limits(self):  # AC-9a
        for lang in ("de", "en"):
            v = store(lang)
            self.assertTrue(2 <= len(v["name"]) <= 30, lang)
            self.assertLessEqual(len(v["subtitle"]), 30, lang)
            self.assertLessEqual(len(v["promotional_text"]), 170, lang)
            self.assertLessEqual(len(v["description"]), 4000, lang)

    def test_keywords_bytes_and_word_length(self):  # AC-9a
        for lang in ("de", "en"):
            kw = store(lang)["keywords"]
            self.assertLessEqual(len(kw.encode("utf-8")), 100, lang)
            self.assertTrue(all(len(w.strip()) > 2 for w in kw.split(",")), lang)

    def test_forbidden_terms_absent(self):  # AC-9b
        for lang in ("de", "en"):
            whole = (R / f"docs/appstore/{lang}.md").read_text(encoding="utf-8").lower()
            self.assertEqual([f for f in FORBIDDEN if f in whole], [], lang)
            kw = store(lang)["keywords"].lower()
            self.assertEqual([f for f in KEYWORD_FORBIDDEN if f in kw], [], lang)

    def test_description_links_and_urls(self):  # AC-9c
        for lang in ("de", "en"):
            v = store(lang)
            self.assertIn(PRIVACY_URL, v["description"], lang)
            self.assertIn(EULA_URL, v["description"], lang)
            self.assertEqual((v["privacy_url"], v["support_url"]), (PRIVACY_URL, SUPPORT_URL), lang)

    def test_privacy_page_equals_legalview(self):  # AC-9d
        secs = dict(sections((R / "docs/appstore/datenschutz.md").read_text(encoding="utf-8")))
        self.assertIn("Deutsch", secs)
        swift = (R / "SmartCart/Views/Settings/LegalView.swift").read_text(encoding="utf-8")
        legal = re.search(r'privacyPolicy = """\n(.*?)\n"""', swift, flags=re.S).group(1)
        self.assertEqual(normalized(secs["Deutsch"]), normalized(legal))

    def test_privacy_page_english_notes_german_authoritative(self):  # AC-9d
        english = dict(sections((R / "docs/appstore/datenschutz.md").read_text(encoding="utf-8")))["English"].lower()
        self.assertIn("german version", english)
        self.assertIn("prevail", english)

    def test_values_equal_spec_wording(self):  # AC-9e
        for lang, heading in (("de", "Deutsch"), ("en", "English")):
            v, want = store(lang), spec_texts(heading)
            for field, value in want.items():
                self.assertEqual(v[field], value, f"{lang}: {field}")
            self.assertEqual((v["support_url"], v["privacy_url"]), (SUPPORT_URL, PRIVACY_URL), lang)

    def test_no_invisible_characters_cr_or_bom(self):  # AC-9e
        for name in ("de.md", "en.md", "datenschutz.md"):
            raw = (R / "docs/appstore" / name).read_bytes()
            self.assertFalse(raw.startswith(b"\xef\xbb\xbf"), f"{name}: BOM")
            text = raw.decode("utf-8")
            self.assertEqual([code for ch, code in INVISIBLE.items() if ch in text], [], name)

    def test_ci_runs_asc_tests(self):  # AC-21
        ci = (R / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        step = re.search(r"- name: Strukturtests \(Python\)\n(.*?)(?=\n      - name: )", ci, flags=re.S)
        self.assertIsNotNone(step, "Schritt „Strukturtests (Python)“ fehlt")
        loop = re.search(r"for t in (.*?); do", step.group(1), flags=re.S)
        self.assertIsNotNone(loop, "Schleife im Schritt fehlt")
        for name in ("scripts/test_asc_texts.py", "scripts/test_asc_scripts.py", "scripts/test_asc_check.py"):
            self.assertIn(name, loop.group(1))


if __name__ == "__main__":
    unittest.main()
