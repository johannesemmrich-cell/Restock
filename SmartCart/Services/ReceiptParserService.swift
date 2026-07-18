import Foundation
import CoreGraphics

struct ReceiptLine {
    let name: String
    let price: Double        // Zeilen-GESAMTpreis (bei Menge > 1: Menge × Stückpreis)
    var quantity: Double = 1 // Stückzahl (aus "N x P.PP"-Mengenzeile oder Multipack-Token wie "6X1.5L")
    var unit: String = ""    // Größenangabe aus dem Namen, z. B. "1,5l", "400g", "50cl"

    /// Stückpreis (Gesamtpreis ÷ Menge) — Basis für mengenbewusstes Preis-Lernen.
    var unitPrice: Double { quantity > 0 ? price / quantity : price }
}

enum ReceiptParserService {
    // Words that identify administrative lines when matched as whole words.
    // Whole-word matching avoids false positives:
    //   "NUTELLA" contains "tel", "FEUERWERK" contains "eur", "BONBON" contains "bon"
    private static let skipWordSet: Set<String> = [
        "summe", "gesamt", "total", "mwst", "ust", "rabatt", "bon", "kasse",
        "datum", "uhrzeit", "danke", "tschüss", "zahlung",
        "kreditkarte", "ec-karte", "gegeben", "rückgeld", "zwischensumme",
        "pfand", "leergut", "steuer", "netto", "brutto", "kundenquittung",
        "filiale", "öffnungszeiten", "kassierer", "kassenbon", "quittung",
        "eur", "euro", "chf", "gbp", "usd",
        "tva", "tasa", "tax", "vat", "mws",
        "payback", "bonuspunkte", "treuepunkte",
        "mastercard", "visa", "girocard", "pin", "autorisierung",
        "transaktions", "terminal", "belegnr",
        "kundenkarte", "mitglied", "bediener",
        "retoure", "gutschrift", "sofortrabatt",
        // Französische Bons (Carrefour & Co.)
        // ACHTUNG: "merci" gehört NICHT hierher — MERCI ist eine deutsche
        // Schokoladenmarke ("MERCI FINEST SELECTION"). Französische
        // Dankes-Fußzeilen werden über skipPhrases + Euro-Pfad gefiltert.
        "montant", "description", "ttc", "especes", "espèces",
        "rendu", "monnaie", "caisse", "siret", "cheque", "chèque",
        // "TOT.GENERAL"/"S/TOTAL" zerfallen nach Punkt-/Slash-Split in
        // "tot"+"general" bzw. "s"+"total" — "tot" deckt die Abkürzung ab.
        "tot",
        // PATCH Iteration 3: deutsche Fußzeilen mit €-Betrag in der Preisspalte
        "zahlen", "kartenzahlung", "sparen",
        // frz. Kartenzahlung ("CB EMV") + frz. Pfand ("CONSIGNE")
        "emv", "consigne",
    ]
    // Multi-word phrases that always indicate an administrative line (substring match).
    private static let skipPhrases = [
        "vielen dank", "auf wiedersehen", "ihre einkäufe",
        "ihr kassier",
        "inkl. mwst", "inkl mwst",
        "7,00 %", "19,00 %", "7 %", "19 %",
        "www.", "tel:", "fon:", "fax:",
        // Französische Dankes-Fußzeilen (kontextsensitiv statt Einzelwort "merci",
        // damit das Produkt "MERCI FINEST SELECTION" nicht verschluckt wird)
        "merci de votre", "merci et à bientôt", "merci et a bientot",
        "merci pour votre", "merci, à bientôt", "merci a bientot",
        // PATCH Iteration 3: "Coupon-Vorteil" bleibt nach Bindestrich-Tokenisierung
        // ein Token — als Substring-Phrase fangen
        "coupon",
    ]

    private static func isAdminLine(_ lower: String) -> Bool {
        for phrase in skipPhrases where lower.contains(phrase) { return true }
        // Tokenizing auch an "." und "/" — fängt "TOT.GENERAL" und "S/TOTAL"
        // als Whole-Word-Treffer ("tot" bzw. "total").
        return adminWords(lower).contains(where: { skipWordSet.contains($0) })
    }

    private static func adminWords(_ lower: String) -> [String] {
        lower.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "./")))
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
    }

    // Führende Artikelnummern (5+ Ziffern)
    private static let articleNumberRegex = try? NSRegularExpression(pattern: #"^\d{5,}\s+"#)
    // Anhängende MwSt-Kennbuchstaben (A B 1 2 * E am Zeilenende)
    private static let vatSuffixRegex = try? NSRegularExpression(pattern: #"\s+[AB12E\*]\s*$"#)

    // MARK: - Zeilen-Rekonstruktion aus Vision-Beobachtungen

    /// Vision liefert auf Kassenbons mit Spaltenlayout (Name links, Preis rechts) KEINE fertigen
    /// Zeilen, sondern separate Beobachtungen pro Textblock — oft erst alle Namen, dann alle
    /// Preise. Diese Funktion gruppiert Beobachtungen anhand ihrer BoundingBox (normalisierte
    /// Vision-Koordinaten, y wächst nach OBEN) zu physischen Bon-Zeilen: von oben nach unten
    /// sortieren, Blöcke mit nahezu gleicher vertikaler Mitte bündeln, innerhalb einer Zeile von
    /// links nach rechts mit 2+ Leerzeichen verbinden (damit greift das "tightRegex"-Spaltenmuster).
    static func reconstructLines(_ blocks: [(text: String, box: CGRect)]) -> [String] {
        let sorted = blocks.sorted { $0.box.midY > $1.box.midY }
        var groups: [[(text: String, box: CGRect)]] = []
        for block in sorted {
            if let lastIndex = groups.indices.last, let ref = groups[lastIndex].first,
               abs(block.box.midY - ref.box.midY) < max(ref.box.height, block.box.height) * 0.6 {
                groups[lastIndex].append(block)
            } else {
                groups.append([block])
            }
        }
        return groups.map { group in
            group.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ")
        }
    }

    // MARK: - Parsing

    static func parse(_ lines: [String]) -> [ReceiptLine] {
        // Formaterkennung: mehrere POSITIONS-Zeilen mit Währungs-SUFFIX hinter dem Preis
        // (z. B. "…TOMATE ENTIER  2.50€") bedeuten einen südeuropäischen Bon
        // (Frankreich/Carrefour-Stil) mit eigener Struktur. Gezählt wird erst NACH dem
        // Admin-Filter und nur, wenn der Preis-Chunk am ZEILENENDE steht (Spalten-Split) —
        // deutsche Fußzeilen wie "Sie sparen heute 0,50 €" (€-Betrag im Fließtext)
        // kippen die Weiche damit nicht mehr.
        let euroSuffixCount = lines.filter { isEuroSuffixItemCandidate($0) }.count
        let classicCount = lines.filter { isClassicVatItemCandidate($0) }.count
        if euroSuffixCount >= 2, euroSuffixCount > classicCount {
            return parseEuroSuffixStyle(lines)
        }
        return parseClassic(lines)
    }

    /// PATCH Iteration 3: klassischer deutscher Positions-Kandidat — Spaltenform mit
    /// Preis + PFLICHT-MwSt-Kürzel ("EMMENTALER  2,19 A"). Überwiegen diese Zeilen,
    /// bleibt der Bon im klassischen Pfad, auch wenn €-Fußzeilen auftauchen.
    private static func isClassicVatItemCandidate(_ rawLine: String) -> Bool {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard line.count >= 3, !isAdminLine(line.lowercased()) else { return false }
        return line.range(of: #"^.+?\s{2,}-?\d{1,4}[,\.]\d{2}\s*[AB12E\*]\s*$"#,
                          options: .regularExpression) != nil
    }

    /// Positions-Kandidat im Euro-Suffix-Format: keine Admin-Zeile, mindestens zwei
    /// Spalten-Chunks (Name links, Preis rechts) und der LETZTE Chunk ist ein reiner
    /// Preis mit Währungssymbol ("2.50€", OCR-bedingt auch "1.55฿"/"3.99₴").
    private static func isEuroSuffixItemCandidate(_ rawLine: String) -> Bool {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard line.count >= 3, !isAdminLine(line.lowercased()) else { return false }
        let chunks = line
            .replacingOccurrences(of: #"\s{2,}"#, with: "\t", options: .regularExpression)
            .components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard chunks.count >= 2, let last = chunks.last else { return false }
        return last.range(of: #"^-?\d{1,4}[.,]\d{2}\s*\p{Sc}$"#, options: .regularExpression) != nil
    }

    // MARK: - Klassisches Format (deutsche Bons: "EMMENTALER   2,19 A")

    private static func parseClassic(_ lines: [String]) -> [ReceiptLine] {
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
            if isAdminLine(lower) {
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

                // Allow names starting with numbers ("2er Pack", "3M") —
                // only reject names that are entirely digits/spaces (article codes).
                guard rawName.count >= 2,
                      !rawName.allSatisfy({ $0.isNumber || $0 == " " }),
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
                    if candidate.count >= 2 {
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

    // MARK: - Euro-Suffix-Format (französische Bons, z. B. Carrefour)
    //
    // Beispielzeilen (nach Rekonstruktion):
    //   "6 *400G TOMATE ENTIER  2.50€"     → TVA-Spalte 6, Name, Gesamtpreis
    //   "2 x 1.25€"                        → Mengenzeile zur VORHERIGEN Position
    //   "6  *6X1.5L CRISTALINE  1.20€"     → Multipack-Token im Namen
    //   "6 *1L PET HUILE OLIVE  100  9.09€" → "100" ist OCR-Müll (Spiegeltext im Foto)

    // Preis-Chunk: "2.50", "2.50€", auch "3.99g" (OCR liest € als g) sowie beliebige
    // Währungssymbole (\p{Sc}) — Vision halluziniert auf Fotos auch "1.55฿" oder "3.99₴".
    private static let euroPriceChunkRegex = try? NSRegularExpression(
        pattern: #"^-?\d{1,4}[.,]\d{2}\s*(?:\p{Sc}|g)?$"#
    )
    // Mengenzeile "2 x 1.25" / "2 x 1.25€" (Währungssymbol OCR-tolerant)
    private static let euroQtyRegex = try? NSRegularExpression(
        pattern: #"^(\d{1,3})\s*x\s*(\d{1,4}[.,]\d{2})\s*\p{Sc}?$"#, options: [.caseInsensitive]
    )
    // Multipack-Token im Namen: "6X1.5L", "6X1,5L", "2X120G", "12X25CL"
    private static let multipackRegex = try? NSRegularExpression(
        pattern: #"\b(\d{1,2})\s*x\s*(\d+(?:[.,]\d+)?)\s*(kg|g|l|cl|ml)\b"#, options: [.caseInsensitive]
    )
    // Einzelgröße im Namen: "100G", "1L", "50 CL", "850G"
    private static let sizeRegex = try? NSRegularExpression(
        pattern: #"\b(\d+(?:[.,]\d+)?)\s*(kg|g|l|cl|ml)\b"#, options: [.caseInsensitive]
    )

    // OCR auf Bon-Fotos halluziniert aus gespiegeltem Hintergrundtext kyrillische Zeichen
    // ("ЗаХ3И", "подио9") — solche Chunks sind nie echte Positionen.
    private static func containsCyrillic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    private static func parseEuroSuffixStyle(_ lines: [String]) -> [ReceiptLine] {
        var results: [ReceiptLine] = []
        var pendingName: String? = nil

        for rawLine in lines {
            let line = rawLine
                .replacingOccurrences(of: "х", with: "x") // kyrillisches Cha aus OCR ("2 х 1.25€")
                .replacingOccurrences(of: "Х", with: "X")
                .replacingOccurrences(of: "×", with: "x")
                .trimmingCharacters(in: .whitespaces)
            guard line.count >= 3 else { continue }
            if isAdminLine(line.lowercased()) { pendingName = nil; continue }

            // Eigenständige Mengenzeile "2 x 1.25€" → Menge der VORHERIGEN Position.
            // Nur übernehmen, wenn Menge × Stückpreis zum Zeilenpreis passt (±5 ct).
            let nsLine = NSRange(line.startIndex..., in: line)
            if let rx = euroQtyRegex, let m = rx.firstMatch(in: line, range: nsLine),
               let nRange = Range(m.range(at: 1), in: line),
               let pRange = Range(m.range(at: 2), in: line) {
                if let n = Double(line[nRange]),
                   let p = Double(line[pRange].replacingOccurrences(of: ",", with: ".")),
                   n >= 2, n <= 99, !results.isEmpty {
                    let last = results.count - 1
                    if abs(results[last].price - n * p) <= 0.05 {
                        results[last].quantity = n
                    }
                }
                continue
            }

            // Gewichts-/Multiplikatorzeilen ("0,835 kg x 1,99 /kg") sind NIE eigene Artikel.
            // Bewusst enger als im klassischen Pfad (kein blankes " x "), damit Zeilen mit
            // Inline-Mengen-Chunk ("NAME  2 x 1.25  2.50€") nicht verschluckt werden.
            // Trägt die Gewichtszeile selbst einen Endpreis, gehört er zur schwebenden
            // Namenszeile davor; sonst Zeile verwerfen und den schwebenden Namen behalten
            // (der Preis folgt dann als eigene Preiszeile, z. B. "1.66€").
            let lowerLine = line.lowercased()
            if lowerLine.contains("/kg") || lowerLine.contains("/stk")
                || lowerLine.contains(" kg x ") || lowerLine.contains(" stk x ") {
                if let pending = pendingName, let price = extractTrailingEuroPrice(from: line) {
                    // PATCH Iteration 3: schwebenden Namen wie jede Euro-Position bereinigen
                    let cleaned = cleanEuroName(pending)
                    results.append(ReceiptLine(name: cleaned.name, price: price,
                                               quantity: cleaned.quantity, unit: cleaned.unit))
                    pendingName = nil
                }
                continue
            }

            // Spalten-Chunks: die Rekonstruktion verbindet Vision-Blöcke mit 2+ Leerzeichen.
            // Kyrillischer OCR-Müll fliegt sofort raus.
            var chunks = line
                .replacingOccurrences(of: #"\s{2,}"#, with: "\t", options: .regularExpression)
                .components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !containsCyrillic($0) }

            // Preis: letzter preisförmiger Chunk (von rechts gesucht, wie auf dem Bon gedruckt)
            var price: Double? = nil
            if let rx = euroPriceChunkRegex {
                for i in stride(from: chunks.count - 1, through: 0, by: -1) {
                    let chunk = chunks[i]
                    let r = NSRange(chunk.startIndex..., in: chunk)
                    if rx.firstMatch(in: chunk, range: r) != nil {
                        let numeric = chunk
                            .replacingOccurrences(of: #"[\p{Sc}g\s]"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: ",", with: ".")
                        price = Double(numeric)
                        chunks.remove(at: i)
                        break
                    }
                }
            }

            // Name: erster Chunk mit Buchstaben. Einzelziffern-Chunks sind die TVA-Spalte (6/7).
            // Chunks NACH dem Namen sind entweder eine Inline-Mengenangabe ("2 x 1.25") oder
            // OCR-Müll aus der Bildmitte ("100", "19108", "ITXIM") — Müll wird verworfen.
            var name: String? = nil
            var inlineQty: (n: Double, p: Double)? = nil
            for chunk in chunks {
                if chunk.count == 1, chunk.first?.isNumber == true { continue } // TVA-Spalte
                if name == nil, chunk.contains(where: { $0.isLetter }) { name = chunk; continue }
                if let rx = euroQtyRegex {
                    let r = NSRange(chunk.startIndex..., in: chunk)
                    if let m = rx.firstMatch(in: chunk, range: r),
                       let nRange = Range(m.range(at: 1), in: chunk),
                       let pRange = Range(m.range(at: 2), in: chunk),
                       let n = Double(chunk[nRange]),
                       let p = Double(chunk[pRange].replacingOccurrences(of: ",", with: ".")),
                       n >= 2, n <= 99 {
                        inlineQty = (n, p)
                    }
                }
            }

            if let price {
                // Negative Preise (Rabatte) und Unsinn ignorieren
                guard price > 0.05, price < 999 else { pendingName = nil; continue }
                // Name auf dieser Zeile, sonst von der vorherigen namensspaltigen Zeile
                // (Vision trennt Name- und Preisspalte gelegentlich in zwei Zeilen)
                let rawName = name ?? pendingName
                pendingName = nil
                guard let rawName else { continue }

                let cleaned = cleanEuroName(rawName)
                var quantity = cleaned.quantity
                if let inlineQty, abs(price - inlineQty.n * inlineQty.p) <= 0.05 {
                    quantity = inlineQty.n
                }
                guard cleaned.name.count >= 2,
                      !cleaned.name.allSatisfy({ $0.isNumber || $0 == " " }) else { continue }
                results.append(ReceiptLine(name: cleaned.name, price: price, quantity: quantity, unit: cleaned.unit))
            } else if let name {
                // Französische Dankes-Fußzeile ohne Preis ("MERCI", "MERCI DE VOTRE VISITE"):
                // nie als schwebenden Produktnamen übernehmen. Nur im Euro-Pfad — im
                // klassischen Pfad bleibt MERCI (Schokolade) ein normales Produkt.
                if adminWords(name.lowercased()).contains("merci") {
                    pendingName = nil
                } else {
                    pendingName = name
                }
            }
            // Zeilen ganz ohne Name & Preis (reiner Müll): pendingName bewusst behalten,
            // damit gespiegelter Hintergrundtext eine Name/Preis-Paarung nicht zerreißt.
        }

        // Duplikate entfernen (letzter Preis gewinnt bei gleichem Namen), wie im klassischen Pfad
        var seen: [String: ReceiptLine] = [:]
        for r in results { seen[r.name.lowercased()] = r }
        return seen.values.sorted { $0.name < $1.name }
    }

    /// Bereinigt einen rohen Carrefour-Positionsnamen:
    /// TVA-Ziffer + "*"-Präfix strippen, Multipack-/Größen-Token als Menge+Einheit extrahieren,
    /// Verpackungs-Kürzel entfernen. "6 *6X1.5L CRISTALINE" → ("Cristaline", 6, "1,5l")
    private static func cleanEuroName(_ raw: String) -> (name: String, quantity: Double, unit: String) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        // Angeklebte TVA-Ziffer vor dem Stern ("6 *1L PET …") und führende Sterne
        s = s.replacingOccurrences(of: #"^\d\s+(?=\*)"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\*+\s*"#, with: "", options: .regularExpression)

        var quantity: Double = 1
        var unit = ""

        if let rx = multipackRegex,
           let m = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let nRange = Range(m.range(at: 1), in: s),
           let sizeRange = Range(m.range(at: 2), in: s),
           let unitRange = Range(m.range(at: 3), in: s),
           let fullRange = Range(m.range, in: s) {
            quantity = Double(s[nRange]) ?? 1
            unit = s[sizeRange].replacingOccurrences(of: ".", with: ",") + s[unitRange].lowercased()
            s.removeSubrange(fullRange)
        } else if let rx = sizeRegex,
                  let m = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let sizeRange = Range(m.range(at: 1), in: s),
                  let unitRange = Range(m.range(at: 2), in: s),
                  let fullRange = Range(m.range, in: s) {
            unit = s[sizeRange].replacingOccurrences(of: ".", with: ",") + s[unitRange].lowercased()
            s.removeSubrange(fullRange)
        }

        func tidy(_ str: String) -> String {
            str.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: " .,-*"))
        }
        func viable(_ str: String) -> Bool {
            str.count >= 2 && str.contains(where: { $0.isLetter })
        }

        var cleaned = tidy(s)
        // Verpackungs-Kürzel: PET(-Flasche), BLE/BLLE (bouteille), BTE (boîte)
        let withoutPackaging = tidy(cleaned.replacingOccurrences(
            of: #"(?i)\b(PET|BLE|BLLE|BTE)\b"#, with: "", options: .regularExpression))
        if viable(withoutPackaging) {
            cleaned = withoutPackaging
        }
        if !viable(cleaned) { cleaned = tidy(s) }
        if !viable(cleaned) { cleaned = tidy(raw) }
        return (smartCapitalize(cleaned), quantity, unit)
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

    // Preis am Zeilenende extrahieren, Euro-Suffix-Variante ("… 1.66€" / "… 1.66")
    private static func extractTrailingEuroPrice(from line: String) -> Double? {
        let pattern = #"(\d{1,4}[.,]\d{2})\s*\p{Sc}?\s*$"#
        guard let rx = try? NSRegularExpression(pattern: pattern),
              let match = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        let raw = String(line[range]).replacingOccurrences(of: ",", with: ".")
        guard let price = Double(raw), price > 0.05, price < 999 else { return nil }
        return price
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
