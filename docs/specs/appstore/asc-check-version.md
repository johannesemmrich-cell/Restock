# Spec: asc_check liest beliebige Version, wählt das appInfo eindeutig, neuer Abschnitt `submission` (Issue #267)

Workflow: `fix-267-asc-check-zwei-versionen` · Fortsetzung von #265/#266 · Kontext: `docs/context/fix-267-asc-check-zwei-versionen.md`

## Problem
Apple hat 1.0.1 (Build 40) am 2026-11-09 mit 2.1(b) abgelehnt. Um zu klären, ob die Käufe angehängt sind, Build 41
hochgeladen ist und die Vereinbarung für bezahlte Apps gilt, muss `scripts/asc_check.py` den Stand von 1.0.1 lesen. Heute
bricht jeder Abschnitt mit `appInfo: 2 Treffer statt genau 1` ab. Ursachen (aus dem Code):
1. `context()` kennt nur Version „1.0“ (`VERSION_QUERY` in `asc_lib.py`, `FENCE` in `asc_check.py` als Festtext).
2. Die appInfo-Wahl nimmt nur `PREPARE_FOR_SUBMISSION`, sonst `one(infos)`; steht kein Eintrag mehr im Entwurf
   (1.0 live, 1.0.1 abgelehnt), greift `one` mit zwei Einträgen. `context()` ist allen Abschnitten gemeinsam, obwohl nur `metadata` und `appinfo` das appInfo brauchen.
3. `sec_status` verlangt starr `PREPARE_FOR_SUBMISSION`, `sec_build` starr „≥ 37“, `sec_iap` prüft die Käufe
   einzeln (Zustand `READY_TO_SUBMIT`), zeigt aber nie auf einen Blick, in welchem Zustand die Käufe stehen und was nicht
   lesbar ist; das leistet der neue Abschnitt `submission` (zeigt an und urteilt nur bei unbekanntem Kaufzustand oder fehlendem Produkt; `sec_iap` bleibt unverändert).

## Lösung (Regelweg, kein Modell: Zeichenmuster, Zustandsvergleich, nur lesen)
- **Aufruf:** `asc_check.py … [--version <x.y[.z]>] [--build <n>]`. Standard `--version 1.0` und Build-Soll „≥ 37“: der
  bisherige Aufruf bleibt unverändert. `--version` nur Ziffern und Punkte (`[0-9]+(\.[0-9]+){1,2}`), `--build` nur Ziffern 0–9; beide Optionen gelten mit `--section <name>` und mit `--all`, in beliebiger Reihenfolge, `--build` auch allein (ohne `--version` gilt 1.0); sonst
  Aufruf-Fehler, Meldung auf stderr, Exit 2 (wie bisher bei falschen Argumenten), kein Netzzugriff.
- **Zaun (`asc_lib.py`):** Die Konstante `VERSION_QUERY` (Festtext für 1.0) bleibt unverändert, weil `asc_publish.py:26`
  sie benutzt. Neu daneben: das Muster `VERSION_QUERY_RE = r"filter\[versionString\]=[0-9]+(?:\.[0-9]+){1,2}&filter\[platform\]=IOS"`
  (`re.fullmatch`) und die Hilfsfunktion `version_query(v)`, die nach demselben Muster prüft und die Abfrage baut. `check_path` (in `asc_lib.py`) sowie `FENCE` und `check_read` (beide in `asc_check.py`)
  vergleichen die Abfrage mit dem Muster statt mit dem Festtext (`FENCE` erlaubt neben `None` und festem Text auch ein
  kompiliertes Muster). Alles andere bleibt: nur GET für `asc_check`, feste Pfadlisten, IDs nur aus Antworten, keine
  Weiterleitungen, Schreibpfade von `asc_publish` unverändert; `asc_publish` fragt weiter nur Version 1.0 ab.
- **Version in `context()`:** Version und Plattform werden gegen die Abfrage gefiltert (`versionString == <Argument>`,
  IOS), genau ein Treffer; Meldung „Version <x> (IOS)“.
- **appInfo nur bei Bedarf:** `context()` liefert App und Version; das appInfo wird erst von den beiden Abschnitten gewählt, die es brauchen (`metadata`, `appinfo`; Hilfsfunktion `info_id(rd, ctx)`, Ergebnis im Zwischenspeicher). `privacy-url`, `iap`, `screenshots`, `build`, `review`, `status` und `submission` brechen nie wegen der appInfos ab. Damit ist der Stand von 1.0.1 (1.0 live, 1.0.1 abgelehnt, kein Entwurf-appInfo) für diese Abschnitte lesbar; die nur in `metadata`/`appinfo` abbrechende Wahl bleibt bewusst streng, bis die Zustandsliste des Live-Laufs eine weitere Regel begründet.
- **appInfo-Wahl in `info_id()`:** (a) genau ein appInfo → dieses; (b) sonst genau eines mit Zustand
  `PREPARE_FOR_SUBMISSION` → dieses; (c) sonst Abbruch (`RuntimeError`) mit Meldung
  `appInfo: <n> Treffer, kein eindeutiger Entwurf; Zustände: <id>=<state>, …` mit ALLEN appInfos. Nie raten, nie
  „ok“. Zustandswerte aus Apples Antwort werden bereinigt wie in `apple_error_suffix` (Steuer-/Formatzeichen entfernt,
  80 Zeichen; weder `state` noch `appStoreState` ein nichtleerer String = `unbekannt`); die IDs sind Apples eigene Kennungen, kein Geheimnis.
  Der Zustand steht je appInfo im Attribut `state` (bei neueren API-Ständen auch `appStoreState`; gelesen wird `state`,
  fehlt es oder ist es leer/kein String, `appStoreState`, sonst `unbekannt`). Angaben in `<…>` in dieser Spec sind
  Notation für Aufruf und Meldungen, kein offener Platzhalter.
- **Zustandsquellen:** appInfo-Wahl und die Käufe in `submission`: Kette `state` → `appStoreState` → `unbekannt`; `sec_iap`/`check_product` bleiben bei `state` allein (unverändert); Version (auch die Versionszeile in `submission`): allein `appVersionState`.
- **`sec_status`:** Gibt den echten `appVersionState` der gewählten Version aus. Für Version 1.0 bleibt es beim
  bisherigen Soll `PREPARE_FOR_SUBMISSION` (ok/Abweichung wie heute). Für jede andere Version steht eine Informationszeile
  `Zustand: <wert>` ohne ok/Abweichung-Urteil (zählt nicht als Abweichung); fehlt der Zustand oder ist er kein
  nichtleerer String, ist das eine Abweichung (Soll „Zustand vorhanden“, Ist „unbekannt“).
- **`sec_build`:** Zielnummer `--build <n>` (Standard bisher: ≥ 37, Feld „≥ 37“). Mit `--build n` wird die der Version
  zugeordnete Build-Nummer auf Gleichheit mit n geprüft, Soll „n“. Übrige Prüfungen (`processingState`, Verschlüsselung)
  unverändert.
- **Neuer Abschnitt `submission` (nur lesend, in `SECTIONS` und damit in `--all`):** Gibt aus
  1. den Zustand der gewählten Version als reine Information `Zustand: <wert>` (für jede Version, auch 1.0, ohne ok/Abweichung-Urteil; das Urteil für 1.0 bleibt allein in `sec_status`; ein fehlender, leerer oder nicht-String-`appVersionState` wird dort als `Zustand: unbekannt` ausgegeben, ebenfalls ohne Urteil; das Urteil dazu steht allein in `sec_status`),
  2. je Kauf aus `inAppPurchasesV2` und aus den Abos der Gruppe „Restock Pro“ (bestehende Leselisten-Pfade) Kurzname,
     Art und `state`, plus Zählung je Zustand über alle gefundenen Käufe (`tally`). Erwartet sind genau die drei Produkte
     der bestehenden Funktion `products()` (`PREFIX + "lifetime"` als IAP, `PREFIX + "monthly"`/`PREFIX + "yearly"` als Abo; `PREFIX` ist die Konstante in `asc_check.py`); fehlt
     eines, meldet `products()` das wie in `sec_iap` (die Zeilen tragen weiter das Label „iap“). Der Zustand eines Kaufs wird mit derselben Kette gelesen wie beim appInfo (`state`, sonst `appStoreState`, sonst `unbekannt`). Ein Kauf mit `unbekannt` ist eine
     Abweichung; jeder andere Zustandswert (auch `MISSING_METADATA`) ist nur Information, kein Urteil,
  3. die Zeilen `manuell belegen: Zuordnung der Käufe zur Version (per API nicht lesbar)` und
     `manuell belegen: Vereinbarung für bezahlte Apps (per API nicht lesbar)`, in der Art der bestehenden Zeile für
     App Privacy.
  Die Käufe-Lesung nutzt die vorhandene Funktion `products()`; ein neuer Pfad kommt nicht hinzu, `FENCE` für Pfade
  bleibt unverändert.
- **Nicht Teil dieser Änderung:** Käufe an die Version anhängen, Einreichen, jede Schreib-Methode. Beides ist
  außenwirksam und geschieht nur auf ausdrückliches Wort des PO.
- **Wiring:** `main` legt `ctx = {"version": <v>, "build": <n oder None>}` an; `context()` prüft `"app" not in ctx`
  statt `not ctx`, damit die Optionen den Zwischenspeicher nicht „füllen“. Argumente werden mit einer kleinen eigenen
  Auswertung gelesen (kein `argparse`-Verhalten ändern, das Fehlermeldungsformat bleibt).

## Acceptance Criteria
- **AC-1:** Zwei appInfos in den Zuständen `READY_FOR_SALE` und `REJECTED` (kein Entwurf) brechen `info_id()` (Abschnitte `metadata`, `appinfo`) mit einer Meldung ab, die beide IDs und beide Zustände nennt und „kein eindeutiger Entwurf“ enthält; kein Abschnitt meldet „ok“. Test: `test_two_infos_without_draft_aborts_with_all_states`.
- **AC-2:** Genau ein appInfo wird genommen, gleichgültig in welchem Zustand (auch `READY_FOR_SALE`). Test: `test_single_info_is_taken_in_any_state`.
- **AC-3:** Zwei appInfos, eines `PREPARE_FOR_SUBMISSION` und eines `READY_FOR_SALE`: der Entwurf wird gewählt. Test: `test_draft_info_wins_over_live`.
- **AC-4:** Zwei appInfos im Zustand `PREPARE_FOR_SUBMISSION` brechen ab (nicht eindeutig) und nennen beide Zustände; drei appInfos ohne Entwurf nennen alle drei. Test: `test_two_drafts_or_three_infos_abort`.
- **AC-5:** Ein appInfo, bei dem weder `state` noch `appStoreState` ein nichtleerer String ist (fehlend, leer, Zahl), erscheint in der Abbruchmeldung als `unbekannt`; ist `state` leer und `appStoreState` gesetzt, gilt dieses; ein Zustandswert mit Steuerzeichen wird davon befreit und auf höchstens 80 Zeichen abgeschnitten (ohne Markierung); ist der Wert danach leer, gilt er als `unbekannt`; null appInfos brechen mit `appInfo: 0 Treffer, kein eindeutiger Entwurf; Zustände: keine` ab. Test: `test_info_state_unknown_and_sanitized_in_message`. Zusätzlich (Test `test_zero_infos_and_empty_after_sanitizing`): null appInfos brechen mit `appInfo: 0 Treffer, kein eindeutiger Entwurf; Zustände: keine` ab, und ein nach der Bereinigung leerer Wert erscheint als `unbekannt`.
- **AC-20:** Bei zwei appInfos ohne Entwurf laufen `status`, `build`, `iap`, `submission`, `review`, `screenshots` und `privacy-url` ohne appInfo-Abbruch (Schein-`send` ruft `/appInfos` für sie nie ab); `metadata` und `appinfo` brechen wie AC-1 ab. Test: `test_info_is_resolved_only_by_sections_that_need_it`.
- **AC-6:** `--version 1.0.1` fragt `/v1/apps/{id}/appStoreVersions?filter[versionString]=1.0.1&filter[platform]=IOS` ab und wählt die Version mit `versionString` 1.0.1; die Folgeabschnitte lesen unter deren ID. Test: `test_version_argument_selects_that_version`.
- **AC-7:** Ohne `--version` und `--build` ist das Verhalten unverändert: Abfrage `versionString=1.0`, `sec_status` mit Soll `PREPARE_FOR_SUBMISSION`, `sec_build` mit „≥ 37“; alle bisherigen Tests bleiben grün. Test: `test_default_without_version_is_unchanged` plus bestehende Tests.
- **AC-8:** Ungültige `--version` (`abc`, `1`, `1.0.1.2`, `1.0;rm`, leer, `1.0.1 `, arabisch-indische Ziffern wie `١.٠`) und ungültige `--build` (`abc`, `-1`, `4.1`, leer) ergeben Exit 2 mit Aufrufhinweis auf stderr und keinen einzigen Netzaufruf (Schein-`send` zählt 0). Test: `test_invalid_version_or_build_exits_2_without_network`.
- **AC-9:** Der Lesezaun `check_read` lässt `GET /v1/apps/X/appStoreVersions?filter[versionString]=1.0.1&filter[platform]=IOS` zu (ID aus einer Antwort) und lehnt ab: `…versionString=1.0.1&x`, `…versionString=1.0.1&filter[platform]=IOS&x=1`, `…versionString=1.0;rm&filter[platform]=IOS`, `…versionString=&filter[platform]=IOS`, `…versionString=1.0.1&filter[platform]=MAC_OS`, die Abfrage ohne Query sowie jede Nicht-GET-Methode (POST, PATCH, PUT, DELETE) auf diesem Pfad. Test: `test_fence_version_pattern_and_rejections`.
- **AC-10:** `asc_lib.check_path` lässt für GET dasselbe Versionsmuster zu (`versionString=1.0.1&filter[platform]=IOS`) und lehnt dieselben Abweichungen mit Query wie AC-9 ab (das heutige Verhalten für GET ohne Query auf `appStoreVersions` bleibt unverändert und ist nicht Teil dieser Änderung); POST und PATCH bleiben auf die bestehenden Pfade beschränkt, an `appStoreVersions` ist weiter kein POST/PATCH möglich. Test: `test_check_path_version_pattern_get_only`.
- **AC-11:** `asc_publish` bleibt auf Version 1.0 festgelegt: sein Lauf fragt nur `filter[versionString]=1.0` ab, und der Schreibweg ist unverändert (bestehende Tests `test_asc_scripts.py` grün). Test: bestehende Tests plus `test_publish_still_queries_only_version_1_0`. Die lesende Öffnung für andere Versionen im Zaun von `asc_lib` ist durch AC-10 abgesichert (nur GET, Muster).
- **AC-12:** `sec_status` für Version 1.0.1 mit `appVersionState` `REJECTED` gibt `Zustand: REJECTED` aus, ohne „ok“ und ohne „Abweichung“, und erhöht den Abweichungszähler nicht; für Version 1.0 im Entwurf bleibt `ok status: appVersionState`, für 1.0 mit anderem Zustand die Abweichung wie bisher. Test: `test_status_other_version_prints_state_without_verdict`.
- **AC-13:** `sec_status` mit fehlendem, leerem oder nicht-String-Zustand (beliebige Version) meldet eine Abweichung und nie „ok“ oder eine Informationszeile mit „unbekannt“ ohne Abweichung. Test: `test_status_unknown_state_is_deviation`.
- **AC-14:** `--build 41` mit zugeordnetem Build `version` „41“ ergibt ok, mit „40“ eine Abweichung `Soll 41, Ist 40`; ohne `--build` gilt weiter „≥ 37“ (36 = Abweichung, 37 und 41 = ok). Ein Build mit nicht-numerischer Nummer ist in beiden Fällen eine Abweichung. Test: `test_build_target_via_option`.
- **AC-15:** Abschnitt `submission` gibt den Zustand der Version (auch bei 1.0 nur als Zeile `Zustand: <wert>`, bei fehlendem, leerem oder nicht-String-Wert `Zustand: unbekannt`, nie ok/Abweichung), je Kauf Kurzname, Art und `state` sowie beide Zeilen `manuell belegen` (Zuordnung Kauf↔Version, Vereinbarung für bezahlte Apps) aus; beide Zeilen erscheinen auch dann, wenn alle Käufe `READY_TO_SUBMIT` sind, und zählen nie als „ok“. Test: `test_submission_section_prints_manual_lines`.
- **AC-16:** `submission` meldet eine Abweichung bei einem Kauf, bei dem weder `state` noch `appStoreState` ein nichtleerer String ist (ein Kauf mit nur `appStoreState` gilt mit diesem Wert, keine Abweichung) und (über `products()`) bei einem der drei erwarteten Produkte, das fehlt; bei drei Käufen mit `state` `READY_TO_SUBMIT`, `READY_TO_SUBMIT`, `MISSING_METADATA` gibt es keine Abweichung, die Ausgabe nennt `MISSING_METADATA ×1, READY_TO_SUBMIT ×2`. Test: `test_submission_section_flags_unknown_or_missing_products`.
- **AC-17:** `submission` benutzt nur bestehende Leselisten-Pfade: ein Lauf mit Schein-`send` ruft ausschließlich GET auf, und die Pfadmenge von `FENCE` (ohne Abfrage-Muster) ist gegenüber vorher unverändert (kein Einreichungs-, kein `…Submissions`-Pfad). Test: `test_submission_uses_only_existing_read_paths`.
- **AC-18:** `--all` enthält `submission` als letzten Abschnitt; findet `context()` die Version nicht (0 Treffer für `--version 9.9`), steht je Abschnitt die Zeile `== <name>` gefolgt von der Fehlermeldung `Version 9.9 (IOS): 0 Treffer statt genau 1` (jeder Abschnitt scheitert einzeln, wie heute), der Exit-Code ist 1, und keine Ausgabezeile beginnt mit `ok ` (so beginnen die Erfolgszeilen heute). Test: `test_all_includes_submission_and_aborts_cleanly`.
- **AC-19:** Die Geheimnistests bleiben grün (`test_no_secrets_in_output_or_errors` in beiden Testdateien); die neuen Meldungen (appInfo-Zustände, Version) enthalten weder Token noch Schlüsselpfad. Test: bestehende Tests plus `test_new_messages_do_not_leak_secrets`.

## Definition of Done
- Der Prüflauf mit `--version 1.0.1` zeigt Zustand, Build und Käufe der Version an, ohne wegen zweier appInfos abzubrechen, und meldet Unbekanntes nie als ok.
- Alle Tests aus dem Test Plan sind grün; der bisherige Aufruf ohne Optionen verhält sich unverändert; es gibt keinen Schreib- oder Einreichungspfad.

## Test Plan
Schein-Antworten über die `send`-Naht, kein Netz, kein Schlüssel; Muster wie `self.version`/`self.info` in `scripts/test_asc_check.py`
(AC-1 bis AC-9 inkl. AC-20, AC-12 bis AC-19; AC-9 prüft `check_read` dort, AC-19 über `test_new_messages_do_not_leak_secrets` ebenfalls dort) und die Zauntests in `scripts/test_asc_scripts.py` (AC-10, AC-11). Beide laufen im CI-Schritt
„Strukturtests (Python)“. Bestehende Tests bleiben unverändert (`VERSION_QUERY` bleibt bestehen).

## Scope
4 Dateien: `scripts/asc_check.py`, `scripts/asc_lib.py`, `scripts/test_asc_check.py`, `scripts/test_asc_scripts.py`; ca. +220/−25 LoC (Tests überwiegen; Limit ±250, bei Überschreitung Rückfrage).
Keine Änderung an App-Code, Token, Schreibpfaden, `asc_publish`-Verhalten oder an den Pfadlisten.

## Alternative (verworfen)
Den Stand von 1.0.1 einmalig in der Weboberfläche lesen: schneller, aber nicht wiederholbar und kein belegbares Protokoll.
Ebenso verworfen: bei mehreren appInfos das „jüngste“ oder erste nehmen. Das wäre Raten, und bei unbekanntem Zustand
zeigte der Bericht ein falsches „ok“ (Regel aus B3b). Ein Modell entfällt: Zustände und Versionsnummern sind
deterministisch vergleichbar.

## Offene Grenzen
- Alles nur gegen Schein-Antworten geprüft; die echte Antwortstruktur (Attribut `state` vs. `appStoreState` am appInfo, `appVersionState` an der Version) ist erst im Live-Lauf belegt.
- Der Zustand der appInfos vor dem Live-Lauf ist unbekannt. Ist kein eindeutiger Entwurf vorhanden, bricht das Werkzeug mit der Zustandsliste ab, statt zu raten; erst diese Liste zeigt, ob eine weitere Regel nötig ist (dann Folgeänderung).
- Zuordnung der Käufe zur Version und Vereinbarung für bezahlte Apps sind per API nicht (sicher) lesbar und bleiben „manuell belegen“.
- Das Muster erlaubt jede Versionsnummer der Form x.y oder x.y.z; der Zaun lässt damit auch in `asc_publish` den lesenden Zugriff auf andere Versionen zu (nur GET, Schreiben bleibt an Version 1.0 gebunden).
- Anhängen der Käufe und Einreichen bleiben außenwirksam und sind nicht Teil dieser Änderung.

## Changelog
- 2026-11-12 (#269): AC-1 und Punkt „appInfo-Wahl in `info_id()`“ fortgeschrieben in `docs/specs/fast/fix-269-asc-check-appinfo-rejected.md` (Regel c: bei abgelehnter Version genau ein abgelehntes appInfo).
