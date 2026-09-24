import SwiftUI

// MARK: - Auswahl-Optionen einer Bon-Position

/// Eine antippbare Namenszeile der Bon-Prüf-Karte (Issue #23, Spec
/// `docs/specs/views/receipt-review-card.md`).
///
/// Variante B („Auswahl statt Tippen"): Der Name einer Position wird nicht mehr frei getippt,
/// sondern aus einer Einfachauswahl gewählt. Jede Quelle bleibt dabei unterscheidbar, weil
/// `save()` je nach Quelle anders lernt: ein Listen-Treffer trägt eine Artikel-Identität
/// (`matchedItemID`), ein KI-Vorschlag die Art.-50-Kennzeichnung (`resolvedByAI`), ein eigener
/// Name keines von beidem.
enum ReceiptNameOption: Identifiable {
    /// Treffer aus den gerade abgehakten Artikeln dieses Ladens — Quelle „auf deiner Liste".
    case listMatch(ReceiptSuggestion)
    /// Von Apple Intelligence vervollständigter Name — trägt die Marke „KI-Vorschlag".
    case aiSuggestion(name: String)
    /// Rückfall, wenn es weder Treffer noch KI-Vorschlag gibt: der heutige Name der Zeile.
    case currentName(name: String)
    /// „Anderer Name …" — immer die letzte Zeile.
    case custom

    var id: String {
        switch self {
        case .listMatch(let suggestion): return "listMatch-\(suggestion.id)"
        case .aiSuggestion(let name):    return "ai-\(name)"
        case .currentName(let name):     return "current-\(name)"
        case .custom:                    return "custom"
        }
    }

    /// Der angezeigte Artikelname dieser Option („Anderer Name …" trägt keinen).
    var displayName: String {
        switch self {
        case .listMatch(let suggestion): return suggestion.name
        case .aiSuggestion(let name):    return name
        case .currentName(let name):     return name
        case .custom:                    return "Anderer Name …"
        }
    }

    /// Name, über den dedupliziert und vorausgewählt wird — `.custom` hat bewusst keinen.
    fileprivate var matchableName: String? {
        switch self {
        case .listMatch(let suggestion): return suggestion.name
        case .aiSuggestion(let name):    return name
        case .currentName(let name):     return name
        case .custom:                    return nil
        }
    }
}

/// Die zwei Stellungen des Mengen-Editors. Mehr gibt es bewusst nicht: `save()` kennt über
/// `EditableReceiptLine.learningQuantity` nur die Lernbasis „Stück" oder „Gramm-Äquivalent";
/// weitere Einheiten würden Umrechnungslogik in die View holen, die es sonst nirgends gibt.
enum ReceiptQuantityMode: Hashable {
    case pieces
    case grams
}

// MARK: - Karte

/// Eine Bon-Position als Karte: oben der gedruckte Bontext plus Namensauswahl, unten die
/// Preiszeile mit Stück-/Kilopreis und „Ändern".
///
/// Ersetzt die frühere `ReceiptLineRow`, in der Name, Stift, KI-Pille und Preisfeld um dieselbe
/// Zeilenbreite konkurrierten (Issue #23: Namen abgeschnitten, Pille vierzeilig umgebrochen,
/// Bontext gar nicht sichtbar).
///
/// Die Semantik von `name`/`originalName`/`matchedItemID`/`resolvedByAI` ist unverändert — die
/// drei Auswahl-Wege bilden exakt die früheren Zuweisungen (Chip-Tap bzw. TextField-Binding) ab,
/// `save()` selbst wurde nicht angefasst.
struct ReceiptReviewCard: View {
    @Binding var line: EditableReceiptLine
    /// Position dieser Zeile im Bon — nur für die `accessibilityIdentifier`s der UI-Tests
    /// (`receiptReview.line.<index>.…`), keine Darstellungswirkung.
    let index: Int

    /// Die Auswahlzeilen werden EINMAL berechnet und behalten danach ihre Reihenfolge.
    ///
    /// `selectionOptions` sortiert die aktuell gewählte Option nach vorn (Regel 3) — würde die
    /// Karte bei jeder Auswahl neu berechnen, spränge die eben angetippte Zeile unter dem Finger
    /// an die erste Stelle. Die Vorauswahl ist eine Aussage über den ANFANGSZUSTAND, nicht über
    /// jeden Folgezustand.
    @State private var options: [ReceiptNameOption] = []
    @State private var customActive = false
    @State private var customName = ""
    @State private var isEditing = false
    @State private var priceText = ""
    @State private var quantityText = ""
    @State private var quantityMode: ReceiptQuantityMode = .pieces
    @FocusState private var customFocused: Bool

    /// 28 pt Kantenlänge braucht mehr Rundung als der 22-pt-Kreis in `ItemRow` (dort 6 pt) —
    /// bewusst lokal, kein neuer globaler Token für einen einzelnen Sonderfall.
    private let checkboxCorner: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            nameSection
            Rectangle()
                .fill(Color.hairline)
                .frame(height: 1)
            priceSection
        }
        .background(Color.surface, in: RoundedRectangle(cornerRadius: RCRadius.card))
        .overlay(RoundedRectangle(cornerRadius: RCRadius.card).strokeBorder(Color.hairline))
        .onAppear {
            if options.isEmpty { options = Self.selectionOptions(for: line) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("receiptReview.line.\(index).card")
    }

    // MARK: Abschnitt 1 — Bontext und Namensauswahl

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Der gedruckte Bontext ist das eigentliche Prüfkriterium dieses Screens und wird
                // deshalb NIE gekürzt — kein `lineLimit`, stattdessen Umbruch in eine zweite Zeile.
                Text(line.originalName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(line.isIncluded ? 1 : 0.4)
                    .accessibilityIdentifier("receiptReview.line.\(index).originalName")

                checkbox
            }

            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { position, option in
                    optionRow(option, at: position)
                }
            }
            .opacity(line.isIncluded ? 1 : 0.4)
        }
        .padding(14)
    }

    /// Gleiches visuelles Muster wie `ItemRow` (Häkchen-Kreis statt `Toggle`), nur 28 statt 22 pt.
    private var checkbox: some View {
        Button {
            line.isIncluded.toggle()
            Haptics.impact(.light)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: checkboxCorner)
                    .fill(line.isIncluded ? Color.accent : Color.clear)
                    .frame(width: 28, height: 28)
                RoundedRectangle(cornerRadius: checkboxCorner)
                    .strokeBorder(line.isIncluded ? Color.accent : Color.hairlineStrong, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                if line.isIncluded {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.canvas)
                }
            }
            // Ohne diese Zeile ist das Häkchen eine Einbahnstraße: `.buttonStyle(.plain)` nimmt
            // nur GEZEICHNETES als Trefferfläche, und im abgewählten Zustand ist die Füllung
            // `Color.clear` — übrig bliebe allein der 1,5 pt dünne Rahmen, ein Tipp in die Mitte
            // fiele ins Leere (nachgemessen: Abwählen ja, Wiederanwählen nein). Dasselbe Mittel
            // benutzen die Auswahlzeilen dieser Karte schon.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Der gewählte Name gehört ins Bedienhilfen-Label: Ein Bon hat vier bis zwanzig
        // gleich aussehende Häkchen, und ein blosses „Position übernehmen" sagt weder, WELCHE
        // Position gemeint ist, noch unter welchem Namen sie gespeichert wird — genau die
        // Angabe, die der Screen prüfen lassen soll. `line.name` ist dabei der Wert, den
        // `save()` schreibt, nicht der Bontext.
        .accessibilityLabel("Position übernehmen: \(line.name)")
        .accessibilityIdentifier("receiptReview.line.\(index).checkbox")
    }

    @ViewBuilder
    private func optionRow(_ option: ReceiptNameOption, at position: Int) -> some View {
        let identifier = "receiptReview.line.\(index).option.\(position)"
        if case .custom = option, customActive {
            customNameRow()
        } else {
            HStack(spacing: 8) {
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 10) {
                        radio(filled: isSelected(option))
                        Text(option.displayName)
                            .font(.system(size: 15))
                            .foregroundStyle(isCustom(option) ? Color.textSecondary : Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if case .listMatch = option {
                            Text("auf deiner Liste")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.textSecondary)
                                .fixedSize()
                        }
                    }
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
                .accessibilityAddTraits(isSelected(option) ? [.isSelected] : [])

                // Art.-50-Kennzeichnung (EU AI Act): sichtbar genau dort, wo der KI-Name zur
                // Auswahl steht. `layoutPriority(1)` + `fixedSize()` sind der eigentliche Fix aus
                // #23 — ohne sie bekam die Pille den Rest der Zeilenbreite zugeteilt und brach
                // Zeichen für Zeichen senkrecht um (gemessen: 147 pt hoch statt 18).
                if case .aiSuggestion = option {
                    aiMark.layoutPriority(1)
                }
            }
        }
    }

    private var aiMark: some View {
        Label("KI-Vorschlag", systemImage: "sparkles")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accent)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentContainer, in: Capsule())
            // `children: .ignore` statt `.combine`: die Pille wird damit EIN Blatt-Element mit
            // genau dem Rahmen der Pille selbst — ein zusammengesetztes Element würde die
            // Rahmenmessung des UI-Tests (einzeilig?) an der Vereinigung der Kindrahmen messen.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("KI-Vorschlag")
            .accessibilityIdentifier("receiptReview.line.\(index).aiMark")
    }

    private func radio(filled: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(filled ? Color.accent : Color.hairlineStrong, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if filled {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func customNameRow() -> some View {
        HStack(spacing: 10) {
            TextField("Anderer Name …", text: $customName)
                .font(.system(size: 15))
                .focused($customFocused)
                .submitLabel(.done)
                .accessibilityIdentifier("receiptReview.line.\(index).customNameField")
                .onChange(of: customName) { _, newValue in
                    Self.applyCustomName(&line, name: newValue)
                }
            Spacer(minLength: 0)
        }
        .padding(.leading, 32)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    // MARK: Abschnitt 2 — Preiszeile und Editor

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Self.priceSummary(for: line))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.ink)
                    .accessibilityIdentifier("receiptReview.line.\(index).price")
                Spacer(minLength: 8)
                Button {
                    if !isEditing { syncEditorFields() }
                    isEditing.toggle()
                    Haptics.impact(.light)
                } label: {
                    Text("Ändern")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("receiptReview.line.\(index).changeButton")
            }

            if isEditing { editorRow }
        }
        .opacity(line.isIncluded ? 1 : 0.4)
        .padding(14)
    }

    private var editorRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Preis")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                // Linksbündig, obwohl Beträge sonst rechts stehen: ein Tipp in die Mitte eines
                // rechtsbündigen Feldes landet LINKS vom Text und setzt die Schreibmarke an den
                // Anfang — eine Korrektur schöbe die neue Zahl dann vor die alte („0,99" + „2"
                // = „20,99"). Linksbündig liegt die Mitte hinter dem Text, die Marke also am Ende.
                TextField("0,00", text: $priceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 15, weight: .medium))
                    .accessibilityIdentifier("receiptReview.line.\(index).priceField")
                    .onChange(of: priceText) { _, newValue in
                        if let value = Self.parseNumber(newValue) { line.price = value }
                    }
                Text(Locale.current.currencySymbol ?? "€")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 10) {
                Text("Menge")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
                TextField("1", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 70)
                    .accessibilityIdentifier("receiptReview.line.\(index).quantityField")
                    .onChange(of: quantityText) { _, _ in applyQuantityFromEditor() }
                Picker("Menge", selection: $quantityMode) {
                    Text("Stück").tag(ReceiptQuantityMode.pieces)
                    Text("Gramm").tag(ReceiptQuantityMode.grams)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
                .accessibilityIdentifier("receiptReview.line.\(index).quantityMode")
                .onChange(of: quantityMode) { _, _ in applyQuantityFromEditor() }
            }
        }
    }

    // MARK: Zustand

    private func isCustom(_ option: ReceiptNameOption) -> Bool {
        if case .custom = option { return true }
        return false
    }

    private func isSelected(_ option: ReceiptNameOption) -> Bool {
        switch option {
        case .listMatch(let suggestion):
            return !customActive && !line.resolvedByAI
                && line.matchedItemID == suggestion.itemID
                && line.name.caseInsensitiveCompare(suggestion.name) == .orderedSame
        case .aiSuggestion(let name):
            return !customActive && line.resolvedByAI
                && line.name.caseInsensitiveCompare(line.aiSuggestedName ?? name) == .orderedSame
        case .currentName(let name):
            return !customActive && line.name.caseInsensitiveCompare(name) == .orderedSame
        case .custom:
            return customActive
        }
    }

    private func select(_ option: ReceiptNameOption) {
        Haptics.impact(.light)
        if case .custom = option {
            customName = line.name
            customActive = true
            // Das Feld existiert erst nach diesem State-Wechsel — Fokus deshalb im nächsten
            // Runloop setzen, sonst läuft `@FocusState` ins Leere.
            DispatchQueue.main.async { customFocused = true }
            return
        }
        customActive = false
        Self.applySelection(&line, option: option)
    }

    private func syncEditorFields() {
        priceText = Self.plainNumber(line.price, fractionDigits: 2)
        quantityMode = line.weightBasis != nil ? .grams : .pieces
        quantityText = Self.plainNumber(line.weightBasis ?? line.quantity, fractionDigits: 0)
    }

    private func applyQuantityFromEditor() {
        guard let value = Self.parseNumber(quantityText) else { return }
        Self.applyQuantityEdit(&line, mode: quantityMode, value: value)
    }

    // MARK: - Reine Regeln (ohne SwiftUI testbar)

    /// Die Auswahlzeilen einer Position, nach den Regeln 1–6 der Spec.
    ///
    /// Höchstens drei inhaltliche Kandidaten (Invariante 5) plus „Anderer Name …" — unabhängig
    /// davon, wie viele Vorschläge `ReceiptResolutionService` liefert (heute bis zu fünf).
    static func selectionOptions(for line: EditableReceiptLine) -> [ReceiptNameOption] {
        // 1. Inhaltliche Kandidaten sammeln.
        var candidates: [ReceiptNameOption] = line.suggestions.prefix(3).map { .listMatch($0) }
        if let aiName = line.aiSuggestedName, !aiName.isEmpty {
            // 2. Dedup: ein namensgleicher Listen-Treffer belegt den Platz, der KI-Name bleibt
            //    über ihn wählbar (Invariante 3).
            let alreadyListed = candidates.contains {
                $0.matchableName?.caseInsensitiveCompare(aiName) == .orderedSame
            }
            if !alreadyListed { candidates.append(.aiSuggestion(name: aiName)) }
        }

        // 3. Der aktuell gewählte Kandidat steht vorn.
        if let selected = candidates.firstIndex(where: {
            $0.matchableName?.caseInsensitiveCompare(line.name) == .orderedSame
        }), selected != 0 {
            let option = candidates.remove(at: selected)
            candidates.insert(option, at: 0)
        }

        // 4. Auf drei kappen.
        candidates = Array(candidates.prefix(3))

        // 5. (Issue #37) Kein verbliebener Kandidat entspricht dem geltenden Namen, und er ist
        //    nicht leer: ihn zusätzlich als vorausgewählte Zeile an Position 0 einfügen. Dafür
        //    entfällt der schwächste (zuletzt gereihte) bisherige Kandidat, damit es bei max. drei
        //    inhaltlichen Optionen bleibt (Invariante 5). Ist `line.name` leer, greift diese Regel
        //    nicht — weiter mit Regel 6 (heutiges Verhalten).
        if !line.name.isEmpty,
           !candidates.contains(where: { $0.matchableName?.caseInsensitiveCompare(line.name) == .orderedSame }) {
            if candidates.count >= 3 { candidates.removeLast() }
            candidates.insert(.currentName(name: line.name), at: 0)
        }

        // 6. Gar kein Kandidat: den heutigen Namen anbieten.
        if candidates.isEmpty { candidates = [.currentName(name: line.name)] }

        // 7. „Anderer Name …" immer als letzte Zeile.
        return candidates + [.custom]
    }

    /// Übernimmt eine gewählte Option in die Zeile — Zeichen für Zeichen dieselben Zuweisungen
    /// wie früher der Chip-Tap bzw. die automatische Auflösung, damit `save()` unverändert lernt.
    static func applySelection(_ line: inout EditableReceiptLine, option: ReceiptNameOption) {
        switch option {
        case .listMatch(let suggestion):
            line.name = suggestion.name
            line.matchedItemID = suggestion.itemID
            line.resolvedByAI = false
        case .aiSuggestion(let name):
            // Aus den gemerkten KI-Feldern, nicht aus dem aktuellen Zustand: nur so lässt sich
            // der KI-Vorschlag nach einer zwischenzeitlich anderen Auswahl exakt wiederherstellen.
            line.name = line.aiSuggestedName ?? name
            line.matchedItemID = line.aiSuggestedMatchedItemID
            line.resolvedByAI = true
        case .currentName(let name):
            line.name = name
        case .custom:
            break
        }
    }

    /// Eigener Name — löst Artikel-Identität und KI-Kennzeichnung, wie früher das freie
    /// TextField-Binding der Zeile. `originalName` bleibt unangetastet.
    static func applyCustomName(_ line: inout EditableReceiptLine, name: String) {
        line.name = name
        line.matchedItemID = nil
        line.resolvedByAI = false
    }

    /// Preis · Menge/Gewicht/Größe · Stück-/Kilo-/Literpreis — in derselben Reihenfolge, die
    /// `EditableReceiptLine.learningQuantity` fürs Preis-Lernen benutzt. Der Nutzer sieht damit
    /// vor dem Speichern genau die Basis, mit der die App rechnen wird.
    static func priceSummary(for line: EditableReceiptLine) -> String {
        let total = currency(line.price)
        if let weight = line.weightBasis, weight > 0 {
            return "\(total) · \(Int(weight.rounded())) g · \(currency(line.price / weight * 1000)) je kg"
        }
        if line.quantity > 1 {
            return "\(total) · \(Int(line.quantity)) St. · \(currency(line.price / line.quantity)) je Stück"
        }
        if let printed = ReceiptParserService.weightBasisFromName(line.originalName), printed > 0 {
            let per = line.unit.lowercased().hasSuffix("l") ? "je l" : "je kg"
            let size = line.unit.isEmpty ? nil : line.unit
            let rate = "\(currency(line.price / printed * 1000)) \(per)"
            return [total, size, rate].compactMap { $0 }.joined(separator: " · ")
        }
        return "\(total) · 1 St. · \(total) je Stück"
    }

    /// Kopfzeile über den Positionen — ersetzt „Gefunden: N Positionen" UND die frühere,
    /// separate „Ausgewählt"-Section.
    static func sectionHeaderText(count: Int, selected: Int, sum: Double) -> String {
        "\(count) Positionen · \(selected) ausgewählt · \(currency(sum))"
    }

    /// Schreibt ausschließlich die Felder, die `learningQuantity` liest — `unit` und
    /// `originalName` (die gedruckte Größe bzw. der Bontext) bleiben immer unverändert.
    static func applyQuantityEdit(_ line: inout EditableReceiptLine, mode: ReceiptQuantityMode, value: Double) {
        switch mode {
        case .pieces:
            // Untergrenze 1: eine Null würde in `learningQuantity` durch null teilen.
            line.quantity = max(1, value.rounded())
            line.weightBasis = nil
        case .grams:
            line.weightBasis = value > 0 ? value : nil
            line.quantity = 1
        }
    }

    // MARK: Formatierung

    private static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: Locale.current.currency?.identifier ?? "EUR"))
    }

    /// Zahl ohne Währungszeichen für die Eingabefelder — im Zahlenformat der Region, damit ein
    /// Nutzer den Wert so wiederfindet, wie er ihn oben liest.
    private static func plainNumber(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).grouping(.never))
    }

    /// Liest „2,00" wie „2.00" — der Ziffernblock liefert je nach Region das eine oder andere.
    private static func parseNumber(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}
