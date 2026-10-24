# Context: feat-175-b1-store-texte

Stand: 2026-10-24, Branch `worktree-nifty-wandering-charm` = `origin/main` @ 3b86b0b (A1 und A2 sind über PR #213 in `main`,
Build 37 im Projekt, noch nicht hochgeladen).

## Request Summary
Issue #175, Durchgang B1: Die Store-Texte (Name, Untertitel, Beschreibung, Schlüsselwörter, Werbetext, Support-URL) für Deutsch
und Englisch sowie die zweisprachige Datenschutzseite als Dateien im Repo anlegen (`docs/appstore/de.md`, `en.md`,
`datenschutz.md`). Henning bekommt die Texte vor dem Festschreiben zur Freigabe (PO 2026-10-24). Wer die Datenschutzseite auf
`emmrich-business.com` stellt, wird danach geklärt (PO 2026-10-24).

## Related Files
| File | Relevance |
|------|-----------|
| `docs/specs/appstore/app-store-auftritt.md` | Spec mit Abschnitt „Durchgang B1“ (Z. 128–136), Textentwurf (Z. 197–295), AC-9 (Z. 372–375), AC-11 (Z. 380–383) |
| `SmartCart/Views/Settings/LegalView.swift` | Quelle für `datenschutz.md`: `privacyPolicy` (Stand Oktober 2026, nur Deutsch, sieben Abschnitte inkl. Fotos geteilter Artikel, Community-Preise, Open Prices); `termsOfUse` verweist auf Apples Standard-EULA |
| `SmartCart/Views/Premium/PaywallView.swift` | enthält **keinen** Link zu Datenschutz oder Nutzungsbedingungen (grep ohne Treffer) |
| `SmartCart/Views/Home/HomeView.swift` Z. 1407/1418 | Paywall nur für Rezeptplan und Ausgaben-Analyse (bestätigt Pro-Umfang im Text) |
| `SettingsView.swift` Z. 17 | Saisonale Vorschläge voreingestellt an, frei (nicht Pro) |
| `scripts/test_*.py` | Muster für Strukturtests (B2 schreibt `test_asc_texts.py`, liest die B1-Dateien) |
| `docs/context/feat-175-app-store-auftritt.md` | Kontext Gesamt-Ticket (ASC-Stand: alles leer, nur de-DE angelegt) |

## Existing Patterns
- Texte im Repo als Markdown mit festen Überschriften, damit Skripte sie lesen (Spec B1). Noch kein `docs/appstore/`-Ordner.
- Strukturtests als Python-Skripte ohne Netz (`scripts/test_ci_*.py`).
- Rechtstexte: einzige Quelle bisher `LegalView` (Deutsch); eine englische Fassung gibt es nirgends.

## Recherche (2026-10-24, vor der Analyse)
- **Feldgrenzen** (Apple, ASC-Hilfe „Platform version information“ und „App information“):
  Name 2–30 Zeichen, Untertitel ≤ 30, Werbetext ≤ 170, Beschreibung ≤ 4000 (nur Text, kein HTML),
  **Schlüsselwörter ≤ 100 Bytes** (nicht Zeichen; jedes Wort > 2 Zeichen; weder App- noch Firmenname noch Namen anderer Apps
  oder Firmen). Quelle: developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- **„Was ist neu“ gibt es für die erste Version nicht** („Required for all versions after the first, and not available for the
  first version“, gleiche Quelle). Spec-Entwurf und AC-11 verlangen es für 1.0 → Spec-Korrektur nötig.
- **Support-URL** muss zu echten Kontaktdaten führen (Anschrift, E-Mail oder Telefon, je nach Landesrecht). Heute:
  `emmrich-business.com/support.html` hat ein Kontaktformular und eine verschleierte E-Mail, keine Anschrift; das Impressum ist
  verlinkt.
- **Kategorien** (developer.apple.com/app-store/categories): Shopping = „Apps that support the purchase of consumer goods or
  materially enhance the shopping experience“; Productivity = „make a specific process or task more organized“. Falsche
  Kategorie verstößt gegen die Review-Richtlinien. Food & Drink nicht nachgelesen (mögliche Alternative).
- **Abos (Richtlinie 3.1.2, Schedule 2 der Entwicklervereinbarung, laut Ablehnungsberichten in Apple-Foren 809635, 813493,
  766296):** Die App selbst muss funktionierende Links zu Datenschutz und Nutzungsbedingungen (EULA) zeigen, dazu Titel, Laufzeit
  und Preis des Abos; die Metadaten brauchen die Datenschutz-URL und bei Apples Standard-EULA einen **Link zu den
  Nutzungsbedingungen in der Beschreibung**. Der Spec-Entwurf nennt „Apples Standard-Lizenzvereinbarung“ ohne Link → nachbessern.
  Belege sind Entwicklerberichte, Schedule 2 selbst nicht gelesen.
- **Richtlinie 5.1.1(i):** Datenschutz-Link in den Metadaten **und** leicht erreichbar in der App (vorhanden: Einstellungen →
  Rechtliches).
- **Richtlinie 2.3.7:** Untertitel ohne Bezug auf andere Apps, keine unbelegbaren Aussagen; keine Preisangaben in Metadaten zum
  Ranking.
- Gezählt (Python): DE-Schlüsselwörter 97 Zeichen / **99 Bytes** („Läden“, „Menüplan“), EN 100/100 (genau an der Grenze);
  Untertitel 27 bzw. 28; Werbetext 104 bzw. 109.

## Dependencies
- Upstream: Funktionsumfang der App (Code, CLAUDE.md), `LegalView`-Texte (A1).
- Downstream: B2 (`test_asc_texts.py`, `asc_publish.py` lesen die Dateien über feste Überschriften), B3 (Eintragen in ASC),
  Datenschutzseite online (offen, Domain-Zugang).

## Existing Specs
- `docs/specs/appstore/app-store-auftritt.md` (Status draft im Kopf, Workflow-State A1/A2 approved).

## Risks & Considerations
- **Ablehnungsrisiko Paywall (außerhalb B1):** Ohne Links zu Datenschutz und Nutzungsbedingungen in `PaywallView` droht
  Ablehnung nach 3.1.2. Das ist eine Produktänderung, gehört nicht in B1; als eigenes Issue vorschlagen (Release-1.0-Meilenstein).
- **Support-Seite ohne Anschrift:** möglicher Review-Einwand; hängt an derselben Domain wie die Datenschutzseite.
- **Webseite `restock.html` veraltet:** beschreibt Nachkauf, Rezeptfoto-Erkennung, „Geteilte Listen“-Add-on; kein Teil von B1,
  aber dieselbe Domain-Frage.
- EN-Schlüsselwörter genau 100 Bytes: jede Änderung muss erneut gezählt werden; Test misst Bytes, nicht Zeichen.
- Texte dürfen „Nachkauf“/„Erinnerung“ nicht nennen (AC-9; erst 1.1). Saisonale Vorschläge sind frei und existieren, fehlen im
  Entwurf (kann bleiben).
- Datenschutzseite englisch: Übersetzung eines Rechtstexts ohne juristische Prüfung (offene Grenze der Spec).
- Spec-Änderungen (kein „Was ist neu“, EULA-Link, Bytes) betreffen AC-9 und AC-11 → beim Korrigieren alle Stellen per grep.

## Analysis

### Type
Feature (reine Text- und Dokumentationsarbeit, kein App-Code, kein Build).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `docs/appstore/de.md` | CREATE | Abschnitte mit festen, sprachneutralen Überschriften: `## name`, `## subtitle`, `## keywords`, `## promotional_text`, `## description`, `## support_url`, `## privacy_url` (kein `whats_new`) |
| `docs/appstore/en.md` | CREATE | gleiche Überschriften, englischer Text |
| `docs/appstore/datenschutz.md` | CREATE | Datenschutzseite, `## Deutsch` (wortgleich mit `LegalView.privacyPolicy`, Stand Oktober 2026) und `## English` (Übersetzung) |
| `docs/specs/appstore/app-store-auftritt.md` | MODIFY | Spec-Korrektur B1: kein „Was ist neu“ für 1.0 (Abschnitt B1, Texte, AC-9, AC-11), Schlüsselwörter in Bytes, EULA-Link und echte Datenschutz-URL in der Beschreibung, Überschriftenformat |

### Scope Assessment
- Files: 3 neu + Spec-Korrektur
- Estimated LoC: +~220 (de ~50, en ~50, datenschutz ~120); Spec ±~30
- Risk Level: LOW — keine App-Änderung; Risiken liegen im Review-Ausgang, nicht im Code

### Befunde aus der Analyse (zusätzlich zur Recherche)
1. **Open Prices in 1.0 für alle sichtbar, aber gegen den Testserver:** `SettingsView.swift` Z. 138–143 zeigt den Eintrag ohne
   Entwicklermodus, `OpenPricesContribution.environment = .preProduction` (`OpenPricesContributionService.swift` Z. 314). Nicht
   B1; als Hinweis an #184 gegeben (Kommentar 2026-10-24). Folge für B1: Die Store-Beschreibung nennt Open Prices **nicht**, die
   Datenschutzseite beschreibt es (Code existiert, Manifest deklariert es).
2. **Paywall ohne Links zu Datenschutz/EULA** → neues Issue #215 (Meilenstein Release 1.0).
3. **Schlüsselwörter doppeln den Untertitel:** „Einkaufsliste“ (DE) und „shopping list“ (EN) stehen schon im Untertitel, den
   Apple ohnehin indiziert; die Bytes sind verschenkt. In der Spec ersetzen, Grenze 100 **Bytes** (Kandidaten mit 110/102 Bytes
   waren zu lang, Auswahl in der Spec mit Python zählen).
4. KI-Preisschätzung nur im Entwicklermodus (`SettingsView.swift` Z. 327) → nicht im Text, richtig so.
5. Beschreibung nennt sonst nur Vorhandenes (Quick-Add-Parser, Ladenzuordnung mit Korrektur, gelernter Weg, Bon-Scan inkl.
   Teilen-Erweiterung und Streifen, Barcode, Community-Preise opt-out, geteilte Läden, Siri, Widget, Live Activity, iCloud,
   Pro = Rezeptplan + Ausgaben-Analyse). Saisonale Vorschläge fehlen und dürfen fehlen.

### Technical Approach (Empfehlung)
- Texte aus dem Spec-Entwurf übernehmen, mit vier Korrekturen: (a) „Was ist neu“ entfällt für 1.0; (b) letzte Zeilen der
  Beschreibung nennen die Datenschutz-URL ausgeschrieben und Apples Standard-EULA als Link
  `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`; (c) Schlüsselwörter ohne Untertitel-Wörter, ≤ 100 Bytes;
  (d) Überschriften sprachneutral, damit B2 beide Dateien mit demselben Parser liest.
- Datenschutzseite **eine** zweisprachige Seite unter derselben URL `https://emmrich-business.com/datenschutz` (Deutsch zuerst,
  dann Englisch), daher in de.md und en.md dieselbe `privacy_url`. Support-URL `https://emmrich-business.com/support.html`.
- Deutsch wortgleich aus `LegalView` (eine Quelle; Abweichung wäre ein zweiter Rechtstext), Englisch als Übersetzung mit Hinweis,
  dass die deutsche Fassung maßgeblich ist.
- Texte gehen als Teil der Spec an Henning zur Freigabe (PO 2026-10-24), erst danach werden die Dateien geschrieben.
- Prüfung in B1 ohne B2-Skripte: Längen und Bytes per Python-Einzeiler, Ergebnis als Artefakt; der dauerhafte Test kommt in B2.

### Alternativen
1. **Zwei getrennte Datenschutzseiten** (`/datenschutz` und `/en/privacy`) statt einer zweisprachigen: sauberer je Sprache,
   aber doppelt so viel Pflege auf einer Domain, deren Zugang offen ist. Nicht empfohlen.
2. **Englische Datenschutzseite weglassen** (nur deutsch): Apple verlangt keine Übersetzung, aber en-US-Nutzer erhielten einen
   Text, den sie nicht lesen können. Kippt nichts Beschlossenes, kostet Vertrauen. Nicht empfohlen.
3. **Datenschutztext aus einer Repo-Datei in die App generieren** (eine Quelle für App und Web): würde `LegalView` umbauen,
   sprengt B1 und gehört zu #214. Nicht jetzt.
4. **Englische Store-Seite erst mit 1.1**: weniger Arbeit, kippt den Spec-Beschluss „de und en“. Nicht empfohlen, da en-US die
   Standardsprache vieler Länder ist.

### Dependencies
- Upstream: `LegalView.privacyPolicy` (A1, gemergt), Funktionsumfang laut Code.
- Downstream: B2 liest die Dateien über die festen Überschriften; B3 trägt sie in ASC ein; die Datenschutzseite muss auf
  `emmrich-business.com` (Klärung nach B1, PO 2026-10-24).
- Neue Issues/Hinweise: #215 (Paywall-Links), Kommentar an #184 (Open Prices 1.0).

### Open Questions
- [ ] Keine, die B1 blockiert. Text-Freigabe erfolgt an der Spec. Hosting der Datenschutzseite wird nach B1 geklärt.
