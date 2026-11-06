#!/usr/bin/env python3
"""Strukturtest des App-Store-Kopfbilds (Issue #241, AC-1 bis AC-4 und AC-7 der Spec
docs/specs/appstore/kopfbild.md). Liest nur Repo-Dateien, ohne Chrome und ohne Netz; das Rendern selbst
belegt docs/artifacts/feat-241-kopfbild/render-protokoll.txt."""
import json, re, struct, unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
TEMPLATE = R / "scripts/header-image/kopfbild.html"
SCRIPT = R / "scripts/make-header-image.sh"
OUT = R / "docs/artifacts/feat-241-kopfbild"
SIZES = ["5244x2950", "3840x1646"]
TEXTS = {
    "de": ["Die Liste, die weiß, wo etwas hingehört.",
           "Restock lernt deinen Weg durch den Markt und rechnet mit Preisen aus deinen Kassenbons."],
    "en": ["The list that knows where things belong.",
           "Restock learns your way through the store and works out costs from your receipts."],
}


def template():
    return TEMPLATE.read_text(encoding="utf-8")


def colorset_hex(name):
    """Hellwert (Eintrag ohne `appearances`) eines Colorsets als #RRGGBB."""
    data = json.loads((R / f"SmartCart/Assets.xcassets/{name}.colorset/Contents.json").read_text())
    light = next(c for c in data["colors"] if "appearances" not in c)["color"]["components"]
    return "#" + "".join(f"{round(float(light[k]) * 255):02X}" for k in ("red", "green", "blue"))


def png_info(path):
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", f"{path.name}: kein PNG"
    width, height, _depth, color_type = struct.unpack(">IIBB", raw[16:26])
    return width, height, color_type, b"tRNS" in raw


class HeaderImageTests(unittest.TestCase):
    def test_template_and_script_exist(self):
        self.assertTrue(TEMPLATE.is_file(), "Vorlage scripts/header-image/kopfbild.html fehlt")
        self.assertTrue(SCRIPT.is_file(), "scripts/make-header-image.sh fehlt")

    def test_script_names_both_target_sizes_and_languages(self):
        text = SCRIPT.read_text(encoding="utf-8")
        for size in SIZES:
            for part in size.split("x"):
                self.assertIn(part, text)
        for lang in TEXTS:
            self.assertIn(lang, text)

    def test_texts_appear_exactly_once_per_language(self):
        html = template()
        for lang, lines in TEXTS.items():
            for line in lines:
                self.assertEqual(html.count(line), 1, f"{lang}: „{line}“ nicht genau einmal in der Vorlage")

    def test_colors_match_light_values_of_colorsets(self):
        html = template().upper()
        for name in ("RCCanvas", "RCSurface", "RCAccent"):
            self.assertIn(colorset_hex(name), html, f"{name} ({colorset_hex(name)}) fehlt in der Vorlage")

    def test_four_pngs_have_exact_size_and_no_alpha(self):
        for lang in TEXTS:
            for size in SIZES:
                path = OUT / f"kopfbild-{lang}-{size}.png"
                self.assertTrue(path.is_file(), f"{path.name} fehlt")
                width, height, color_type, has_trns = png_info(path)
                self.assertEqual(f"{width}x{height}", size, f"{path.name}: falsche Pixelmaße")
                self.assertNotIn(color_type, (4, 6), f"{path.name}: Alphakanal (Farbtyp {color_type})")
                self.assertFalse(has_trns, f"{path.name}: tRNS-Chunk (Transparenz)")

    def test_render_protocol_exists(self):
        self.assertTrue((OUT / "render-protokoll.txt").is_file(), "render-protokoll.txt fehlt")


if __name__ == "__main__":
    unittest.main()
