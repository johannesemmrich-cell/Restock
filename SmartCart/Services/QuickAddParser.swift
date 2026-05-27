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
            name = trimmed
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
}
