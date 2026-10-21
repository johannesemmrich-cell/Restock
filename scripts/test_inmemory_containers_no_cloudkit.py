#!/usr/bin/env python3
"""Strukturtest (Issue #194): Jeder In-Memory-Testspeicher in RestockTests/ schaltet die CloudKit-Spiegelung ab.

`ModelConfiguration(isStoredInMemoryOnly: true)` lässt `cloudKitDatabase` auf `.automatic`; der Test-Host trägt die
iCloud-Berechtigung, der Aufbau scheitert im Simulator ohne Konto, und iOS 27 entfernt daraufhin den Speicher —
der nächste `save()` reißt den Test-Host ab („No eligible connection available"). Deshalb muss im selben
`ModelConfiguration(...)`-Aufruf `cloudKitDatabase: .none` stehen, auch wenn der Aufruf über mehrere Zeilen geht."""
import re
import unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
TESTS = R / "RestockTests"
# Jeder Wert außer dem Literal `false` zählt: `true`, `:true` ohne Leerzeichen, Variablen (Adversary F002).
MARKER = re.compile(r"isStoredInMemoryOnly\s*:(?!\s*false\b)")
REQUIRED = "cloudKitDatabase: .none"


def _call_text(text: str, marker_pos: int) -> str:
    """Liefert den `ModelConfiguration(...)`-Aufruf, der die Markierung an `marker_pos` enthält."""
    start = text.rfind("ModelConfiguration(", 0, marker_pos)
    if start < 0:
        return text[max(0, marker_pos - 200):marker_pos + 200]
    depth, i = 0, start + len("ModelConfiguration")
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    return text[start:]


def violations_in(text: str, name: str = "<text>") -> list[str]:
    found = []
    for m in MARKER.finditer(text):
        if REQUIRED not in _call_text(text, m.start()):
            found.append(f"{name}:{text.count(chr(10), 0, m.start()) + 1}")
    return found


class InMemoryContainersDisableCloudKit(unittest.TestCase):
    def test_every_inmemory_container_in_tests_sets_cloudkit_none(self):
        found = []
        for path in sorted(TESTS.glob("*.swift")):
            found += violations_in(path.read_text(encoding="utf-8"), str(path.relative_to(R)))
        self.assertEqual(found, [], "In-Memory-Container ohne `cloudKitDatabase: .none`:\n  " + "\n  ".join(found))

    def test_detector_sees_multiline_calls(self):
        sample = (
            "let a = try ModelContainer(for: schema, configurations: ModelConfiguration(\n"
            "    isStoredInMemoryOnly: true\n"
            "))\n"
            "let b = ModelConfiguration(schema: schema,\n"
            "    isStoredInMemoryOnly: true,\n"
            "    cloudKitDatabase: .none)\n"
        )
        self.assertEqual(violations_in(sample, "Beispiel.swift"), ["Beispiel.swift:2"])

    def test_detector_sees_spelling_variants_and_ignores_false(self):
        sample = (
            "let a = ModelConfiguration(isStoredInMemoryOnly: true)\n"
            "let b = ModelConfiguration(isStoredInMemoryOnly:true)\n"
            "let c = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)\n"
            "let d = ModelConfiguration(isStoredInMemoryOnly: false)\n"
            "let e = ModelConfiguration(isStoredInMemoryOnly:true, cloudKitDatabase: .none)\n"
        )
        self.assertEqual(violations_in(sample, "V.swift"), ["V.swift:1", "V.swift:2", "V.swift:3"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
