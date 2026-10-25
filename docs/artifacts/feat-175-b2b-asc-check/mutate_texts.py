"""Gegenprobe: Die Texttests (AC-9…AC-9e) müssen an verdorbenen Kopien rot werden."""
import shutil, sys, tempfile, unittest
from pathlib import Path

REPO = Path(sys.argv[1])
sys.path.insert(0, str(REPO / "scripts"))
import test_asc_texts as t

MUTATIONS = [
    ("test_no_invisible_characters_cr_or_bom", "docs/appstore/de.md", lambda s: s.replace("Restock", "Re​stock", 1)),
    ("test_no_invisible_characters_cr_or_bom", "docs/appstore/en.md", lambda s: s.replace("\n", "\r\n")),
    ("test_no_invisible_characters_cr_or_bom", "docs/appstore/datenschutz.md", lambda s: "﻿" + s),
    ("test_values_equal_spec_wording", "docs/appstore/de.md", lambda s: s.replace("Einkaufsliste mit Ladenwahl", "Einkaufsliste mit Ladenwahl!")),
    ("test_values_equal_spec_wording", "docs/appstore/en.md", lambda s: s.replace("only the number is sent", "only the number gets sent").replace("Only the number is sent", "Only the number gets sent")),
    ("test_forbidden_terms_absent", "docs/appstore/de.md", lambda s: s.replace("Haushalt", "Nachkauf")),
    ("test_keywords_bytes_and_word_length", "docs/appstore/en.md", lambda s: s.replace("grocery,", "grocery,ab,")),
    ("test_field_limits", "docs/appstore/de.md", lambda s: s.replace("Einkaufsliste mit Ladenwahl", "Einkaufsliste mit Ladenwahl und noch mehr")),
    ("test_description_links_and_urls", "docs/appstore/en.md", lambda s: s.replace("stdeula/", "eula/")),
    ("test_privacy_page_equals_legalview", "docs/appstore/datenschutz.md", lambda s: s.replace("Stand: Oktober 2026", "Stand: September 2026", 1)),
    ("test_sections_present_and_not_empty", "docs/appstore/de.md", lambda s: s.replace("## keywords", "## schluesselwoerter")),
]

failed_as_expected = 0
for test, rel, mutate in MUTATIONS:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        for sub in ("docs/appstore", "docs/specs/appstore", "SmartCart/Views/Settings", ".github/workflows"):
            shutil.copytree(REPO / sub, root / sub)
        p = root / rel
        p.write_bytes(mutate(p.read_text(encoding="utf-8")).encode("utf-8"))
        t.R, t.SPEC = root, root / "docs/specs/appstore/app-store-auftritt.md"
        result = unittest.TextTestRunner(stream=open("/dev/null", "w")).run(t.AscTexts(test))
        red = not result.wasSuccessful()
        failed_as_expected += red
        print(("rot  (gefangen)  " if red else "GRÜN (NICHT gefangen) ") + f"{test} ← {rel}")
print(f"\n{failed_as_expected} von {len(MUTATIONS)} Verderbnissen gefangen")
sys.exit(0 if failed_as_expected == len(MUTATIONS) else 1)
