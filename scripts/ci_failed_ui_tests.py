#!/usr/bin/env python3
"""Issue #173, Fassung 2: liest die JSON-Ausgabe von
`xcrun xcresulttool get test-results tests --path <bundle> --compact` von stdin und gibt die Kennungen
der fehlgeschlagenen Testfälle aus (eine je Zeile, ohne das abschließende `()`, z. B.
`DataResetUITests/testAppUsableAfterEmergencyReset`), damit ci.yml genau diese Tests mit
`-only-testing:RestockUITests/<Kennung>` einmal erneut startet. Ohne fehlgeschlagene Testfälle: keine Ausgabe.
Keine Fremdbibliothek, läuft mit dem Python 3 des macOS-Runners."""
import json
import sys


def failed_test_identifiers(tree):
    """Alle Knoten vom Typ „Test Case“ mit Ergebnis „Failed“, in Dokumentreihenfolge, ohne Doppelte."""
    found = []

    def walk(node, suite):
        if isinstance(node, dict):
            node_type = node.get("nodeType", "")
            name = node.get("name", "")
            if node_type == "Test Case":
                if node.get("result") == "Failed":
                    ident = node.get("nodeIdentifier") or (f"{suite}/{name}" if suite else name)
                    ident = ident[:-2] if ident.endswith("()") else ident
                    if ident and ident not in found:
                        found.append(ident)
                return
            next_suite = name if node_type == "Test Suite" else suite
            for child in node.get("children", []) or []:
                walk(child, next_suite)
        elif isinstance(node, list):
            for item in node:
                walk(item, suite)

    walk(tree.get("testNodes", tree) if isinstance(tree, dict) else tree, "")
    return found


if __name__ == "__main__":
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        print(f"ci_failed_ui_tests: keine JSON-Ausgabe ({error})", file=sys.stderr)
        sys.exit(0)
    for ident in failed_test_identifiers(data):
        print(ident)
