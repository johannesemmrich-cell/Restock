---
spec_file: docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md
spec_sha256: dd2ac8df639c4f6891ef2059f853dd94268a2e3e071da4e72d795f67a0da9e6f
spec_frozen_sha256: 8d22a64fc711eedf3deb879725f79e890d8b31667ea69f7ca1e31a7827845000
---

# PO-Briefing: test-145-testluecken-98

- **Spec:** docs/specs/ui-tests/test-145-durchgang-1-dev-passwort.md
- **Issue:** #145
- **Erstellt:** 2026-10-15

## Was gebaut wird

Ein automatischer Test prüft, dass ein richtiges Entwickler-Passwort den Entwicklermodus freischaltet und dieser einen Neustart überlebt.

## Definition of Done

Neue Tests sind grün, die gesamte Testsuite bleibt grün, der Release-Build enthält die Testhilfen nicht, und ein Durchlauf im Simulator ist registriert.

## Wie geprüft wird

Freischalten, Pro-Anzeige, DEV-Markierung und Neustart werden mit Testpasswort geprüft; nicht geprüft wird das echte Passwort.

## Kritische Anmerkungen

- Getestet wird mit ausgetauschtem Prüfwert; das echte Passwort und der Release-Weg bleiben ungetestet, nur per Vergleich belegt.
- Zwei kleine Änderungen am App-Code (nur Testversion), obwohl das Ticket nur „Test“ verlangt; bewusst entschieden.
- Das Aufräumen nach dem Test hat keinen eigenen Test; es zeigt sich erst im gemeinsamen Gesamtlauf.

## Freigabe-Frage

Soll Durchgang 1 (Entwickler-Passwort) so gebaut werden, mit den drei anderen Durchgängen als offen?
