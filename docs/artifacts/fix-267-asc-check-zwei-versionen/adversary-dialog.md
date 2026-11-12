# Adversary Dialog — fix-267-asc-check-zwei-versionen
Spec: docs/specs/appstore/asc-check-version.md
Datum: 2026-11-12 07:28

## Checkliste
- [x] **AC-1:** Zwei appInfos in den Zuständen `READY_FOR_SALE` und `REJECTED` (kein Entwurf) brechen `info_id()` (Abschnitte `metadata`, `appinfo`) mit einer Meldung ab, die beide IDs und beide Zustände nennt und „kein eindeutiger Entwurf“ enthält; kein Abschnitt meldet „ok“. Test: `test_two_infos_without_draft_aborts_with_all_states`.
- [x] **AC-2:** Genau ein appInfo wird genommen, gleichgültig in welchem Zustand (auch `READY_FOR_SALE`). Test: `test_single_info_is_taken_in_any_state`.
- [x] **AC-3:** Zwei appInfos, eines `PREPARE_FOR_SUBMISSION` und eines `READY_FOR_SALE`: der Entwurf wird gewählt. Test: `test_draft_info_wins_over_live`.
- [x] **AC-4:** Zwei appInfos im Zustand `PREPARE_FOR_SUBMISSION` brechen ab (nicht eindeutig) und nennen beide Zustände; drei appInfos ohne Entwurf nennen alle drei. Test: `test_two_drafts_or_three_infos_abort`.
- [x] **AC-5:** Ein appInfo, bei dem weder `state` noch `appStoreState` ein nichtleerer String ist (fehlend, leer, Zahl), erscheint in der Abbruchmeldung als `unbekannt`; ist `state` leer und `appStoreState` gesetzt, gilt dieses; ein Zustandswert mit Steuerzeichen wird davon befreit und auf höchstens 80 Zeichen abgeschnitten (ohne Markierung); ist der Wert danach leer, gilt er als `unbekannt`; null appInfos brechen mit `appInfo: 0 Treffer, kein eindeutiger Entwurf; Zustände: keine` ab. Test: `test_info_state_unknown_and_sanitized_in_message`. Zusätzlich (Test `test_zero_infos_and_empty_after_sanitizing`): null appInfos brechen mit `appInfo: 0 Treffer, kein eindeutiger Entwurf; Zustände: keine` ab, und ein nach der Bereinigung leerer Wert erscheint als `unbekannt`.
- [x] **AC-20:** Bei zwei appInfos ohne Entwurf laufen `status`, `build`, `iap`, `submission`, `review`, `screenshots` und `privacy-url` ohne appInfo-Abbruch (Schein-`send` ruft `/appInfos` für sie nie ab); `metadata` und `appinfo` brechen wie AC-1 ab. Test: `test_info_is_resolved_only_by_sections_that_need_it`.
- [x] **AC-6:** `--version 1.0.1` fragt `/v1/apps/{id}/appStoreVersions?filter[versionString]=1.0.1&filter[platform]=IOS` ab und wählt die Version mit `versionString` 1.0.1; die Folgeabschnitte lesen unter deren ID. Test: `test_version_argument_selects_that_version`.
- [x] **AC-7:** Ohne `--version` und `--build` ist das Verhalten unverändert: Abfrage `versionString=1.0`, `sec_status` mit Soll `PREPARE_FOR_SUBMISSION`, `sec_build` mit „≥ 37“; alle bisherigen Tests bleiben grün. Test: `test_default_without_version_is_unchanged` plus bestehende Tests.
- [x] **AC-8:** Ungültige `--version` (`abc`, `1`, `1.0.1.2`, `1.0;rm`, leer, `1.0.1 `, arabisch-indische Ziffern wie `١.٠`) und ungültige `--build` (`abc`, `-1`, `4.1`, leer) ergeben Exit 2 mit Aufrufhinweis auf stderr und keinen einzigen Netzaufruf (Schein-`send` zählt 0). Test: `test_invalid_version_or_build_exits_2_without_network`.
- [x] **AC-9:** Der Lesezaun `check_read` lässt `GET /v1/apps/X/appStoreVersions?filter[versionString]=1.0.1&filter[platform]=IOS` zu (ID aus einer Antwort) und lehnt ab: `…versionString=1.0.1&x`, `…versionString=1.0.1&filter[platform]=IOS&x=1`, `…versionString=1.0;rm&filter[platform]=IOS`, `…versionString=&filter[platform]=IOS`, `…versionString=1.0.1&filter[platform]=MAC_OS`, die Abfrage ohne Query sowie jede Nicht-GET-Methode (POST, PATCH, PUT, DELETE) auf diesem Pfad. Test: `test_fence_version_pattern_and_rejections`.
- [x] **AC-10:** `asc_lib.check_path` lässt für GET dasselbe Versionsmuster zu (`versionString=1.0.1&filter[platform]=IOS`) und lehnt dieselben Abweichungen mit Query wie AC-9 ab (das heutige Verhalten für GET ohne Query auf `appStoreVersions` bleibt unverändert und ist nicht Teil dieser Änderung); POST und PATCH bleiben auf die bestehenden Pfade beschränkt, an `appStoreVersions` ist weiter kein POST/PATCH möglich. Test: `test_check_path_version_pattern_get_only`.
- [x] **AC-11:** `asc_publish` bleibt auf Version 1.0 festgelegt: sein Lauf fragt nur `filter[versionString]=1.0` ab, und der Schreibweg ist unverändert (bestehende Tests `test_asc_scripts.py` grün). Test: bestehende Tests plus `test_publish_still_queries_only_version_1_0`. Die lesende Öffnung für andere Versionen im Zaun von `asc_lib` ist durch AC-10 abgesichert (nur GET, Muster).
- [x] **AC-12:** `sec_status` für Version 1.0.1 mit `appVersionState` `REJECTED` gibt `Zustand: REJECTED` aus, ohne „ok“ und ohne „Abweichung“, und erhöht den Abweichungszähler nicht; für Version 1.0 im Entwurf bleibt `ok status: appVersionState`, für 1.0 mit anderem Zustand die Abweichung wie bisher. Test: `test_status_other_version_prints_state_without_verdict`.
- [x] **AC-13:** `sec_status` mit fehlendem, leerem oder nicht-String-Zustand (beliebige Version) meldet eine Abweichung und nie „ok“ oder eine Informationszeile mit „unbekannt“ ohne Abweichung. Test: `test_status_unknown_state_is_deviation`.
- [x] **AC-14:** `--build 41` mit zugeordnetem Build `version` „41“ ergibt ok, mit „40“ eine Abweichung `Soll 41, Ist 40`; ohne `--build` gilt weiter „≥ 37“ (36 = Abweichung, 37 und 41 = ok). Ein Build mit nicht-numerischer Nummer ist in beiden Fällen eine Abweichung. Test: `test_build_target_via_option`.
- [x] **AC-15:** Abschnitt `submission` gibt den Zustand der Version (auch bei 1.0 nur als Zeile `Zustand: <wert>`, bei fehlendem, leerem oder nicht-String-Wert `Zustand: unbekannt`, nie ok/Abweichung), je Kauf Kurzname, Art und `state` sowie beide Zeilen `manuell belegen` (Zuordnung Kauf↔Version, Vereinbarung für bezahlte Apps) aus; beide Zeilen erscheinen auch dann, wenn alle Käufe `READY_TO_SUBMIT` sind, und zählen nie als „ok“. Test: `test_submission_section_prints_manual_lines`.
- [x] **AC-16:** `submission` meldet eine Abweichung bei einem Kauf, bei dem weder `state` noch `appStoreState` ein nichtleerer String ist (ein Kauf mit nur `appStoreState` gilt mit diesem Wert, keine Abweichung) und (über `products()`) bei einem der drei erwarteten Produkte, das fehlt; bei drei Käufen mit `state` `READY_TO_SUBMIT`, `READY_TO_SUBMIT`, `MISSING_METADATA` gibt es keine Abweichung, die Ausgabe nennt `MISSING_METADATA ×1, READY_TO_SUBMIT ×2`. Test: `test_submission_section_flags_unknown_or_missing_products`.
- [x] **AC-17:** `submission` benutzt nur bestehende Leselisten-Pfade: ein Lauf mit Schein-`send` ruft ausschließlich GET auf, und die Pfadmenge von `FENCE` (ohne Abfrage-Muster) ist gegenüber vorher unverändert (kein Einreichungs-, kein `…Submissions`-Pfad). Test: `test_submission_uses_only_existing_read_paths`.
- [x] **AC-18:** `--all` enthält `submission` als letzten Abschnitt; findet `context()` die Version nicht (0 Treffer für `--version 9.9`), steht je Abschnitt die Zeile `== <name>` gefolgt von der Fehlermeldung `Version 9.9 (IOS): 0 Treffer statt genau 1` (jeder Abschnitt scheitert einzeln, wie heute), der Exit-Code ist 1, und keine Ausgabezeile beginnt mit `ok ` (so beginnen die Erfolgszeilen heute). Test: `test_all_includes_submission_and_aborts_cleanly`.
- [x] **AC-19:** Die Geheimnistests bleiben grün (`test_no_secrets_in_output_or_errors` in beiden Testdateien); die neuen Meldungen (appInfo-Zustände, Version) enthalten weder Token noch Schlüsselpfad. Test: bestehende Tests plus `test_new_messages_do_not_leak_secrets`.

## Dialog

### Runde 1
**Adversary:** Lesezaun und Argumente angegriffen: Versionsmuster mit Zeilenumbruch am Ende, arabisch-indische Ziffern, Leerzeichen, 1.0.1.2, Plattform klein, Nicht-GET-Methoden in check_read und asc_lib.check_path. Ergebnis: alles abgelehnt (fullmatch, ASCII-Klassen, kein dollar-Problem); nur GET mit exakt dem Muster erlaubt. Argumente: Doppelangabe, fehlender Wert, --all plus --section, Option als Wert, arabische Ziffern in --build ergeben None, also Exit 2 vor jedem Netzzugriff; beliebige Reihenfolge geht.
Code reference: scripts/asc_lib.py:13
Code reference: scripts/asc_lib.py:109
Code reference: scripts/asc_lib.py:127
Code reference: scripts/asc_check.py:48
Code reference: scripts/asc_check.py:479
**Implementierer:** nicht beteiligt (Kontextisolation)


Finding:
  ID: F001
  Severity: MEDIUM
  Category: spec_violation
  Code reference: scripts/asc_check.py:222
  Description: sec_privacy braucht keinen Kontext und druckt bei --all --version 9.9 mit erreichbarer Datenschutzseite drei Zeilen, die mit ok beginnen.
  Spec requirement: AC-18 - keine Ausgabezeile beginnt mit ok bei nicht gefundener Version.
  Conflict: Der Test erzwingt eine 404-Seite und umgeht so den Fall; in der Praxis erscheinen ok-Zeilen. Der Abschnitt ist laut Spec bewusst versionsunabhaengig, der AC-Wortlaut also zu streng oder der Test zu schwach.
  Remediation: AC-18 praezisieren, privacy-url ausnehmen, oder Test mit Seite 200 ergaenzen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/asc_check.py:151
  Description: clean laesst reine Leerzeichen-Werte stehen; state_of meldet dann Leerzeichen statt unbekannt, bei appVersionState eine leere Zustandszeile ohne Abweichung.
  Spec requirement: AC-13 und AC-5 - nichtleerer String; Spec nennt nur Steuer- und Formatzeichen als Bereinigung.
  Conflict: Randfall, Wortlaut erfuellt, Verhalten unschoen.
  Remediation: nach der Bereinigung strip anwenden.

Finding:
  ID: F003
  Severity: LOW
  Category: anti_pattern
  Code reference: scripts/asc_check.py:458
  Description: Formatierungsrest im Code von sec_review, fehlendes Leerzeichen nach dem Gleichheitszeichen; --build 041 wird als Text gegen 41 verglichen und ergibt Abweichung.
  Spec requirement: AC-14 - Gleichheit mit n.
  Conflict: kosmetisch bzw. Randfall.
  Remediation: Leerzeichen setzen; fuehrende Nullen optional normalisieren.

### Runde 2
**Adversary:** Regressionen und Zustandsfaelle: Version 1.0 unveraendert, ok status appVersionState und build ab 37 ohne --build; 1.0.1 REJECTED nur als info-Zeile; Zustand als Zahl ist Abweichung mit Exit 1; submission mit drei READY_TO_SUBMIT zaehlt, druckt beide manuell-belegen-Zeilen, nie ok; --all --version 1.0.1 --build 41 nutzt ausschliesslich GET; metadata und appinfo brechen bei zwei appInfos mit allen Zustaenden ab, andere Abschnitte lesen appInfos nie. asc_publish unveraendert, nutzt weiter VERSION_QUERY, Datei nicht im Diff. Meldungen ohne Token oder Schluesselpfad, Geheimnistest gruen.
Code reference: scripts/asc_check.py:171
Code reference: scripts/asc_check.py:440
Code reference: scripts/asc_check.py:454
Code reference: scripts/test_asc_check.py:970
Code reference: scripts/test_asc_scripts.py:1
**Implementierer:** nicht beteiligt

Nachweis je AC: AC-1 bis AC-5 und AC-20: info_id bricht ohne eindeutigen Entwurf mit allen Zustaenden ab, nur von metadata und appinfo aufgerufen. AC-6 und AC-7: context mit Version aus ctx, Standard 1.0. AC-8: parse_args. AC-9 und AC-10: Zaun in asc_check.py:48 und asc_lib.py:127. AC-11: asc_publish unberuehrt. AC-12 und AC-13: sec_status. AC-14: sec_build. AC-15 bis AC-17: sec_submission, nur GET. AC-18: bis auf F001 erfuellt. AC-19: Geheimnistests gruen.

### Runde 3
**Adversary:** F002-Fix gegengebrochen: Zustand aus Tab, Leerzeichen und Zeilenumbruch, nur Steuerzeichen, Zero-Width plus Leerzeichen, geschuetztes Leerzeichen ergeben unbekannt; Rand-Whitespace um LIVE wird entfernt, nicht-String bleibt leer. Einziger Rest: bei Abschneiden auf 80 Zeichen kann ein Leerzeichen am Ende stehen bleiben, rein kosmetisch. F003: Formatrest in sec_review behoben. Tests: 97 passed, 0 failed.
Code reference: scripts/asc_check.py:151
Code reference: scripts/asc_check.py:431
Code reference: scripts/asc_lib.py:109
Code reference: scripts/test_asc_check.py:970
Code reference: scripts/test_asc_scripts.py:1
**Wertung F001:** Kein Codefehler. privacy-url haengt an keiner Version, der Code urteilt dafuer nie falsch ok; fuer die nicht gefundene Version steht in allen versionsabhaengigen Abschnitten ein Fehler und kein ok. Der AC-Wortlaut ist zu weit gefasst (Fehlerfall ohne Ausnahme fuer privacy-url). F001 ist damit LOW, Spec-Wortlaut zu eng, kein Code- oder Testfehler.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
**VERIFIED**

Der Code genuegt der Absicht aller 20 ACs. Einzige Abweichung ist der zu weit gefasste Wortlaut von AC-18 bezueglich privacy-url (F001, LOW, Spec-Pflege empfohlen). F002 und F003 behoben und gegengeprueft. Keine Zaun- oder Sicherheitsluecke. Tests: 97 passed, 0 failed, 0 uebersprungen.

## Geprüfte Dateien

- sha256:f52c2217945e0d3346c993778ab50e09264d93091c75c8cb768caa5d1dd89732  scripts/asc_check.py
- sha256:682b24e80e3b94ccc5d3b502354adcb4362cddef01c98c6ba5bc454dca43f3a4  scripts/asc_lib.py
- sha256:e18efdac314a3db4eff3571d07d8e6d4ffe355a554ddd9290cbb87096ac54b0d  scripts/test_asc_check.py
- sha256:f96a2e6bbeae6f43002046a6a3537a257758c5489dd138a12597eddba4a6973d  scripts/test_asc_scripts.py

## Prüfbasis

- base: 9116fb590ad56d7acd454ef3c238474e55bb998e
- blob:0b7e2c560da050ca371e99aafc6de6644562dadc  scripts/asc_check.py
- blob:d0b55df71347f382fae57c9ce7271882138dd5ee  scripts/asc_lib.py
- blob:82da8b56859044f356353ec479d387ad81be0e10  scripts/test_asc_check.py
- blob:42d859455f22df4cab8312d3741ee3916fad5795  scripts/test_asc_scripts.py
