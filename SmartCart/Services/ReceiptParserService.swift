import Foundation

struct ReceiptLine {
    let name: String
    let price: Double
}

enum ReceiptParserService {
    private static let skipKeywords = [
        "summe", "gesamt", "total", "mwst", "ust", "rabatt", "bon", "kasse",
        "datum", "uhrzeit", "tel", "www.", "danke", "tschüss", "zahlung",
        "kreditkarte", "ec-karte", "gegeben", "rückgeld", "zwischensumme",
        "pfand", "leergut", "steuer", "netto", "brutto", "kundenquittung",
        "filiale", "öffnungszeiten", "kassierer", "kassenbon", "quittung",
        "vielen dank", "auf wiedersehen", "ihre einkäufe",
        "eur", "euro", "chf", "gbp", "usd",
        "tva", "tasa", "tax", "vat", "mws",
        "payback", "bonuspunkte", "treuepunkte",
        "mastercard", "visa", "girocard", "pin", "autorisierung",
        "transaktions", "terminal", "belegnr",
        "kundenkarte", "mitglied",
        "ihr kassier", "bediener",
        "retoure", "gutschrift", "sofortrabatt",
        "inkl. mwst", "inkl mwst",
        "7,00 %", "19,00 %", "7 %", "19 %"
    ]

    // Führende Artikelnummern (5+ Ziffern)
    private static let articleNumberRegex = try? NSRegularExpression(pattern: #"^\d{5,}\s+"#)
    // Anhängende MwSt-Kennbuchstaben (A B 1 2 * E am Zeilenende)
    private static let vatSuffixRegex = try? NSRegularExpression(pattern: #"\s+[AB12E\*]\s*$"#)

    static func parse(_ lines: [String]) -> [ReceiptLine] {
        // Bevorzugt: Name + 2+ Leerzeichen + Preis (+ opt. MwSt-Kürzel)
        guard let tightRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s{2,}(-?\d{1,4}[,\.]\d{2})\s*[AB12E\*]?\s*$"#
        ) else { return [] }
        // Fallback: 1 Leerzeichen vor Preis
        guard let looseRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s+(-?\d{1,4}[,\.]\d{2})\s*[AB12E\*]?\s*$"#
        ) else { return [] }
        // Nur-Preis-Zeile (für gewichtsbasierte Artikel)
        guard let priceOnlyRegex = try? NSRegularExpression(
            pattern: #"^(-?\d{1,4}[,\.]\d{2})\s*[AB12E\*]?\s*$"#
        ) else { return [] }

        var results: [ReceiptLine] = []
        var pendingName: String? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { pendingName = nil; continue }

            let lower = trimmed.lowercased()

            // Administrative Zeilen überspringen
            if skipKeywords.contains(where: { lower.contains($0) }) {
                pendingName = nil; continue
            }
            // Reine Zahlenzeilen (EAN, Artikelnr.) überspringen
            if trimmed.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) {
                pendingName = nil; continue
            }
            // Gewichts-/Multiplikatorzeilen überspringen ("0,436 kg x 12,49")
            if lower.contains(" x ") || lower.contains(" × ") || lower.contains("/kg") || lower.contains("/stk") {
                // Preis aus dieser Zeile extrahieren und mit pendingName verknüpfen
                if let pending = pendingName, let price = extractTrailingPrice(from: trimmed) {
                    results.append(ReceiptLine(name: pending, price: price))
                    pendingName = nil
                }
                continue
            }

            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)

            // Pendingname + Nur-Preis-Zeile → gewichtsbasierter Artikel
            if let pending = pendingName {
                if let match = priceOnlyRegex.firstMatch(in: trimmed, range: nsRange),
                   let priceRange = Range(match.range(at: 1), in: trimmed) {
                    let raw = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: ".")
                    if let price = Double(raw), price > 0.05, price < 999 {
                        results.append(ReceiptLine(name: pending, price: price))
                        pendingName = nil
                        continue
                    }
                }
                pendingName = nil
            }

            // Negative Preise (Rabatte) ignorieren
            if trimmed.hasPrefix("-") { continue }

            // Normales Preismuster
            let match = tightRegex.firstMatch(in: trimmed, range: nsRange)
                ?? looseRegex.firstMatch(in: trimmed, range: nsRange)

            if let match,
               let nameRange = Range(match.range(at: 1), in: trimmed),
               let priceRange = Range(match.range(at: 2), in: trimmed) {

                var rawName = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)

                // Führende Artikelnummern entfernen
                if let rx = articleNumberRegex {
                    let r = NSRange(rawName.startIndex..., in: rawName)
                    rawName = rx.stringByReplacingMatches(in: rawName, range: r, withTemplate: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                // Anhängendes MwSt-Kürzel entfernen
                if let rx = vatSuffixRegex {
                    let r = NSRange(rawName.startIndex..., in: rawName)
                    rawName = rx.stringByReplacingMatches(in: rawName, range: r, withTemplate: "")
                        .trimmingCharacters(in: .whitespaces)
                }

                let rawPrice = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: ".")

                guard rawName.count >= 2,
                      !(rawName.first?.isNumber ?? true),
                      let price = Double(rawPrice),
                      price > 0.05,
                      price < 999 else { continue }

                results.append(ReceiptLine(name: smartCapitalize(rawName), price: price))
                pendingName = nil

            } else {
                // Kein Preis auf dieser Zeile → ggf. Produktname für nächste Zeile merken
                let hasLetters = trimmed.contains(where: { $0.isLetter })
                if hasLetters && trimmed.count >= 2 && trimmed.count <= 60 {
                    var candidate = trimmed
                    if let rx = articleNumberRegex {
                        let r = NSRange(candidate.startIndex..., in: candidate)
                        candidate = rx.stringByReplacingMatches(in: candidate, range: r, withTemplate: "")
                            .trimmingCharacters(in: .whitespaces)
                    }
                    if candidate.count >= 2 && !(candidate.first?.isNumber ?? true) {
                        pendingName = smartCapitalize(candidate)
                    }
                }
            }
        }

        // Duplikate entfernen (letzter Preis gewinnt bei gleichem Namen)
        var seen: [String: ReceiptLine] = [:]
        for r in results { seen[r.name.lowercased()] = r }
        return seen.values.sorted { $0.name < $1.name }
    }

    // Preis am Zeilenende extrahieren (für Gewichtszeilen)
    private static func extractTrailingPrice(from line: String) -> Double? {
        let pattern = #"(\d{1,4}[,\.]\d{2})\s*[AB12E\*]?\s*$"#
        guard let rx = try? NSRegularExpression(pattern: pattern),
              let match = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        let raw = String(line[range]).replacingOccurrences(of: ",", with: ".")
        let price = Double(raw)
        return (price ?? 0) > 0.05 ? price : nil
    }

    // Intelligente Großschreibung: NUR-GROSSBUCHSTABEN → Ersten Buchstaben groß, Rest klein
    private static func smartCapitalize(_ s: String) -> String {
        let letters = s.filter { $0.isLetter }
        guard !letters.isEmpty else { return s }
        let isAllCaps = letters == letters.uppercased()
        guard isAllCaps else { return s }
        // Erstes Wort kapitalisieren, Rest lowercase
        let words = s.components(separatedBy: " ")
        return words.enumerated().map { i, w in
            i == 0 ? (w.first.map { String($0).uppercased() } ?? "") + w.dropFirst().lowercased()
                   : w.lowercased()
        }.joined(separator: " ")
    }
}
