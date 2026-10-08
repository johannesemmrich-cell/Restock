import SwiftUI
import SwiftData
import Vision
import UIKit

// MARK: - Editable line model

// `ReceiptSuggestion` lebt in `ReceiptResolutionService.swift` — dort auch von der Share
// Extension genutzt, die dieselbe Namensauflösung braucht.

struct EditableReceiptLine: Identifiable {
    let id = UUID()
    var name: String
    var price: Double        // Zeilen-GESAMTpreis
    var isIncluded = true
    /// Roher Bon-Text vor Anwendung gelernter Kürzel-Zuordnungen — Schlüssel für
    /// `ReceiptAliasService.learn(...)`, wenn der User den Namen im Review korrigiert.
    var originalName: String = ""
    var quantity: Double = 1 // Stückzahl (Mengenzeile "2 x 1.25€" / Multipack "6X1.5L")
    var unit: String = ""    // Größe aus dem Namen, z. B. "1,5l", "400g"
    /// Siehe `ReceiptLine.weightBasis` (ReceiptParserService.swift) — reiner Durchreiche-Wert
    /// für `save()`, keine eigene UI-Darstellung.
    var weightBasis: Double? = nil
    /// Antippbare Alternativen aus den gerade abgehakten Artikeln dieses Stores — z. B. wenn die
    /// automatische Auflösung danebenliegt (kryptische Bon-Kürzel wie "MDHSZ" für "Mozzarella"
    /// lassen sich durch keine Text-Ähnlichkeit zuverlässig auflösen). Tippen setzt nur `name`;
    /// `originalName` bleibt unverändert, das Kürzel-Lernen in `save()` funktioniert dadurch
    /// identisch zu einer manuellen Texteingabe.
    var suggestions: [ReceiptSuggestion] = []
    /// Gesetzt, wenn diese Zeile einem konkreten, gerade abgehakten `ShoppingItem` zugeordnet
    /// wurde (automatisch oder per Vorschlags-Chip) — `save()` schreibt den gelernten Preis dann
    /// direkt auf DIESES Item zurück (statt nur `store.learnedPrices` für künftige Artikel zu
    /// lernen), und nutzt für die PurchaseRecord-Zuordnung dessen eigene Historie statt der
    /// unscharfen 7-Tage-Suche. Wird zurückgesetzt, sobald der Name danach frei überschrieben
    /// wird — sonst bliebe ein manuell korrigierter Name fälschlich mit der alten Identität
    /// verknüpft.
    var matchedItemID: UUID? = nil
    /// Siehe `ResolvedReceiptLine.resolvedByAI` — steuert die Art.-50-Kennzeichnung in
    /// `ReceiptReviewCard`. Wird zurückgesetzt, sobald der Name manuell überschrieben wird (gleicher
    /// Reset-Zeitpunkt wie `matchedItemID`), da die Kennzeichnung sonst fälschlich an einem vom
    /// Nutzer selbst eingetippten Text hängen bliebe.
    var resolvedByAI: Bool = false
    /// KI-Vorschlag und die zugehörige Artikel-Zuordnung, unabhängig von der aktuellen Auswahl —
    /// erlaubt, die KI-Options-Zeile der Prüf-Karte nach einer zwischenzeitlich anderen Auswahl
    /// wieder exakt herzustellen (`resolvedByAI = true`, `matchedItemID` wie ursprünglich).
    /// Gesetzt an allen drei Konstruktionsstellen, wann immer `resolvedByAI` dort true ist.
    /// NIE Teil von `ResolvedReceiptLine`/`ReceiptSuggestion` (Wire-Format zur Share Extension) —
    /// rein lokaler Anzeigezustand der Karte, ohne Prozessgrenze.
    var aiSuggestedName: String? = nil
    var aiSuggestedMatchedItemID: UUID? = nil
    /// Messgrundlage für `ReceiptResolutionStats` (Issue #14): Stufe und Name unmittelbar nach der
    /// Auflösung. Gesetzt an allen drei Konstruktionsstellen; ändert sich nicht, wenn der Nutzer
    /// im Review umbenennt — genau diese Abweichung zählt `save()` als „geändert“.
    var stage: ReceiptResolutionStage? = nil
    var resolvedName: String = ""

    /// Divisor fürs Preis-Lernen in `save()` — als Methode extrahiert (statt inline dort
    /// berechnet), damit Tests exakt diese Formel aufrufen statt sie nachzubilden. Ein Test, der
    /// die Formel nur kopiert, würde eine künftige Regression in `save()` selbst nicht bemerken
    /// (siehe RestockTests/ReceiptParserPriceTests.swift). Bevorzugt `weightBasis` (Gewichtszeile
    /// wie "0,500 kg x 2,29" — verlässlich, weil direkt aus dem Bon geparst, unabhängig von einem
    /// Artikel-Match), sonst mengenbewusst `quantity` selbst (Mengenzeile "2 x 1.25€" oder
    /// Multipack-Token "6X1.5L"), sonst den abgehakten Artikel (`matchQuantityAmount`), sonst eine
    /// im rohen Bon-Namen selbst gedruckte Füllmenge (`ReceiptParserService.weightBasisFromName` —
    /// deckt abgepackte Ware mit festem Gesamtpreis ab, z. B. "SKYR NATUR 500G", die NIE eine
    /// eigene Gewichts-/Mengenzeile hat; behebt den wiederholt gemeldeten Skyr-Bug, bei dem der
    /// volle Zeilenpreis mangels jeglichen Divisors als Pro-Gramm-Preis gelernt wurde). Nutzt
    /// bewusst `originalName` (roher OCR-Text), nicht `name` — eine bereits aufgelöste/KI-
    /// vervollständigte Bezeichnung könnte die gedruckte Füllmenge nicht mehr enthalten. Absoluter
    /// Fallback ist 1, dann ist der Preis bereits per-unit.
    func learningQuantity(matchQuantityAmount: Double?) -> Double {
        weightBasis ?? (quantity > 1 ? quantity : (matchQuantityAmount ?? ReceiptParserService.weightBasisFromName(originalName) ?? 1))
    }

    /// Bezugsgröße des Preises, den `learningQuantity` gerade herleitet (`"g"` oder `"stk"`, siehe
    /// `Store.learnedPriceUnits`) — Schwestermethode DIREKT neben der Divisor-Formel, nicht eine
    /// Kopie der Verzweigung an der Aufrufstelle: beide müssen dieselben Bedingungen in derselben
    /// Reihenfolge treffen, sonst lernt `save()` einen Preis unter einer falschen Bezugsgröße
    /// (Issue #10). Ein Test prüft beide Methoden an derselben Instanz gegeneinander.
    ///
    /// | Divisor-Quelle in `learningQuantity` | Ergebnis hier |
    /// |---|---|
    /// | `weightBasis` (Gewichtszeile „0,706 kg x 2,49") | `"g"` |
    /// | `quantity > 1` (Mengenzeile „4 Stk x 0,39") | `"stk"` |
    /// | `matchQuantityAmount` (abgehakter Artikel) | Eimer von dessen Einheit |
    /// | `weightBasisFromName(originalName)` („… 400G") | `"g"` |
    /// | Fallback `1` | `"stk"` |
    ///
    /// `matchUnit` MUSS aus demselben `PurchaseRecord` stammen wie das `matchQuantityAmount`, das
    /// `learningQuantity` bekommt (beide `match?.…`) — nur dann ist „Treffer vorhanden" in beiden
    /// Methoden dieselbe Bedingung.
    func learningUnit(matchUnit: String?) -> String {
        if weightBasis != nil { return "g" }
        if quantity > 1 { return "stk" }
        if let matchUnit { return ShoppingItem.unitBucket(matchUnit) }
        if ReceiptParserService.weightBasisFromName(originalName) != nil { return "g" }
        return "stk"
    }

    /// Menge und Einheit für den `PurchaseRecord`, den `save()` für eine Zeile ohne Artikel-Treffer
    /// anlegt (Issue #54, `docs/specs/views/receipt-save-purchase-quantity.md`). Erste zutreffende
    /// Regel gewinnt: Gewicht der Zeile in g; sonst Stückzahl > 1 ohne Einheit; sonst gedruckte
    /// Packungsgröße aus dem Namen (g/ml); sonst 1 ohne Einheit. Der Rohtext `unit` ("400g") wird
    /// bewusst nicht übernommen. Regeln 1 und 2 decken sich mit `learningQuantity`.
    func purchaseRecordQuantity() -> (amount: Double, unit: String) {
        if let weightBasis { return (weightBasis, "g") }
        if quantity > 1 { return (quantity, "") }
        if let size = ReceiptParserService.packageSizeFromName(originalName) { return size }
        return (1, "")
    }

    /// Der `PurchaseRecord`, den `save()` für eine Zeile ohne Artikel-Treffer einfügt (Issue #54).
    /// Menge und Einheit kommen aus `purchaseRecordQuantity()`; einfügen bleibt in `save()`.
    func makePurchaseRecord(storeName: String) -> PurchaseRecord {
        let recordQuantity = purchaseRecordQuantity()
        return PurchaseRecord(
            itemName: name,
            storeName: storeName,
            quantityAmount: recordQuantity.amount,
            unit: recordQuantity.unit,
            actualPrice: price
        )
    }

    /// Darf diese Position gespeichert werden? (Issue #50, Paket 1, Regel 11 —
    /// `docs/specs/views/receipt-review-card.md`.)
    ///
    /// Trägt die bisher in `save()` inline stehende Bedingung (`isIncluded && price > 0`) und
    /// ergänzt sie um den leeren Namen: `save()` würde sonst einen `PurchaseRecord` OHNE Namen in
    /// die Ausgabenhistorie schreiben und einen Preis unter dem leeren Schlüssel lernen. Bewusst
    /// hier neben `learningQuantity`/`learningUnit`, weil die Bedingung eine Aussage über die
    /// ZEILE ist, nicht über die View.
    static func isSavable(_ line: EditableReceiptLine) -> Bool {
        line.isIncluded
            && line.price > 0
            && !line.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Indizes von Zeilen, die Stufe 5 (Apple Intelligence) noch NICHT durchlaufen haben — erkannt
    /// daran, dass ihr Name unverändert dem OCR-Rohtext entspricht UND `resolvedByAI` false ist
    /// (ein per Alias/Fuzzy-Match bereits aufgelöster Name wäre von `originalName` verschieden,
    /// selbst ohne KI). Reine, testbare Auswahl-Logik — von `reResolveAIIfNeeded()` (Share-
    /// Handoff-Pfad) verwendet, ohne dass ein Test FoundationModels/SystemLanguageModel-
    /// Verfügbarkeit braucht.
    static func linesNeedingAIReresolution(_ lines: [EditableReceiptLine]) -> [Int] {
        lines.indices.filter { i in
            !lines[i].resolvedByAI && lines[i].name == lines[i].originalName
        }
    }

    /// Schreibt das Ergebnis einer erneuten Auflösung (siehe `linesNeedingAIReresolution`) an
    /// exakt den ausgewählten Indizes zurück, alle anderen Zeilen bleiben unangetastet.
    /// `resolved` muss `indices.count` Einträge haben, in derselben Reihenfolge wie `indices`
    /// (so wie `ReceiptResolutionService.resolve` sie liefert, wenn man ihm dieselbe Teilmenge
    /// als `parsed` übergibt).
    static func mergeAIReresolution(into lines: [EditableReceiptLine], resolved: [ResolvedReceiptLine], at indices: [Int]) -> [EditableReceiptLine] {
        var result = lines
        for (offset, index) in indices.enumerated() where offset < resolved.count {
            let r = resolved[offset]
            result[index].name = r.name
            result[index].suggestions = r.suggestions
            result[index].matchedItemID = r.matchedItemID
            result[index].resolvedByAI = r.resolvedByAI
            result[index].stage = r.stage
            result[index].resolvedName = r.name
            // Siehe `aiSuggestedName`: nur merken, wenn diese Auflösung wirklich von der KI kam.
            if r.resolvedByAI {
                result[index].aiSuggestedName = r.name
                result[index].aiSuggestedMatchedItemID = r.matchedItemID
            }
        }
        return result
    }
}

// MARK: - Lern-Entscheidungen beim Speichern

/// Fachentscheidungen beim Speichern eines geprüften Bons (Issue #59) — aus
/// `ReceiptScannerView.save()` herausgezogen, damit sie ohne View direkt prüfbar sind. `save()`
/// ruft diese Funktionen auf und schreibt nur noch. Kein neues Verhalten gegenüber dem vorherigen
/// Inline-Code.
enum ReceiptLearning {
    /// Was für eine Bon-Zeile gelernt wird: Schlüssel in `Store.learnedPrices`, Preis je
    /// Bezugsgröße und die Bezugsgröße selbst (`"g"`/`"stk"`, siehe `Store.learnedPriceUnits`).
    struct Plan: Equatable {
        let key: String
        let perUnitPrice: Double
        let unit: String
    }

    /// `learnedPrices` muss je Einheit bleiben (es speist `ShoppingItem.estimatedPrice`), eine
    /// Bon-Zeile trägt aber die Zeilen-SUMME — Herleitung in
    /// `EditableReceiptLine.learningQuantity(matchQuantityAmount:)`. Menge und Einheit des
    /// Treffers kommen bewusst aus DEMSELBEN Datensatz (`match`), siehe `learningUnit(matchUnit:)`.
    static func plan(line: EditableReceiptLine, match: PurchaseRecord?) -> Plan {
        let quantity = line.learningQuantity(matchQuantityAmount: match?.quantityAmount)
        return Plan(
            key: line.name.lowercased(),
            perUnitPrice: quantity > 0 ? line.price / quantity : line.price,
            unit: line.learningUnit(matchUnit: match?.unit)
        )
    }

    /// Der gemeinte, bereits gelistete Artikel.
    ///
    /// Ist die Zeile einem konkreten Artikel zugeordnet (automatisch oder per Vorschlag,
    /// `matchedItemID`), gilt dieser — die Identität steht dann schon fest. `matchedItemID` ist
    /// aber oft bewusst nil: eine manuelle Namens-Korrektur im Review löscht sie (siehe
    /// `ReceiptReviewCard`). Der korrigierte Name ist dann die verlässlichste Evidenz, deshalb
    /// zusätzlich exakt (nicht nur „contains") gegen alle Artikel des Ladens suchen. Behebt
    /// „Maultaschen ohne Preis".
    ///
    /// Nur bereits abgehakte Artikel — ein Bon belegt einen tatsächlichen Kauf, ein noch offener
    /// Artikel mit gleichem Namen (schon wieder vorgemerkt) wurde nicht gekauft. Ohne diesen Filter
    /// träfe `max(by:)` bevorzugt den neueren, ungekauften Artikel und der Bon-Preis landete am
    /// falschen Artikel.
    static func matchedItem(for line: EditableReceiptLine, in items: [ShoppingItem]) -> ShoppingItem? {
        if let id = line.matchedItemID, let item = items.first(where: { $0.id == id }) {
            return item
        }
        let lineLower = line.name.lowercased()
        return items
            .filter { $0.isCompleted && $0.name.lowercased() == lineLower }
            .max(by: { ($0.completedDate ?? $0.addedDate) < ($1.completedDate ?? $1.addedDate) })
    }

    /// Der Kaufdatensatz, der den Bon-Preis bekommt — oder nil, dann legt `save()` einen neuen an.
    ///
    /// Bevorzugt den jüngsten unbepreisten Datensatz des gemeinten Artikels (`ownRecords`, Identität
    /// verifiziert). Sonst die lockere 7-Tage-Suche im selben Laden über alle Datensätze. Die hat
    /// über reines `contains` keinerlei Namensprüfung („Milch" träfe „Kondensmilch") und schreibt
    /// Preis UND Datum auf einen womöglich fremden Datensatz — deshalb dieselbe Ähnlichkeitsschwelle
    /// wie bei der automatischen Vorschlags-Übernahme; darunter gilt sie als kein Treffer.
    static func purchaseMatch(
        for line: EditableReceiptLine,
        ownRecords: [PurchaseRecord],
        allRecords: [PurchaseRecord],
        storeName: String,
        cutoff: Date
    ) -> PurchaseRecord? {
        if let ownUnpriced = ownRecords
            .filter({ $0.actualPrice == nil })
            .max(by: { $0.date < $1.date }) {
            return ownUnpriced
        }
        let lineLower = line.name.lowercased()
        let storeNameLower = storeName.lowercased()
        let looseMatch = allRecords.first { record in
            record.storeName.lowercased() == storeNameLower &&
            record.date >= cutoff &&
            (record.itemName.lowercased().contains(lineLower) ||
             lineLower.contains(record.itemName.lowercased()))
        }
        guard let looseMatch else { return nil }
        let score = ReceiptParserService.lcsSimilarity(line.name, looseMatch.itemName)
        return score >= ReceiptParserService.completedItemAutoApplyThreshold ? looseMatch : nil
    }

    /// Schreibt den gelernten Preis auf den gelisteten Artikel — nach derselben
    /// Entscheidungstabelle wie `ShoppingItem.init` (Issue #10): eine pro Gramm gelernte Rate darf
    /// nicht als Stückpreis an einen Artikel ohne Mengenangabe geschrieben werden (die gemeldeten
    /// „0,01 €").
    static func apply(_ plan: Plan, to item: ShoppingItem) {
        switch ShoppingItem.learnedRateUsage(
            learnedUnit: plan.unit,
            itemUnit: item.unit,
            quantitySource: item.quantitySource
        ) {
        case .apply:
            item.estimatedPrice = plan.perUnitPrice
            item.estimatedPriceIsAutoDerived = false
        case .rateOnly:
            item.estimatedPrice = plan.perUnitPrice
            item.unit = "g"
            item.estimatedPriceIsAutoDerived = false
        case .reject:
            break // Der bisherige (geschätzte) Preis bleibt stehen — kein falscher Betrag.
        }
    }
}

// MARK: - Main Scanner View

struct ReceiptScannerView: View {
    // `@State` statt `@Bindable`: kein Code in dieser Datei bindet über `$store.…` an einzelne
    // Felder, `@State` erlaubt dafür — anders als `@Bindable` — das komplette AUSTAUSCHEN der
    // Referenz aus einer Button-Action heraus (Store-Korrektur unten), Lesezugriffe auf
    // `store.name` etc. bleiben über SwiftData/Observation trotzdem live nachverfolgt.
    @State private var store: Store
    /// `true`, solange der über die Share Extension übergebene Laden nur geraten war (siehe
    /// `SharedReceiptPayload.storeConfidentlyDetected`) und der Nutzer das noch nicht bestätigt
    /// oder korrigiert hat — steuert die Korrektur-Aufforderung unten in `reviewView`. Bleibt bei
    /// einem normalen Kamera-/Foto-Scan (`init(store:)`) immer `false`, dort wählt der Nutzer den
    /// Laden ohnehin schon vorher selbst (`StoreDetailView`).
    @State private var storeNeedsConfirmation = false
    @State private var showStoreCorrection = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Store> { $0.isActive }, sort: \Store.sortIndex) private var activeStores: [Store]
    @Query(sort: \PurchaseRecord.date, order: .reverse) private var allRecords: [PurchaseRecord]

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var parsedLines: [EditableReceiptLine] = []
    @State private var phase: Phase = .capture
    /// Die von Vision rekonstruierten Rohzeilen VOR dem Parsing — nur für die Dev-Feedback-
    /// Diagnose (siehe `.devFeedback` unten) gehalten, damit ein "das ist komisch"-Feedback aus
    /// dem Review automatisch den tatsächlichen OCR-Rohtext mitschickt, statt dass ein einzelner
    /// falsch erkannter oder komplett fehlender Artikel ohne das Originalfoto nicht mehr
    /// nachvollziehbar ist.
    @State private var debugRawLines: [String] = []
    /// Der auf dem Bon selbst aufgedruckte Gesamtbetrag ("zu zahlen"), unabhängig von den
    /// erkannten Positionen — Vergleichswert für `totalMismatchWarning` unten. `nil`, wenn der
    /// Bon keine "zahlen"-Zeile enthielt (z. B. französisches Format) oder kein Betrag daraus
    /// extrahierbar war — dann bleibt die Warnung schlicht aus, statt etwas zu behaupten.
    @State private var detectedTotal: Double?
    /// Nur bei `init(store:prefilled:)` true — steuert `reResolveAIIfNeeded()`: die Share
    /// Extension übergibt Zeilen mit `allowAIResolution: false` (Speicherlimit dort, siehe
    /// `ReceiptResolutionService`-Doku), Stufe 5 muss also spätestens hier, mit vollem
    /// App-Speicherbudget, noch nachgeholt werden — sonst bleiben geteilte Bons dauerhaft auf den
    /// rohen OCR-Namen aus Stufe 1-4 hängen ("Namen nicht so gut wie vorher").
    @State private var cameFromShareHandoff = false

    enum Phase { case capture, processing, review }

    init(store: Store) {
        _store = State(initialValue: store)
    }

    /// Einstiegspunkt für einen per Share Extension bereits erkannten Bon (siehe
    /// `ReceiptShareHandoff`) — startet direkt in `.review`, ohne Foto-Aufnahme/OCR-Schritt,
    /// mit denselben Feldern befüllt, die ein normaler Scan an diesem Punkt hätte. Gleiches
    /// Init-Muster wie `StoreDetailView.init` (State(initialValue:) für vorbefüllte @State).
    /// `storeConfidentlyDetected`: siehe `SharedReceiptPayload` — steuert, ob `store` hier unten
    /// gleich als bestätigungspflichtiger Rate-Treffer markiert wird.
    init(store: Store, prefilled: SharedReceiptPayload, storeConfidentlyDetected: Bool) {
        _store = State(initialValue: store)
        _storeNeedsConfirmation = State(initialValue: !storeConfidentlyDetected)
        _phase = State(initialValue: .review)
        _cameFromShareHandoff = State(initialValue: true)
        _parsedLines = State(initialValue: prefilled.lines.map { line in
            EditableReceiptLine(
                name: line.name,
                price: line.price,
                originalName: line.originalName,
                quantity: line.quantity,
                unit: line.unit,
                weightBasis: line.weightBasis,
                suggestions: line.suggestions,
                matchedItemID: line.matchedItemID,
                resolvedByAI: line.resolvedByAI,
                aiSuggestedName: line.resolvedByAI ? line.name : nil,
                aiSuggestedMatchedItemID: line.resolvedByAI ? line.matchedItemID : nil,
                stage: line.stage,
                resolvedName: line.name
            )
        })
        _debugRawLines = State(initialValue: prefilled.rawLines)
        _detectedTotal = State(initialValue: prefilled.detectedTotal)
    }

    private var selectedTotal: Double {
        parsedLines.filter(\.isIncluded).reduce(0.0) { $0 + $1.price }
    }

    /// Summe ALLER erkannten Positionen, unabhängig vom An/Aus-Toggle — bewusst nicht
    /// `selectedTotal`, weil ein Nutzer einzelne Positionen absichtlich abwählen kann (z. B. weil
    /// er sie nicht in die Preis-Historie übernehmen will); das wäre keine Erkennungslücke.
    private var parsedTotal: Double {
        parsedLines.reduce(0.0) { $0 + $1.price }
    }

    /// Nicht-nil, wenn die erkannten Positionen nicht zur aufgedruckten Bon-Summe passen (mehr als
    /// 1 Cent Differenz, um harmlose Rundung nicht fälschlich zu melden) — macht eine
    /// Erkennungslücke wie eine komplett von Vision übersehene Position (Name UND Zuordnung fehlen,
    /// nicht reparierbar) wenigstens sichtbar, statt sie in der Summe kommentarlos verschwinden zu
    /// lassen.
    private var totalMismatchWarning: String? {
        guard let detectedTotal, abs(parsedTotal - detectedTotal) > 0.01 else { return nil }
        let diff = detectedTotal - parsedTotal
        let diffText = abs(diff).formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR"))
        return diff > 0
            ? "Erkannte Positionen ergeben \(diffText) weniger als die Bon-Summe — vermutlich wurde eine Position nicht erkannt."
            : "Erkannte Positionen ergeben \(diffText) mehr als die Bon-Summe."
    }

    /// Siehe `ChipToolbarItem`-Dokumentation (DesignSystem.swift): der Button muss immer
    /// deklariert bleiben, hier nur per `disabled`/`opacity` gesteuert werden — kein `if` um das
    /// ganze `ChipToolbarItem`.
    ///
    /// `!storeNeedsConfirmation`: OHNE diese Bedingung ließ sich „Speichern" antippen, während das
    /// orange Banner unten noch unbeachtet stand — ein per Share Extension nur GERATENER Laden
    /// (`storeConfidentlyDetected: false`) hätte dann still und ungefragt alle Positionen bekommen,
    /// obwohl der Nutzer den Hinweis nie bestätigt oder korrigiert hat. Genau der Fall, den das
    /// Banner eigentlich verhindern soll (Nutzerrückmeldung 20.09.2026: "keine falsch-Zuordnung...
    /// sondern dies für die App offen gelassen" — das Banner allein war nur ein Hinweis, keine
    /// erzwungene Entscheidung).
    private var canSave: Bool {
        phase == .review && !storeNeedsConfirmation && !parsedLines.filter(\.isIncluded).isEmpty
    }

    /// Kandidaten für den Korrektur-Dialog — der aktuell angenommene Laden fehlt bewusst (Tippen
    /// darauf wäre ein No-Op), gleiches Muster wie `otherStoresForCorrection` in HomeView.
    private var otherStoresForCorrection: [Store] {
        activeStores.filter { $0.id != store.id }
    }

    private func correctStore(to newStore: Store) {
        store = newStore
        storeNeedsConfirmation = false
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .capture:    captureView
                case .processing: processingView
                case .review:     reviewView
                }
            }
            .navigationTitle("Bon scannen — \(store.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ChipToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Abbrechen").toolbarChip() }
                        .buttonStyle(.pressable)
                }
                ChipToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Speichern").toolbarChip(prominent: true) }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("receiptReview.saveButton")
                        .disabled(!canSave)
                        .opacity(phase == .review ? 1 : 0)
                        // Explizit statt sich auf automatisches Opacity-Ausblenden zu verlassen —
                        // sonst könnte VoiceOver in .capture/.processing auf einen unsichtbaren
                        // "Speichern"-Button landen (siehe ChipToolbarItem-Dokumentation).
                        .accessibilityHidden(phase != .review)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerRepresentable(sourceType: .camera) { image in
                guard let image else { return }
                process(image)
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePickerRepresentable(sourceType: .photoLibrary) { image in
                guard let image else { return }
                process(image)
            }
        }
        // Gleiches Muster wie die Store-Korrektur in HomeView (`correctQuickAddStore`): eine
        // `confirmationDialog` mit einem Button je aktivem Laden, statt eine eigene Picker-UI zu
        // erfinden.
        .confirmationDialog(
            "Welcher Laden ist das?",
            isPresented: $showStoreCorrection,
            titleVisibility: .visible
        ) {
            ForEach(otherStoresForCorrection) { candidate in
                Button("\(candidate.emoji) \(candidate.name)") { correctStore(to: candidate) }
            }
        }
        .devFeedback(context: debugRawLines.isEmpty
            ? "Bon scannen — \(store.name)"
            : "Bon scannen — \(store.name)\n\nRohzeilen:\n\(debugRawLines.joined(separator: "\n"))")
        .task { await reResolveAIIfNeeded() }
    }

    /// Holt Stufe 5 (Apple Intelligence) für Zeilen nach, die aus einem Share-Extension-Handoff
    /// stammen und dort mit `allowAIResolution: false` übersprungen wurden (Speicherlimit einer
    /// Extension) — jetzt mit vollem App-Speicherbudget. No-op für einen normalen Kamera-/Foto-
    /// Scan (`process()` hat dort bereits Stufe 5 mit `allowAIResolution: true` durchlaufen).
    /// Nutzt `originalName` statt des ggf. schon (Stufe 1-4) gesetzten `name`, weil Stufe 1-4 in
    /// der Extension bereits gelaufen ist — ein erneuter Durchlauf davon hier ist zwar günstig/
    /// idempotent, aber unnötig; nur Stufe 5 leistet neue Arbeit.
    private func reResolveAIIfNeeded() async {
        guard cameFromShareHandoff else { return }
        let indices = EditableReceiptLine.linesNeedingAIReresolution(parsedLines)
        guard !indices.isEmpty else { return }
        let toResolve = indices.map { i -> ReceiptLine in
            let line = parsedLines[i]
            return ReceiptLine(name: line.originalName, price: line.price, quantity: line.quantity, unit: line.unit, weightBasis: line.weightBasis)
        }
        let resolved = await ReceiptResolutionService.resolve(parsed: toResolve, store: store, allRecords: allRecords)
        parsedLines = EditableReceiptLine.mergeAIReresolution(into: parsedLines, resolved: resolved, at: indices)
    }

    // MARK: - Phase views

    private var captureView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("Kassenbon scannen")
                    .font(.headline)
                Text("Fotografiere deinen Kassenbon oder wähle ein Bild aus der Fotobibliothek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        Haptics.impact(.light)
                        showCamera = true
                    } label: {
                        Label("Foto aufnehmen", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.restockPrimary)
                }

                Button {
                    Haptics.impact(.light)
                    showPhotoLibrary = true
                } label: {
                    Label("Aus Fotos wählen", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Bon wird ausgelesen…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewView: some View {
        List {
            if parsedLines.isEmpty {
                ContentUnavailableView(
                    "Keine Positionen erkannt",
                    systemImage: "doc.text",
                    description: Text("Versuche ein klareres, gut beleuchtetes Foto.")
                )
                .listRowBackground(Color.clear)

                Section {
                    Button {
                        showPhotoLibrary = true
                        phase = .capture
                    } label: {
                        Label("Neues Foto wählen", systemImage: "arrow.uturn.left")
                    }
                }
            } else {
                // Ganz oben, noch vor den Positionen: eine falsche Laden-Zuordnung betrifft ALLE
                // Positionen zugleich (Preise landen im falschen Laden), muss also vor allem
                // anderen aufgelöst werden. Nur sichtbar, solange der Laden aus der Share
                // Extension noch ein unbestätigter Rate-Treffer ist (`storeNeedsConfirmation`).
                //
                // ZWEI explizite Aktionen statt nur "antippen zum Ändern": eine geratene Zuordnung
                // kann ja auch zufällig stimmen, dann soll der Nutzer das aktiv bestätigen können,
                // statt gezwungen zu sein, denselben Laden nochmal aus dem Korrektur-Dialog
                // auszuwählen. Beide Wege setzen `storeNeedsConfirmation = false` und schalten
                // damit „Speichern" (`canSave`) erst frei — reines Ignorieren des Banners speichert
                // NICHT mehr stillschweigend beim geratenen Laden.
                if storeNeedsConfirmation {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Laden nicht sicher erkannt")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Angenommen: \(store.emoji) \(store.name) — bitte bestätigen oder ändern, bevor du speicherst.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    storeNeedsConfirmation = false
                                } label: {
                                    Label("\(store.name) ist richtig", systemImage: "checkmark")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)

                                Button {
                                    showStoreCorrection = true
                                } label: {
                                    Text("Anderer Laden")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                }

                Section {
                    // Index zusätzlich zur Binding-Identität, damit jede Zeile ihre eigenen
                    // `accessibilityIdentifier`-Suffixe bekommt (receiptReview.line.<index>.…).
                    // Bewusst über `enumerated()` statt `indices` — die ForEach-Identität bleibt
                    // die `Identifiable`-id der Zeile, nicht der reine Array-Index.
                    // ALLE Karten in EINER Listenzeile, nicht eine Zeile je Position: `List`
                    // erzeugt Zeilen erst, wenn sie in Sichtweite kommen. Die Karten sind
                    // deutlich höher als die frühere einzeilige Darstellung, sodass schon die
                    // vierte Position eines Bons nicht mehr existiert, bevor der Nutzer
                    // gescrollt hat — weder für VoiceOver noch für einen Bildschirmtest.
                    // Eine Zelle wird dagegen immer vollständig aufgebaut. Preis dafür: bei
                    // sehr langen Bons entsteht die ganze Liste auf einmal (siehe „Risiken" der
                    // Spec, Abschnitt Kartenhöhe).
                    VStack(spacing: 12) {
                        ForEach(Array($parsedLines.enumerated()), id: \.element.id) { index, $line in
                            ReceiptReviewCard(line: $line, index: index)
                        }
                    }
                    // Jede Karte schwebt als eigene Fläche im Seitenfluss (Ebene 0,
                    // DesignSystem §4) — ohne Listenhintergrund und ohne die Standard-
                    // Trennlinie, die sonst quer durch die Karten liefe.
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                } header: {
                    // Ersetzt „Gefunden: N Positionen" UND die frühere separate
                    // „Ausgewählt"-Section: Anzahl, Auswahl und Summe an einer Stelle.
                    Text(ReceiptReviewCard.sectionHeaderText(
                        count: parsedLines.count,
                        selected: parsedLines.filter(\.isIncluded).count,
                        sum: selectedTotal))
                        .textCase(nil)
                        .accessibilityIdentifier("receiptReview.sectionHeader")
                } footer: {
                    Text("Tippe eine Zeile an, um den Artikel zu wählen, oder ändere in der letzten Zeile den vorausgefüllten Bontext.")
                }

                if let totalMismatchWarning {
                    Section {
                        Label(totalMismatchWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                }

                Section {
                    Button {
                        phase = .capture
                    } label: {
                        Label("Neues Foto", systemImage: "arrow.uturn.left")
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func process(_ image: UIImage) {
        phase = .processing
        // Sofort zurücksetzen, nicht erst nach der OCR — sonst könnte ein Feedback-Tap während
        // dieses Scans (oder ein Scan, der schon am fehlenden cgImage scheitert, siehe Guard
        // unten) noch die Rohzeilen des VORHERIGEN Fotos anzeigen.
        debugRawLines = []
        detectedTotal = nil
        Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else {
                await MainActor.run { parsedLines = []; phase = .review }
                return
            }
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            // Issue #120: sehr hohe Bilder werden in Streifen erkannt, normale im Einzelzug; wirft
            // Vision, kommen leere Blöcke zurück, sodass der Spinner endet.
            let lines = ReceiptParserService.reconstructLines(
                ReceiptTextRecognizer.recognizeBlocks(in: cgImage, orientation: orientation))
            await MainActor.run {
                debugRawLines = lines
                detectedTotal = ReceiptParserService.detectedTotal(from: lines)
            }
            let parsed = ReceiptParserService.parse(lines)
            // Wiederverwendet von der Share Extension (geteiltes Bild aus einer anderen App) —
            // siehe ReceiptResolutionService.swift für die mehrstufige Auflösungs-Logik selbst.
            let resolved = await ReceiptResolutionService.resolve(parsed: parsed, store: store, allRecords: allRecords)
            await MainActor.run {
                parsedLines = resolved.map { line in
                    EditableReceiptLine(
                        name: line.name,
                        price: line.price,
                        originalName: line.originalName,
                        quantity: line.quantity,
                        unit: line.unit,
                        weightBasis: line.weightBasis,
                        suggestions: line.suggestions,
                        matchedItemID: line.matchedItemID,
                        resolvedByAI: line.resolvedByAI,
                        aiSuggestedName: line.resolvedByAI ? line.name : nil,
                        aiSuggestedMatchedItemID: line.resolvedByAI ? line.matchedItemID : nil,
                        stage: line.stage,
                        resolvedName: line.name
                    )
                }
                phase = .review
            }
        }
    }

    private func save() {
        // Issue #14: Messung je Stufe — ALLE Zeilen, auch abgewählte (Spalte „Abgewählt“).
        ReceiptResolutionStats().record(parsedLines)
        let included = parsedLines.filter { EditableReceiptLine.isSavable($0) }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)

        for line in included {
            // Kürzel-Lernen: weicht der finale Name vom rohen Bon-Text ab (User hat die Position
            // umbenannt oder eine früher gelernte Zuordnung bestätigt), Mapping für künftige
            // Scans merken — beim nächsten Bon erscheint das Kürzel direkt als richtiger Artikel.
            if !line.originalName.isEmpty {
                ReceiptAliasService.shared.learn(receiptText: line.originalName, itemName: line.name)
            }

            // Gemeinten Artikel und Kaufdatensatz auflösen (Issue #59: als reine Funktionen in
            // `ReceiptLearning`, Begründungen dort).
            let matchedItem = ReceiptLearning.matchedItem(for: line, in: store.items ?? [])
            let match = ReceiptLearning.purchaseMatch(
                for: line,
                ownRecords: matchedItem?.purchaseRecords ?? [],
                allRecords: allRecords,
                storeName: store.name,
                cutoff: cutoff
            )

            // Learn price for this store — overwrites previous learned price for this item.
            // Preis, Bezugsgröße und Datum in EINEM Zug (Issue #10), siehe `ReceiptLearning.plan`.
            let plan = ReceiptLearning.plan(line: line, match: match)
            store.learnedPrices[plan.key] = plan.perUnitPrice
            store.learnedPriceUnits[plan.key] = plan.unit
            store.learnedPriceDates[plan.key] = Date()

            // Direkt auf den bereits gelisteten Artikel zurückschreiben — sonst lernt ein Scan nur
            // für KÜNFTIG neu erstellte Artikel (über `learnedPrices`), während der schon
            // abgehakte Artikel auf der aktuellen Liste weiterhin gar keinen oder einen veralteten
            // geschätzten Preis zeigt, obwohl der Bon ihn gerade korrekt erkannt hat. Bevorzugt
            // `matchedItem` (aus der Kandidaten-Suche mit dem aufgelösten Namen), fällt aber auf
            // `match.item` zurück — `match` ist an dieser Stelle bereits namensgeprüft (entweder
            // über `matchedItemID` oder die LCS-Schwelle in `purchaseMatch`), das PurchaseRecord
            // kennt über die Kaufhistorie oft denselben, noch existierenden Artikel, auch wenn
            // `matchedItemID` z. B. wegen einer OCR-Verwucherung des Namens nicht griff. Ohne diesen
            // Fallback bekommt der PurchaseRecord (und damit die Ausgaben-Ansicht) einen Preis,
            // während der Artikel auf der Liste selbst weiterhin keinen zeigt — genau das gemeldete
            // Mandeln-Symptom.
            if let itemToUpdate = matchedItem ?? match?.item {
                ReceiptLearning.apply(plan, to: itemToUpdate)
            }

            if let match {
                match.actualPrice = line.price
                // Ein Bon-Scan ist die verlässlichste verfügbare Evidenz für das tatsächliche
                // Kaufdatum — verlässlicher als der Zeitpunkt, an dem der Artikel in der App
                // abgehakt wurde (kann beim Planen Tage vorher liegen). Ohne dieses Update behält
                // ein aktualisierter Datensatz sein altes Abhak-Datum, während andere Positionen
                // desselben Bons als neu eingefügte Datensätze das heutige Datum bekommen — ein
                // einzelner Bon würde dann in der tageweisen Ausgaben-Gruppierung (PriceOverviewView
                // .TripKey) auf mehrere "Einkäufe" auseinanderfallen.
                match.date = Date()
            } else {
                modelContext.insert(line.makePurchaseRecord(storeName: store.name))
            }
        }
        Haptics.success()
        // Ohne diesen Push sieht kein anderes Mitglied einer geteilten Liste die neuen Preise/
        // Positionen, bis irgendeine SPÄTERE Aktion zufällig einen Push auslöst — jede andere
        // Mutations-Stelle im Code (HomeView, AddItemView, EditItemView, StoreDetailView, ...)
        // pusht bereits zuverlässig, save() hier war die einzige Ausnahme (gemeldet 19.08.2026:
        // Bon-Import löste nie eine Push-Notification für andere Mitglieder aus).
        SyncCoordinator.shared.pushInBackground(store)
        dismiss()
    }
}

// MARK: - UIImagePickerController wrapper

private struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerRepresentable
        init(_ parent: ImagePickerRepresentable) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            parent.completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.completion(nil)
        }
    }
}
