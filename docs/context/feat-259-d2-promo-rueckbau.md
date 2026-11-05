# Context: feat-259-d2-promo-rueckbau

## Request Summary
Issue #259, Durchgang 2: Den selbstgebauten Promo-Code-Pool (CloudKit-Public-DB) vollständig aus der App entfernen, nachdem Durchgang 1 (PR #260, gemergt) den Offer-Code-Einstieg geliefert hat. Die Spec ist bereits freigegeben: `docs/specs/views/offer-codes-einloesen.md`, Abschnitt „Durchgang 2“, AC-10 bis AC-17.

## Related Files (gemessen am Stand origin/main 7ff7d19)
| File | Relevanz |
|------|----------|
| `SmartCart/Services/PromoCodeService.swift` (311 Z.) | löschen |
| `SmartCart/Views/Settings/PromoCodeAdminView.swift` (183 Z.) | löschen; wird nirgends mehr referenziert (Waise) |
| `RestockTests/PromoCodeServiceTests.swift` (227 Z., 13 Tests) | löschen |
| `SmartCart/Services/PremiumService.swift` Z. 136–143, 156 | `hasValidPromoCode`, `setHasValidPromoCode`, Term in `hasPremiumAccess` raus |
| `SmartCart/SmartCartApp.swift` Z. 979–981 | `PromoCodeService.shared.revalidateLocalRedemption()` samt Kommentar raus |
| `SmartCart/Views/Settings/LegalView.swift` Z. 184–185 | Absatz Promo-Codes raus |
| `docs/appstore/datenschutz.md` Z. 38–39 (de), 125–126 (en) | Absätze raus, wortgleich zu LegalView |
| `SmartCart/Resources/{de,en}.lproj/Localizable.strings` Z. 117–123 | 7 Schlüssel je Sprache raus; Ist: 478 Schlüssel je Sprache, Soll 471 |
| `Restock.xcodeproj/project.pbxproj` | 12 Treffer „PromoCode“ (3 Dateien × 4 Bereiche) |
| `docs/cloudkit/private-schema-aktuell.ckdb` Z. 152 | bleibt (Typ bleibt in Dev/Prod, Spec) |

Gegenprobe per grep: Außerhalb der drei Löschdateien kommt „promo“ in `scripts/` nur als „promotional_text“ (App-Store-Feld, unbetroffen) vor; `PrivacyManifestTests` und `test_asc_texts.py` nennen Promo-Codes nicht. `RestockUITests` und `project.yml` ohne Treffer. Die Schlüssel `settings.promoCode.*` / `promoCode.error.*` werden nur in den gelöschten Dateien benutzt.

## Existing Patterns
- Neue/gelöschte Swift-Dateien müssen in vier pbxproj-Bereichen (`PBXBuildFile`, `PBXFileReference`, `PBXGroup`, `PBXSourcesBuildPhase`) gepflegt werden (CLAUDE.md).
- `LegalView.privacyPolicy` und `docs/appstore/datenschutz.md` müssen wortgleich bleiben (`scripts/test_asc_texts.py`).
- `LocalizationKeyParityTests` prüft gleiche Schlüssel und Platzhalter in de/en.

## Dependencies
- Upstream: `PromoCodeService` nutzt CloudKit Public DB und `PremiumService.setHasValidPromoCode`.
- Downstream: nur `SmartCartApp` (Start-`.task`) und `PremiumService.hasPremiumAccess`. Die Offer-Code-Kette aus Durchgang 1 (`Transaction.updates` → `PremiumService`) ist unabhängig.

## Existing Specs
- `docs/specs/views/offer-codes-einloesen.md` (Durchgang 2 dort bereits vollständig spezifiziert, mit Scope-Tabelle und PO-Freigabe für die Überschreitung der Dateigrenze durch reine Löschung)

## Risks & Considerations
- Eingelöste Promo-Codes verlieren die Freischaltung (laut Spec akzeptiert, auf keinem Fremdgerät erprobt).
- pbxproj von Hand: eine verwaiste Referenz bricht den Build (AC-11: Debug- und Release-Build).
- Datenschutztext: LegalView und Seite zugleich ändern, sonst rotes `test_asc_texts.py`; Stand „Oktober 2026“ nicht anfassen.
- Schlüsselzahl vorher/nachher messen (478 → 471).
- Testzahl der Unit-Suite: Vorher-Zahl minus 13.
- Zwei bekannte zeitabhängige `ConsumptionPatternTests` können rot sein (nicht aus diesem Ticket).
- Zeilenlimit: −770 Löschzeilen, vom PO in der Spec-Freigabe für diesen Durchgang freigegeben.
- Alternative (gekippt in Spec): Pool für Tester behalten.

## Analysis

### Type
Feature (Rückbau, Durchgang 2 von #259)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| SmartCart/Services/PromoCodeService.swift | DELETE | −311 |
| SmartCart/Views/Settings/PromoCodeAdminView.swift | DELETE | −183, Waise |
| RestockTests/PromoCodeServiceTests.swift | DELETE | −227, 13 Tests |
| SmartCart/Services/PremiumService.swift | MODIFY | hasValidPromoCode/setHasValidPromoCode + Term in hasPremiumAccess raus |
| SmartCart/SmartCartApp.swift | MODIFY | revalidateLocalRedemption()-Aufruf (Z. 981) samt Kommentar raus |
| SmartCart/Views/Settings/LegalView.swift | MODIFY | Promo-Absatz raus |
| docs/appstore/datenschutz.md | MODIFY | Absatz de + en raus, wortgleich zu LegalView |
| SmartCart/Resources/{de,en}.lproj/Localizable.strings | MODIFY | 7 Schlüssel je Sprache (478 → 471) |
| Restock.xcodeproj/project.pbxproj | MODIFY | 12 Referenzen raus |

### Scope Assessment
- Files: 11 (3 gelöscht), ~−770 LoC fast nur Löschung (PO-Freigabe in der Spec)
- Risk Level: LOW–MEDIUM (pbxproj von Hand; eingelöste Promo-Codes verlieren Zugang, laut Spec akzeptiert)

### Technical Approach
Regelweg ist hier das Löschen: Pool ersatzlos entfernen, Offer-Code-Kette aus Durchgang 1 trägt die Freischaltung. Abgleich 2026-11-05 gegen Code: grep findet Promo-Treffer nur in den erwarteten Dateien, 478 Schlüssel je Sprache, pbxproj 12 Treffer. Verifikation über AC-10 bis AC-17 (grep, Debug- und Release-Build, Unit-Suite mit Testzahl, test_asc_texts.py, UI-Klassen, Benutzen im frischen Simulator).
Alternative (in Spec gekippt): Pool für Tester behalten; würde die Entscheidung vom 2026-11-01 beibehalten, kostet Datenschutz-Absatz, Schreibrecht und zwei Freischaltwege.

### Dependencies
Nur SmartCartApp (Start-.task) und PremiumService.hasPremiumAccess hängen am Pool. CloudKit-Typ PromoCode und PrivacyInfo.xcprivacy bleiben unberührt.

### Open Questions
- [ ] keine; Spec Durchgang 2 ist freigegeben
