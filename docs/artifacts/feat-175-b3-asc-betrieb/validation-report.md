# Validation Report: feat-175-b3-asc-betrieb (B3b)

Datum: 2026-10-25, geprüfter Stand `ef67b92` (sha256 `asc_check.py` 9f7f05a7…, `test_asc_check.py` 1ad9cb07…, identisch mit dem Prüfdialog)

## Tests
- `scripts/test_asc_check.py`: 39 Tests OK
- `scripts/test_asc_scripts.py`: 15 Tests OK
- `scripts/test_asc_texts.py`: 10 Tests OK
- übrige CI-Strukturtests (`build-price-catalog.py --check`, `test_price_catalog_build`, `test_open_prices_medians`,
  `test_ui_tests_discard_community_prices`, `test_inmemory_containers_no_cloudkit`): OK
- Swift/Xcode: nicht betroffen (keine App-Datei geändert)

## Spec-Abgleich (unabhängige Lektüre)
- AC-23, AC-23a, AC-23b, AC-23d, AC-23e: erfüllt
- AC-23c: erfüllt; mehrere gültige Einträge mit Betrag 0 gelten als „ok“ (= Prüfdialog F002, LOW, unschädlich)

## Echtlauf (Definition of Done)
`asc-check-lauf-3-2026-10-25.txt`: Datenschutzseite „ok HTTP-Status“ (nur Inhaltsabweichung), Altersfreigabe, App-Preis
und Verfügbarkeit als Abweichung, keine Zeile „Fehler“. Die Kopfzeile nennt `f8d41fb` (RED), weil der Korrekturcode beim
Lauf noch nicht eingecheckt war; Ausgaben wie „Ist nicht eingerichtet“ und der 200 der Datenschutzseite erzeugt nur der
Korrekturcode. Echter Kontobefund: „Basisland: Soll DEU, Ist USA“.

## Regression
Keine; Bestand AC-20 bis AC-22g in derselben Suite grün.

## Umfang
Code: 2 Dateien, `asc_check.py` +68/−8, `test_asc_check.py` +170/−4 (zusammen 250). Übrige Dateien: Spec, Kontext,
Briefing, Nachweise.

## Ergebnis: PASS
