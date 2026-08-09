import Foundation

struct QuickAddResult {
    var name: String
    var quantity: String
    var quantityAmount: Double
    var unit: String
}

enum QuickAddParser {
    private static let knownUnits: [String] = [
        "kg", "g", "mg", "ml", "l", "cl", "dl",
        "kilogramm", "gramm", "milligramm", "liter", "milliliter", "zentiliter", "deziliter",
        "el", "tl", "tbsp", "tsp",
        "stk", "stück", "stücke", "pck", "pkg", "pkt",
        "dose", "dosen", "flasche", "flaschen", "glas", "gläser",
        "bund", "bündel", "prise", "priesen",
        "päckchen", "packung", "packungen",
        "becher", "tube", "tuben", "karton", "kartons",
        "portion", "portionen", "würfel", "rolle", "rollen", "blatt", "blätter",
        "can", "bottle", "box", "bag", "pack", "piece", "pieces",
    ]

    private static let wordNumbers: [String: Double] = [
        "ein": 1, "eine": 1, "einen": 1, "einem": 1, "einer": 1,
        "zwei": 2, "drei": 3, "vier": 4, "fünf": 5,
        "sechs": 6, "sieben": 7, "acht": 8, "neun": 9, "zehn": 10,
        "half": 0.5, "halbe": 0.5, "halber": 0.5, "halbes": 0.5,
    ]

    /// Parses smart quick-add input.
    /// Examples:
    ///   "Milch"          → {name:"Milch", qty:"1", unit:""}
    ///   "2 Milch"        → {name:"Milch", qty:"2", unit:""}
    ///   "2x Milch"       → {name:"Milch", qty:"2", unit:""}
    ///   "200g Mehl"      → {name:"Mehl",  qty:"200", unit:"g"}
    ///   "1,5 kg Äpfel"   → {name:"Äpfel", qty:"1.5", unit:"kg"}
    ///   "3 EL Olivenöl"  → {name:"Olivenöl", qty:"3", unit:"EL"}
    static func parse(_ input: String) -> QuickAddResult {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return QuickAddResult(name: trimmed, quantity: "1", quantityAmount: 1, unit: "")
        }

        // Tokenize
        var tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            return QuickAddResult(name: trimmed, quantity: "1", quantityAmount: 1, unit: "")
        }

        // Try to parse leading number from first token (handles "200g", "2x", "1,5", "ein", "zwei"…)
        var qty: Double? = nil
        var unit: String = ""
        var consumed = 0

        let first = tokens[0]
        // Strip trailing 'x' or 'X' for "2x"
        let firstClean = first.hasSuffix("x") || first.hasSuffix("X")
            ? String(first.dropLast())
            : first

        // Check word-numbers first ("ein", "zwei", "halbe"…)
        if let wordQty = wordNumbers[firstClean.lowercased()] {
            qty = wordQty
            consumed = 1
        }

        // Check if first token starts with a digit (possibly glued to unit: "200g")
        if qty == nil {
            let numPattern = #"^(\d+[\.,]?\d*)"#
            if let numRange = firstClean.range(of: numPattern, options: .regularExpression) {
                let numStr = String(firstClean[numRange])
                    .replacingOccurrences(of: ",", with: ".")
                if let parsed = Double(numStr) {
                    qty = parsed
                    consumed = 1

                    // Remainder of first token could be a unit: "200g" → unit "g"
                    let remainder = String(firstClean[numRange.upperBound...]).lowercased()
                    if !remainder.isEmpty && knownUnits.contains(remainder) {
                        unit = String(firstClean[numRange.upperBound...]) // preserve case
                    }
                }
            }
        }

        // If we got a quantity and no unit yet, check if next token is a unit
        if qty != nil && unit.isEmpty && tokens.count > consumed {
            let candidate = tokens[consumed].lowercased()
            if knownUnits.contains(candidate) {
                unit = tokens[consumed]
                consumed += 1
            }
        }

        // Remaining tokens form the name
        let name: String
        if qty != nil && consumed < tokens.count {
            name = tokens[consumed...].joined(separator: " ")
        } else if qty != nil && consumed >= tokens.count {
            // Number only (e.g. just "2") — treat as name "2" with qty 1
            name = trimmed
            qty = nil
        } else {
            // No leading quantity — try trailing: "Hackfleisch 3kg", "Hackfleisch 3 kg", "Milch 2", "Milch 4x"
            var trailingName = trimmed
            if tokens.count >= 2 {
                let last = tokens[tokens.count - 1]
                // Strip trailing 'x'/'X' multiplier suffix: "4x" → "4"
                let lastClean = (last.hasSuffix("x") || last.hasSuffix("X")) ? String(last.dropLast()) : last
                let numPat = #"^(\d+[\.,]?\d*)"#
                // Try "3kg" glued or plain-number/Nx pattern
                if let numRange = lastClean.range(of: numPat, options: .regularExpression) {
                    let numStr = String(lastClean[numRange]).replacingOccurrences(of: ",", with: ".")
                    if let parsed = Double(numStr) {
                        let unitPart = String(lastClean[numRange.upperBound...]).lowercased()
                        if !unitPart.isEmpty && knownUnits.contains(unitPart) {
                            // "3kg" glued: has unit
                            qty = parsed
                            unit = String(lastClean[numRange.upperBound...])
                            trailingName = tokens.dropLast().joined(separator: " ")
                        } else if unitPart.isEmpty {
                            // Plain number "Milch 2" or "x"-stripped "Milch 4x"
                            qty = parsed
                            trailingName = tokens.dropLast().joined(separator: " ")
                        }
                    }
                }
                // Try "3 kg" separated pattern
                if qty == nil && tokens.count >= 3 {
                    let lastLower = tokens[tokens.count - 1].lowercased()
                    if knownUnits.contains(lastLower) {
                        let numStr = tokens[tokens.count - 2].replacingOccurrences(of: ",", with: ".")
                        if let parsed = Double(numStr) {
                            qty = parsed
                            unit = tokens[tokens.count - 1]
                            trailingName = tokens.dropLast(2).joined(separator: " ")
                        }
                    }
                }
            }
            name = trailingName
        }

        let finalQty = qty ?? 1.0
        let qtyStr = finalQty == finalQty.rounded() ? "\(Int(finalQty))" : String(format: "%.1f", finalQty)

        return QuickAddResult(
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: qtyStr,
            quantityAmount: finalQty,
            unit: unit
        )
    }

    /// Returns a formatted preview hint, e.g. "2× · kg · Mehl"
    static func hint(for input: String) -> String? {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let r = parse(input)
        guard r.name != input.trimmingCharacters(in: .whitespaces) || !r.unit.isEmpty else { return nil }
        var parts: [String] = []
        if r.quantityAmount != 1 { parts.append("\(r.quantity)×") }
        if !r.unit.isEmpty { parts.append(r.unit) }
        parts.append(r.name)
        return parts.joined(separator: " · ")
    }

    /// Diakritik-gefaltete Kleinschreibung fürs Vorschlags-Matching — "Äpfel" soll auch bei "Ap"
    /// als Eingabe treffen, nicht nur bei exakt "Äp".
    private static func foldedLower(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }

    /// Namen, die der Nutzer schon mal gekauft/eingetippt/auf die Liste gesetzt hat. Präfix-Match
    /// zuerst (präzise genug für ruhiges Autocomplete-während-des-Tippens), bei zu wenigen
    /// Treffern zusätzlich eine Teilstring-Suche als zweiten Pass — damit z. B. "fel" noch
    /// "Apfel" findet, nicht nur Namen, die exakt damit ANFANGEN. Schwelle 2 Zeichen statt der
    /// sonst in diesem Bereich üblichen `>= 3`: Präfix-Matching ist präzise genug, dass kurze
    /// deutsche Grundnahrungsmittel ("Ei" → "Eier") schon ab 2 Zeichen sinnvoll greifen.
    ///
    /// `itemNames` ergänzt die Kaufhistorie (`records`) um Namen, die zwar schon mal auf einer
    /// Liste standen, aber nie als `PurchaseRecord` abgehakt wurden — sonst verschwinden gerade
    /// erst hinzugefügte, noch nicht abgeschlossene Artikel komplett aus den Vorschlägen.
    /// Niedrigere Priorität als `records` (wird nach der Kaufhistorie angehängt), da Kaufhistorie
    /// die verlässlichere "wirklich gebraucht"-Signal ist.
    static func knownProductSuggestions(for input: String, in records: [PurchaseRecord], itemNames: [String] = [], limit: Int = 5) -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let inputLower = foldedLower(trimmed)

        let candidateNames = records.sorted(by: { $0.date > $1.date }).map(\.itemName) + itemNames

        var seenLower = Set<String>()
        var result: [String] = []

        func collect(_ matches: (String) -> Bool) {
            for name in candidateNames {
                if result.count == limit { return }
                let lower = foldedLower(name)
                guard lower != inputLower, !seenLower.contains(lower), matches(lower) else { continue }
                seenLower.insert(lower)
                result.append(name)
            }
        }

        collect { $0.hasPrefix(inputLower) }
        if result.count < limit {
            collect { $0.contains(inputLower) }
        }
        return result
    }
}
