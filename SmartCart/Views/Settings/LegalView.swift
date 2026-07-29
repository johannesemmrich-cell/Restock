import SwiftUI

enum LegalDocument: String, CaseIterable {
    case privacy = "Datenschutzerklärung"
    case terms   = "Nutzungsbedingungen"
    case imprint = "Impressum"

    var systemImage: String {
        switch self {
        case .privacy: return "lock.shield"
        case .terms:   return "doc.text"
        case .imprint: return "building.2"
        }
    }
}

struct LegalView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Color.canvas)
        .navigationTitle(document.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    private var content: AttributedString {
        (try? AttributedString(markdown: markdownContent, options: .init(interpretedSyntax: .full)))
            ?? AttributedString(markdownContent)
    }

    private var markdownContent: String {
        switch document {
        case .privacy: return privacyPolicy
        case .terms:   return termsOfUse
        case .imprint: return imprint
        }
    }

    // MARK: - Datenschutzerklärung

    private let privacyPolicy = """
**Datenschutzerklärung**
Stand: Juni 2026

---

**1. Verantwortlicher**

Johannes Emmrich
Eichenaue 14, 48157 Münster
E-Mail: j.emmrich@icloud.com

---

**2. Welche Daten werden verarbeitet?**

**Lokale Datenspeicherung**
Restock speichert alle Einkaufsdaten (Listen, Artikel, Geschäfte, Kaufhistorie, Preise) ausschließlich lokal auf deinem Gerät mittels SwiftData. Diese Daten verlassen dein Gerät nur im Rahmen der unten beschriebenen Dienste.

**iCloud-Synchronisierung**
Wenn iCloud auf deinem Gerät aktiviert ist, werden die App-Daten über Apples CloudKit-Dienst zwischen deinen eigenen Apple-Geräten synchronisiert. Dabei gelten die Datenschutzrichtlinien von Apple (apple.com/legal/privacy). Restock hat keinen Zugriff auf diese iCloud-Daten.

**Barcode-Scanner**
Beim Scannen eines Produktbarcodes wird ausschließlich die EAN-Nummer an den Open-Food-Facts-Dienst (openfoodfacts.org) übermittelt, um den Produktnamen abzufragen. Es werden keine personenbezogenen Daten übertragen. Open Food Facts ist ein gemeinnütziges Projekt mit eigener Datenschutzrichtlinie unter world.openfoodfacts.org/privacy.

**Geteilte Listen (Premium)**
Wenn du eine Einkaufsliste mit anderen teilst, werden die Listendaten (Artikelnamen, Status, Zuweisung) verschlüsselt in Apples CloudKit Public Database gespeichert. Der Zugriff erfolgt ausschließlich über einen 6-stelligen Einladungscode. Es werden keine Kontodaten oder andere personenbezogene Informationen der Teilnehmer gespeichert.

**In-App-Käufe**
Käufe werden ausschließlich über Apples StoreKit-Dienst abgewickelt. Restock erhält dabei keine Zahlungsinformationen oder Kontodaten.

**Keine Analyse, kein Tracking**
Restock verwendet keine Analyse-Tools, keine Werbenetzwerke und kein Tracking. Es werden keine Nutzungsdaten an Dritte weitergegeben.

---

**3. Weitergabe an Dritte**

Deine Daten werden nicht verkauft oder vermarktet. Eine Weitergabe erfolgt ausschließlich im Rahmen der oben genannten Dienste (Apple CloudKit, Open Food Facts) und nur in dem Umfang, der für die jeweilige Funktion notwendig ist.

---

**4. Speicherdauer**

Daten auf deinem Gerät bleiben bis zur Deinstallation der App erhalten. iCloud-Daten werden nach Apples Richtlinien verwaltet und können in den iCloud-Einstellungen gelöscht werden.

---

**5. Deine Rechte (DSGVO)**

Du hast das Recht auf:
- **Auskunft** über deine gespeicherten Daten
- **Berichtigung** unrichtiger Daten
- **Löschung** deiner Daten (Art. 17 DSGVO)
- **Einschränkung** der Verarbeitung
- **Datenportabilität**
- **Widerspruch** gegen die Verarbeitung

Für Anfragen wende dich an: j.emmrich@icloud.com

---

**6. Datenlöschung**

Alle lokalen Daten kannst du durch Deinstallation der App löschen. Für iCloud-Daten nutze Einstellungen → [dein Name] → iCloud auf deinem Gerät. Geteilte Listen-Daten bleiben in Apples CloudKit gespeichert, bis du uns unter der unten genannten Adresse um Löschung bittest.

---

**7. Kontakt bei Datenschutzfragen**

j.emmrich@icloud.com
"""

    // MARK: - Nutzungsbedingungen

    private let termsOfUse = """
**Nutzungsbedingungen**
Stand: Juni 2026

---

**1. Geltungsbereich**

Diese Nutzungsbedingungen gelten für die iOS-App Restock (nachfolgend „App"), bereitgestellt von Johannes Emmrich.

---

**2. Leistungsumfang**

Restock bietet digitale Einkaufslisten mit folgenden Funktionen:
- Artikel hinzufügen, organisieren und abhaken
- Automatische Ladenzuweisung basierend auf Kaufhistorie
- Kassenbon-Scan und Preiserfassung (Premium)
- Menüplanung (Premium)
- Geteilte Listen zur Zusammenarbeit (Premium / Add-on)
- Ausgaben-Analyse (Premium)

Der genaue Funktionsumfang kann sich zwischen kostenlosen und kostenpflichtigen Versionen unterscheiden.

---

**3. In-App-Käufe und Abonnements**

Bestimmte Funktionen erfordern ein Restock-Pro-Abonnement oder einen Einmalkauf. Verfügbare Optionen:

- **Monatliches Abo** — automatische Verlängerung monatlich
- **Jährliches Abo** — automatische Verlängerung jährlich
- **Einmalkauf (Lifetime)** — einmalige Zahlung, dauerhafter Zugang
- **Geteilte Listen Add-on** — Einmalkauf für das Teilen-Feature

**Automatische Verlängerung:** Abonnements verlängern sich automatisch, sofern nicht mindestens 24 Stunden vor Ende des aktuellen Zeitraums in den Apple-ID-Einstellungen gekündigt wird.

**Kündigung:** Abonnements können jederzeit in Einstellungen → Apple ID → Abonnements verwaltet und gekündigt werden.

**Rückerstattung:** Rückerstattungen erfolgen nach den Richtlinien von Apple. Restock kann keine direkten Rückerstattungen gewähren.

---

**4. Nutzungsrechte**

Restock räumt dir ein persönliches, nicht-übertragbares, nicht-exklusives Recht zur Nutzung der App auf deinen Apple-Geräten gemäß Apples Standard-EULA ein.

---

**5. Nutzerpflichten**

Du verpflichtest dich, die App nicht für rechtswidrige Zwecke zu verwenden und keine automatisierten Zugriffe auf verbundene Dienste durchzuführen.

---

**6. Haftungsausschluss**

Die App wird „wie sie ist" (as-is) bereitgestellt. Für folgende Punkte übernehmen wir keine Haftung:
- Richtigkeit von automatisch erfassten Preisen oder Produktinformationen
- Verfügbarkeit externer Dienste (Open Food Facts, iCloud)
- Datenverlust durch Geräteschäden oder App-Deinstallation

---

**7. Änderungen der Bedingungen**

Wir behalten uns vor, diese Bedingungen anzupassen. Bei wesentlichen Änderungen wirst du in der App informiert. Die weitere Nutzung nach einer Änderung gilt als Zustimmung.

---

**8. Anwendbares Recht**

Es gilt deutsches Recht unter Ausschluss des UN-Kaufrechts.

---

**9. Kontakt**

Bei Fragen zu diesen Nutzungsbedingungen:
j.emmrich@icloud.com
"""

    // MARK: - Impressum

    private let imprint = """
**Impressum**
Angaben gemäß § 5 TMG

---

**Anbieter**

Johannes Emmrich
Eichenaue 14
48157 Münster
Deutschland

E-Mail: j.emmrich@icloud.com

---

**Hinweis**

Da Restock eine private, nicht-kommerzielle App ist, besteht nach aktueller Rechtslage u.U. keine vollständige Impressumspflicht gemäß TMG. Es werden dennoch freiwillig Kontaktdaten bereitgestellt.

---

**Inhaltlich verantwortlich gemäß § 55 Abs. 2 RStV**

Johannes Emmrich
(Adresse s.o.)

---

**Haftung für Inhalte**

Die Inhalte dieser App wurden mit größtmöglicher Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte kann jedoch keine Gewähr übernommen werden.

---

**Externe Links**

Die App enthält Links zu externen Webseiten (z.B. Open Food Facts). Für die Inhalte dieser externen Seiten sind ausschließlich deren Betreiber verantwortlich.

---

**Urheberrecht**

Die durch den App-Entwickler erstellten Inhalte und Werke unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der Zustimmung des Autors.

---

**Streitschlichtung**

Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.
"""
}

// MARK: - Overview

struct LegalOverviewView: View {
    var body: some View {
        List {
            ForEach(LegalDocument.allCases, id: \.rawValue) { doc in
                NavigationLink {
                    LegalView(document: doc)
                } label: {
                    Label(doc.rawValue, systemImage: doc.systemImage)
                }
            }
        }
        .navigationTitle("Rechtliches")
        .navigationBarTitleDisplayMode(.inline)
    }
}
