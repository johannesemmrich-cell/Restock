import Foundation

struct ReceiptLine {
    let name: String
    let price: Double
}

enum ReceiptParserService {
    private static let skipKeywords = [
        "summe", "gesamt", "total", "mwst", "ust", "rabatt", "bon", "kasse",
        "datum", "uhrzeit", "tel", "www", "danke", "tschüss", "zahlung",
        "kreditkarte", "ec-karte", "gegeben", "rückgeld", "zwischensumme",
        "pfand", "leergut", "steuer", "netto", "brutto", "kundenquittung",
        "filiale", "öffnungszeiten", "kassierer", "kassenbon",
        // Währungscodes und -symbole
        "eur", "euro", "chf", "gbp", "usd", "dkk", "sek", "nok", "pln", "czk",
        "tva", "tasa", "tax", "vat"
    ]

    // Regex zum Entfernen führender Artikelnummern (5+ Ziffern gefolgt von Leerzeichen)
    private static let articleNumberRegex = try? NSRegularExpression(pattern: #"^\d{5,}\s+"#)

    static func parse(_ lines: [String]) -> [ReceiptLine] {
        // Match: any leading text, then whitespace, then a German/English price (e.g. 1,99 or 1.99),
        // optionally followed by a tax indicator (A, B, *).
        guard let priceRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s{2,}(\d{1,3}[,\.]\d{2})\s*[AB*]?\s*$"#
        ) else { return [] }

        // Also try a loose version for lines with single whitespace separator.
        guard let looseRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s+(\d{1,3}[,\.]\d{2})\s*[AB*]?\s*$"#
        ) else { return [] }

        var results: [ReceiptLine] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 5 else { continue }

            let lower = trimmed.lowercased()
            guard !skipKeywords.contains(where: { lower.contains($0) }) else { continue }

            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)

            // Prefer tight match (2+ spaces before price), fall back to loose (1 space).
            let match = priceRegex.firstMatch(in: trimmed, range: nsRange)
                ?? looseRegex.firstMatch(in: trimmed, range: nsRange)

            guard let match,
                  let nameRange = Range(match.range(at: 1), in: trimmed),
                  let priceRange = Range(match.range(at: 2), in: trimmed) else { continue }

            var rawName = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)

            // Strip leading article numbers (e.g. "123456 HACKFLEISCH" → "HACKFLEISCH")
            if let regex = articleNumberRegex {
                let nsRange = NSRange(rawName.startIndex..., in: rawName)
                rawName = regex.stringByReplacingMatches(in: rawName, range: nsRange, withTemplate: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            let rawPrice = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: ".")

            // Name must be at least 2 chars and not start with a digit.
            guard rawName.count >= 2,
                  !(rawName.first?.isNumber ?? true),
                  let price = Double(rawPrice),
                  price > 0.01,
                  price < 500 else { continue }

            results.append(ReceiptLine(name: rawName.capitalized, price: price))
        }

        return results
    }
}
