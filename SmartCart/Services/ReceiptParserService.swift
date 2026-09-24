import Foundation
import CoreGraphics
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ReceiptLine {
    let name: String
    var price: Double        // Zeilen-GESAMTpreis (bei Menge > 1: Menge × Stückpreis; nachträglich
                              // veränderlich, z. B. um einen Pfand-/Consigne-Betrag zu addieren)
    var quantity: Double = 1 // Stückzahl (aus "N x P.PP"-Mengenzeile oder Multipack-Token wie "6X1.5L")
    var unit: String = ""    // Größenangabe aus dem Namen, z. B. "1,5l", "400g", "50cl"
    /// Bei Gewichtszeilen ("0,500 kg x 2,29") das erkannte Gewicht umgerechnet in Gramm (z. B.
    /// 500 für "0,500 kg") — bewusst NICHT in `quantity` abgelegt, weil `quantity` als Stückzahl
    /// in der Review-UI angezeigt wird (`ReceiptReviewCard.priceSummary`: "N St. · … je Stück")
    /// und dort ein Gewichts-Divisor als "500 St." erscheinen würde. Dient ausschließlich als
    /// verlässlicher Divisor beim Preis-Lernen (`ReceiptScannerView.save()`), unabhängig davon,
    /// ob ein historischer Artikel-Match existiert — der bisher (`match?.quantityAmount`) die
    /// einzige Quelle für einen korrekten Gewichts-Divisor war und bei einem ERSTEN Scan eines
    /// neuen Gewichtsartikels fehlt (dann fiel der Divisor fälschlich auf 1 zurück).
    var weightBasis: Double? = nil

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
        // Rewe-Fußzeile: "Gesamtbetrag" ist ein zusammengesetztes Wort, matcht das vorhandene
        // "gesamt" deshalb NICHT über den Whole-Word-Vergleich (siehe Kommentar oben) — eigener
        // Eintrag nötig, sonst rutscht die MwSt-Aufschlüsselungszeile ("Gesamtbetrag 27,29 2,15
        // 29,44") als Phantom-Artikel durch.
        "gesamtbetrag",
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

    // MwSt-Aufschlüsselungs-Tabellenzeile — Kennung gefolgt von "=" am Zeilenanfang, dann der
    // Prozentsatz und die Brutto/Netto/MwSt-Spalten. Die Kennung ist je nach Kassensystem ein
    // Buchstabe ("A= 19,0% 2,02 0,38 2,40", Rewe) ODER eine Ziffer ("1=19,00% 25,45 21,39 4,06",
    // DM — reales Beispiel, wurde ohne diese Erweiterung fälschlich als Produktposition erkannt).
    // Kommt in Produktnamen so nicht vor, kein Wort aus skipWordSet/skipPhrases deckt das ab.
    private static let vatSummaryRowRegex = try? NSRegularExpression(pattern: #"^[A-Za-z0-9]\s*=\s*\d"#)

    /// Prüft, ob `lowercasedWord` (bereits klein geschrieben) ein bekanntes
    /// Kassenbon-Verwaltungswort ist (siehe `skipWordSet` oben). Nicht `private`:
    /// `AssignmentService.detectStore` (anderer Typ) braucht das für die Fallback-Suche über den
    /// ganzen Bon — verhindert, dass generische MwSt-Tabellen-Vokabeln wie "netto"/"brutto"
    /// fälschlich als Laden-Namens-Treffer zählen (kollidiert konkret mit dem eingebauten
    /// Laden-Preset "Netto", gefunden von einer unabhängigen Verify-Runde, 24.08.2026).
    static func isKnownAdminWord(_ lowercasedWord: String) -> Bool {
        skipWordSet.contains(lowercasedWord)
    }

    private static func isAdminLine(_ lower: String, ignoring exemptWords: Set<String> = []) -> Bool {
        for phrase in skipPhrases where lower.contains(phrase) { return true }
        if let rx = vatSummaryRowRegex, rx.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
            return true
        }
        // Tokenizing auch an "." und "/" — fängt "TOT.GENERAL" und "S/TOTAL"
        // als Whole-Word-Treffer ("tot" bzw. "total").
        return adminWords(lower).contains(where: { skipWordSet.contains($0) && !exemptWords.contains($0) })
    }

    private static func adminWords(_ lower: String) -> [String] {
        lower.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "./")))
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
    }

    // Zusätzliche, von "zahlen" unabhängige Auslöser für `pastItemSection` (siehe Deklaration in
    // `parseClassic`). Falls Vision "zu zahlen" auf einem echten Foto (Unschärfe, Schatten,
    // Blendung) NICHT liest, blieb der Cutoff bisher komplett aus: der gesamte
    // Zahlungs-/Metadaten-Bereich, INSBESONDERE MwSt-Tabellen-DATENZEILEN im Format "A  7 %
    // 1,92  27,46  29,38" (enthalten kein Wort aus `skipWordSet`, siehe `vatSummaryRowRegex`
    // oben — die deckt nur das "Buchstabe/Ziffer="-Format ab, nicht dieses) wurden als
    // Positions-Kandidaten durchgereicht (gemeldet 24.08.2026: vier Phantom-Positionen aus genau
    // dieser Tabelle + Bon-Summe). "mwst" ist bereits ein admin-Wort (filtert seine EIGENE
    // Zeile), schützt bisher aber keine FOLGEZEILEN — als zusätzlicher Cutoff-Auslöser tut es das
    // jetzt auch, ebenso zwei weitere, ausschließlich in der Zahlungs-Metadaten-Sektion
    // vorkommende Begriffe. Jede Phrase hier ist auf einem echten Bon praktisch nie Teil eines
    // Artikelnamens — Whole-Word-Vergleich wie bei `skipWordSet`, keine neue Fehltreffer-Fläche.
    private static let additionalPastItemsTriggerWords: Set<String> = [
        "mwst", "transaktionsnummer", "signaturzähler",
    ]

    private static func triggersPastItemSection(_ lower: String) -> Bool {
        let words = adminWords(lower)
        return words.contains("zahlen") || words.contains(where: additionalPastItemsTriggerWords.contains)
    }

    // Führende Artikelnummern (5+ Ziffern)
    private static let articleNumberRegex = try? NSRegularExpression(pattern: #"^\d{5,}\s+"#)
    // Anhängende MwSt-/Zeilentyp-Kennbuchstaben (A B 1 2 * E am Zeilenende) — "M" kam dazu, weil
    // Lidl die Pfand-Zeile eigens damit kennzeichnet ("Pfand 0,25 M", eigener Code statt echter
    // MwSt-Kategorie): ohne "M" in dieser Klasse matchte KEINE der Preis-Regexes in dieser Datei
    // (alle 6 Stellen mit `[AB...]` unten verwenden dieselbe Zeichenklasse) die Pfand-Zeile, der
    // Pfand-Merge-Zweig griff dadurch nie — die Zeile fiel weiter auf den generischen Admin-Skip
    // zurück, exakt der ursprüngliche Bug blieb bestehen.
    private static let vatSuffixRegex = try? NSRegularExpression(pattern: #"\s+[ABM12E\*]\s*$"#)

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

    private static func isBareQuantityOrWeightConfirmationLine(_ rawLine: String) -> Bool {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        return line.range(
            of: #"^-?\d+([,\.]\d+)?\s*(Stk|St|kg|g)?\s*[x×]\s*-?\d{1,4}[,\.]\d{2}"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static func parse(_ rawLines: [String]) -> [ReceiptLine] {
        let lines = rawLines.map(repairSplitDecimals)
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

    /// Der auf dem Bon selbst aufgedruckte Gesamtbetrag ("zu zahlen"-Zeile), unabhängig vom
    /// eigentlichen Positions-Parsing — NICHT Teil der erkannten Positionen, nur als Vergleichswert
    /// für einen "Summe stimmt nicht"-Hinweis in der Review-Ansicht gedacht (siehe
    /// `ReceiptScannerView`). Ein einzelner Artikel, dessen NAME von Vision gar nicht erst erkannt
    /// wurde (beobachteter Fall: eine Position fehlt komplett, nur ihr Preis taucht als
    /// namenlose Zeile auf und wird beim Parsing mangels Namen verworfen), lässt sich dadurch
    /// zumindest sichtbar machen, statt spurlos in der Summe zu fehlen. Bewusst nur für den
    /// deutschen Pfad — für französische Bons liefert das absichtlich `nil` (kein Hinweis, kein
    /// falscher).
    ///
    /// Mehrere Auslöser-Wörter, nicht nur "zahlen" (Trigger-Wort von `pastItemSection` oben):
    /// "Kreditkarte"/"EC-Karte"/"Betrag" tragen auf einem deutschen Bon denselben Gesamtbetrag
    /// wie die "zu zahlen"-Zeile (Zahlungsbestätigung), stehen aber auf eigenen, unabhängigen
    /// Zeilen — falls Vision ausgerechnet "zu zahlen" nicht liest (derselbe Foto-OCR-Fehler,
    /// gegen den `pastItemSection` gehärtet wurde, siehe dort), bleibt so noch eine zweite und
    /// dritte Chance, den echten Betrag zu finden, statt den "Summe stimmt nicht"-Hinweis
    /// stillschweigend ausfallen zu lassen (gefunden von einer unabhängigen Verify-Runde,
    /// 24.08.2026 — `pastItemSection` wurde gehärtet, diese Funktion aber vergessen). Prüft bei
    /// einem Treffer-Wort ohne extrahierbaren Preis weiter mit der nächsten Kandidaten-Zeile,
    /// statt sofort mit `nil` aufzugeben.
    private static let detectedTotalTriggerWords: Set<String> = ["zahlen", "kreditkarte", "ec-karte", "betrag"]

    static func detectedTotal(from rawLines: [String]) -> Double? {
        let lines = rawLines.map(repairSplitDecimals)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard adminWords(trimmed.lowercased()).contains(where: detectedTotalTriggerWords.contains) else { continue }
            // "Betrag  35,87 EUR" (Kartenzahlungs-Beleg) hängt die Währung als volles Wort an,
            // nicht als einzelnes MwSt-Kürzel wie "A"/"B"/"M" — extractTrailingPrice erlaubt am
            // Zeilenende nur EIN optionales Kürzel-Zeichen, kein 3-Buchstaben-Wort, und würde
            // sonst nichts finden. Deshalb vorher entfernen.
            let withoutCurrencyWord = trimmed.replacingOccurrences(
                of: #"\s*(EUR|eur)\s*$"#, with: "", options: .regularExpression)
            if let total = extractTrailingPrice(from: withoutCurrencyWord) { return total }
        }
        return nil
    }

    /// Vision zerlegt eine Kommazahl auf manchen Bon-Fotos in zwei Textblöcke, die
    /// `reconstructLines` mit doppeltem Leerzeichen wieder zusammenfügt — das bricht jedes
    /// nachfolgende Preis-Regex, das eine zusammenhängende Zahl erwartet. Beobachtete Varianten:
    /// "2,  49" (Trennzeichen im ersten Block) und "2.  ,29" (Trennzeichen im ZWEITEN Block, mit
    /// OCR-Verwechslung Punkt/Komma) — in BEIDEN Fällen steht ein Trennzeichen an mindestens
    /// einer Seite der Lücke. Genau das wird hier verlangt (mind. eine Seite, nicht zwingend
    /// beide): ein Trennzeichen auf KEINER Seite (z. B. "1  49") wird bewusst NICHT repariert,
    /// weil sich das nicht zuverlässig von zwei echten, unabhängigen mehrspaltigen Zahlen
    /// unterscheiden lässt (beobachtet an einer MwSt-Tabellenzeile mit drei echten Einzelzahlen
    /// wie "14,80  15,84" — ein zu freizügiges Muster hätte die fälschlich zusammengezogen).
    /// Baut die Zahl mit einem einheitlichen Komma wieder zusammen; welches Trennzeichen
    /// ursprünglich gemeint war, ist für die nachgelagerten Preis-Regexe ohnehin egal (die
    /// akzeptieren beide, siehe `[,\.]`-Muster).
    private static func repairSplitDecimals(_ line: String) -> String {
        guard let rx = try? NSRegularExpression(pattern: #"(\d)(?:[,\.]\s{2,}[,\.]?|\s{2,}[,\.])(\d{2})\b"#) else { return line }
        let range = NSRange(line.startIndex..., in: line)
        return rx.stringByReplacingMatches(in: line, range: range, withTemplate: "$1,$2")
    }

    /// PATCH Iteration 3: klassischer deutscher Positions-Kandidat — Spaltenform mit
    /// Preis + PFLICHT-MwSt-Kürzel ("EMMENTALER  2,19 A"). Überwiegen diese Zeilen,
    /// bleibt der Bon im klassischen Pfad, auch wenn €-Fußzeilen auftauchen.
    private static func isClassicVatItemCandidate(_ rawLine: String) -> Bool {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard line.count >= 3, !isAdminLine(line.lowercased()) else { return false }
        return line.range(of: #"^.+?\s{2,}-?\d{1,4}[,\.]\d{2}\s*[ABM12E\*]\s*$"#,
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

    /// Entfernt die zuletzt erfasste Position mit einem zu `rawName` fuzzy-passenden Namen aus
    /// `results` (dieselbe Substring-Heuristik wie an den anderen Fuzzy-Match-Stellen im Projekt,
    /// z. B. `ShoppingItem.init`) — genutzt, um eine per "ZEILENSTORNO" stornierte Position
    /// wieder zu entfernen. `lastIndex` statt `firstIndex`, weil bei mehreren gleichnamigen
    /// Positionen (z. B. zwei identische Artikel nacheinander gekauft) die STORNO-Zeile die
    /// zuletzt hinzugefügte meint, nicht zwangsläufig die allererste.
    private static func removingMostRecentMatch(named rawName: String, from results: inout [ReceiptLine]) {
        let target = rawName.lowercased()
        guard target.count >= 3 else { return }
        if let idx = results.lastIndex(where: { line in
            let ln = line.name.lowercased()
            return ln.count >= 3 && (ln.contains(target) || target.contains(ln))
        }) {
            results.remove(at: idx)
        }
    }

    // MARK: - Klassisches Format (deutsche Bons: "EMMENTALER   2,19 A")

    private static func parseClassic(_ lines: [String]) -> [ReceiptLine] {
        // Bevorzugt: Name + 2+ Leerzeichen + Preis (+ opt. MwSt-Kürzel)
        guard let tightRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s{2,}(-?\d{1,4}[,\.]\d{2})\s*[ABM12E\*]?\s*$"#
        ) else { return [] }
        // Fallback: 1 Leerzeichen vor Preis
        guard let looseRegex = try? NSRegularExpression(
            pattern: #"^(.+?)\s+(-?\d{1,4}[,\.]\d{2})\s*[ABM12E\*]?\s*$"#
        ) else { return [] }
        // Nur-Preis-Zeile (für gewichtsbasierte Artikel)
        guard let priceOnlyRegex = try? NSRegularExpression(
            pattern: #"^(-?\d{1,4}[,\.]\d{2})\s*[ABM12E\*]?\s*$"#
        ) else { return [] }

        var results: [ReceiptLine] = []
        var pendingName: String? = nil
        // Gegenstück zu pendingName für den umgekehrten Fall (beobachtet bei Gewichtsartikeln
        // auf manchen Bons): eine reine Preiszeile OHNE vorherigen Namen steht VOR statt NACH
        // der Name+Gewicht-Zeile. Wird nur gesetzt, wenn eine Zeile WIRKLICH nur ein Preis ist
        // (siehe unten) — verhindert, dass so eine Zeile stattdessen fälschlich als pendingName
        // (Artikel-"Name") missbraucht wird, was den nächsten echten Preis komplett falsch
        // zuordnen würde (beobachtet: eine isolierte Gewichtsartikel-Preiszeile wie "0,75 A"
        // wurde so zum Pseudo-Namen für den Preis einer GANZ ANDEREN, folgenden Position).
        var pendingPrice: Double? = nil
        // Wird wahr, sobald die "zu zahlen"-Zeile (oder einer der weiteren Auslöser in
        // `triggersPastItemSection`, siehe dort) erreicht ist — ab da folgt auf deutschen Bons
        // nur noch Zahlungs-Metadaten (TSE-Transaktionsnummer, Seriennr., Autorisierungscode,
        // "GEN.NR", MwSt-Tabelle, …), die sonst einzeln per Schlüsselwort erkannt werden müssten
        // und sonst als Produktzeile durchrutschen (z. B. "00 GEN.NR: 54  13,03" wurde als
        // Artikel erkannt, ebenso MwSt-Tabellen-Datenzeilen ohne "="-Kennung). Alle Auslöser
        // bewusst nur deutsche Begriffe (nicht z. B. "montant"/"total" für französische Bons) —
        // "montant" steht dort in der SPALTEN-KOPFZEILE ganz oben ("MONTANT TTC"), ein Abbruch
        // darauf würde den kompletten Rest jedes französischen Bons verschlucken.
        var pastItemSection = false
        // Wird wahr bei einer "ZEILENSTORNO"/"STORNO"-Zeile (Kassierer storniert die zuletzt
        // gescannte Position, meist gefolgt von derselben Position noch einmal mit negativem
        // Vorzeichen — beobachtet auf einem echten DM-Bon: ein falscher CO2-Zylinder wurde
        // storniert und durch den richtigen ersetzt). Ohne Sonderbehandlung bleibt die
        // ursprüngliche (falsche/stornierte) Position in `results` stehen, während die
        // stornierende Negativ-Zeile weiter unten am `price > 0.05`-Positivitäts-Check scheitert
        // und einfach spurlos verworfen wird — der stornierte Artikel erscheint dann fälschlich
        // als gekauft, OHNE dass die Korrektur je zum Zuge kommt.
        var pendingStornoCancel = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { pendingName = nil; pendingPrice = nil; continue }

            let lower = trimmed.lowercased()

            if pastItemSection { continue }
            if triggersPastItemSection(lower) {
                pastItemSection = true
                continue
            }
            if lower.contains("storno") {
                pendingStornoCancel = true
                pendingName = nil; pendingPrice = nil
                continue
            }

            // Manche Bons (z. B. Rewes digitaler eBon) drucken den vollen Gesamtpreis DIREKT auf der
            // Namenszeile UND zusätzlich eine Mengen-/Gewichts-Bestätigungszeile direkt darunter
            // ("4 Stk x 0,39", "0,706 kg x 2,49 EUR/kg") — bei Lidl trägt die Namenszeile dagegen NUR
            // den bloßen Namen, der Gesamtpreis wird erst weiter unten AUS genau so einer Zeile
            // berechnet (siehe `weightTimesRate` im " x "-Zweig darunter). Ohne diese Behandlung
            // würde eine reine Bestätigungszeile als eigenständige Phantom-Position mit
            // unsinnigem/leerem Namen erkannt (beobachtet: "4 Stk x 0,39" wurde selbst zu einer
            // "Position", Name "Stk x 0,39").
            //
            // Nur hier greifen, wenn KEIN Name/Preis mehr offen ist — die VORHERIGE Zeile war dann
            // bereits für sich allein eine vollständige Position (Name + Preis, steht schon in
            // `results`). Bleibt die vorherige Zeile ein bloßer Name ohne Preis (Lidl-Fall,
            // `pendingName != nil`) oder eine reine Preiszeile (`pendingPrice != nil`), läuft die
            // Zeile wie bisher in den " x "-Zweig: dort ist sie die einzige Preisquelle.
            //
            // Die Zeile wird IMMER konsumiert (nie eigene Position, Issue #9). Stückzahl bzw.
            // Gewicht werden der Vorposition nur dann zugeschrieben, wenn die Rechenprobe
            // Menge × Rate ≈ Zeilenpreis aufgeht (Toleranz 0,01 wegen Bon-Rundung: 0,706 × 2,49 =
            // 1,75794, gedruckt 1,76) — andernfalls (OCR-Zahlendreher) wird nichts übernommen.
            // Der bereits korrekte Preis der Vorposition bleibt in jedem Fall unangetastet.
            if pendingName == nil, pendingPrice == nil, !pendingStornoCancel,
               isBareQuantityOrWeightConfirmationLine(trimmed) {
                if let last = results.last, let wr = weightTimesRate(in: trimmed),
                   abs(wr.weight * wr.rate - last.price) <= 0.01 {
                    if wr.unit == "kg" {
                        results[results.count - 1].weightBasis = wr.weight * 1000
                    } else if wr.unit == "stk" {
                        results[results.count - 1].quantity = wr.weight
                    }
                }
                continue
            }

            // Dieselbe Bestätigungszeile DIREKT nach einer STORNO-Zeile ("STORNO", "-4 Stk x 0,39"):
            // der Block oben greift dort wegen `!pendingStornoCancel` nicht, die Zeile fiele sonst in
            // den " x "-Zweig und würde zur Phantom-Position mit dem Zeilentext als Namen (Issue #24).
            // `pendingStornoCancel` bleibt bewusst stehen — die eigentliche Storno-Verrechnung soll
            // erst beim nächsten Namens-/Preis-Zeilenpaar greifen, diese Zeile verbraucht sie nicht.
            if pendingStornoCancel, isBareQuantityOrWeightConfirmationLine(trimmed) {
                continue
            }

            // Gewichts-/Multiplikatorzeilen ("0,436 kg x 12,49", "…  0,584 kg x 1,29  EUR/Kg")
            // MÜSSEN vor dem allgemeinen Admin-Filter geprüft werden: die Mengeneinheit "EUR/Kg"
            // enthält "eur" (Admin-Schlüsselwort) und würde sonst JEDE Gewichtszeile — und damit
            // jeden gewogenen Artikel (Obst, Gemüse, Frischetheke) — komplett verschlucken, bevor
            // die eigentliche Gewichts-Erkennung unten überhaupt zum Zug kommt. Trotzdem NICHT
            // blind vor den Admin-Filter gezogen: eine wirklich administrative Zeile, die zufällig
            // auch " x "/"/kg" enthält (z. B. "Pfand 3 x -0,75"), soll weiter normal gefiltert
            // werden — daher hier nur "eur"/"euro" als alleinigen Admin-Grund ignorieren (die
            // Mengeneinheit), jeden ANDEREN Admin-Treffer (pfand, summe, …) weiter ernst nehmen.
            if (lower.contains(" x ") || lower.contains(" × ") || lower.contains("/kg") || lower.contains("/stk"))
                && !isAdminLine(lower, ignoring: ["eur", "euro"]) {
                // Preis bevorzugt aus dieser Zeile selbst, sonst aus einer vorherigen reinen
                // Preiszeile (umgekehrte Reihenfolge, siehe pendingPrice oben).
                var price = extractTrailingPrice(from: trimmed) ?? pendingPrice
                var quantity: Double = 1
                var weightBasis: Double? = nil
                // Manche Bons drucken auf dieser Zeile NUR Gewicht/Stückzahl × Grundpreis-Rate,
                // ohne separaten Gesamtpreis ("0,436 kg x 12,49" — Beispiel oben im Kommentar).
                // Dann liest extractTrailingPrice (mangels anderer Zahl) die RATE selbst statt
                // eines Gesamtpreises — erkennbar daran, dass der oben ermittelte "Preis" exakt
                // der Rate entspricht (oder gar keiner gefunden wurde). In dem Fall durch den
                // tatsächlichen, mathematisch korrekten Gesamtpreis (Gewicht × Rate) ersetzen,
                // statt die Rate fälschlich als Gesamtpreis zu übernehmen — Ursache eines Bugs,
                // bei dem gewogene Artikel (z. B. "Skyr 500g" bei 2,29 €/kg) mit dem 1000-fachen
                // Preis (1145,00 € statt 1,15 €) auf der Liste landeten. Greift NICHT, wenn oben
                // bereits ein echter, eigenständiger Gesamtpreis gefunden wurde (z. B. über
                // pendingPrice aus einer vorherigen reinen Preiszeile) — der ist verlässlicher als
                // eine Neuberechnung.
                if let match = weightTimesRate(in: trimmed),
                   price == nil || price.map({ abs($0 - match.rate) < 0.005 }) == true {
                    price = (match.weight * match.rate * 100).rounded() / 100
                    switch match.unit {
                    case "kg":
                        // Gramm-Basis, damit der Divisor direkt zu `quantityAmount`/`unit == "g"`
                        // auf `ShoppingItem` passt (siehe `weightBasis`-Doc oben) — unabhängig
                        // davon, ob beim Preis-Lernen später ein historischer Match existiert.
                        weightBasis = match.weight * 1000
                    case "stk":
                        // Echte Stückzahl — anders als bei "kg" hier direkt `quantity` selbst
                        // setzen: das ist zugleich der korrekte Wert für die "N St."-Anzeige
                        // in der Review-UI (ReceiptReviewCard.priceSummary), keine Sonderrolle nötig.
                        quantity = match.weight
                    default:
                        break
                    }
                } else if let bare = priceTimesCount(in: trimmed), let currentPrice = price,
                          abs(currentPrice - bare.unitPrice * bare.count) <= 0.05 {
                    // Lidl-Mehrfachkauf OHNE Einheiten-Wort ("BürgerSchwä.Maultas.  2,29 x  3
                    // 6,87 A" — Stückpreis × Anzahl, der Gesamtpreis 6,87 steht bereits als
                    // Trailing-Preis auf derselben Zeile fest). `weightTimesRate` oben griff hier
                    // nie (die verlangt zwingend "kg"/"stk" zwischen den Zahlen), `quantity` blieb
                    // dadurch beim Default 1 — der volle Zeilen-Gesamtpreis wurde beim Speichern
                    // (`ReceiptScannerView.save()`s `perUnitPrice = line.price / quantity`)
                    // fälschlich als Stückpreis gelernt statt durch die echte Anzahl geteilt
                    // (gemeldet 24.08.2026: "3 Packungen Maultaschen à 2,29€ lernen 6,87€ pro
                    // Packung"). Sanity-Check gegen den bereits extrahierten Gesamtpreis (wie
                    // `euroQtyRegex` in `parseEuroSuffixStyle`) — nur übernehmen, wenn Menge ×
                    // Stückpreis wirklich zum Zeilenpreis passt.
                    quantity = bare.count
                }
                // Name bevorzugt aus einer vorherigen Namenszeile; fehlt die, aus dem Teil DIESER
                // Zeile vor dem Gewichts-Muster (manche Bons drucken Name und Gewichtsdetail auf
                // derselben rekonstruierten Zeile).
                let name = pendingName ?? nameChunkBeforeWeightDetail(trimmed)
                if let name, let price {
                    results.append(ReceiptLine(name: name, price: price, quantity: quantity, weightBasis: weightBasis))
                }
                pendingName = nil
                pendingPrice = nil
                continue
            }
            // Pfand-Zeile ("Pfand 0,25 M") gehört zur VORHERIGEN Position (Flaschen-/Dosenpfand) —
            // statt sie wie jede andere Admin-Zeile zu verwerfen (bisheriges Verhalten: der Betrag
            // verschwand einfach spurlos), zum letzten erkannten Preis addieren.
            if adminWords(lower).contains("pfand"), !results.isEmpty,
               let pfandPrice = extractTrailingPrice(from: trimmed) {
                // extractTrailingPrice liefert nur die Ziffern, ein führendes "-" (Pfand-Rückgabe/
                // Leergut-Erstattung, siehe Beispiel "Pfand 3 x -0,75" im Kommentar weiter oben)
                // geht dabei verloren — hier separat erkennen, sonst würde eine Rückerstattung
                // fälschlich zum vorherigen Preis ADDIERT statt abgezogen.
                let isRefund = hasNegativeTrailingAmount(trimmed)
                results[results.count - 1].price += isRefund ? -pfandPrice : pfandPrice
                pendingName = nil; pendingPrice = nil
                continue
            }
            // Administrative Zeilen überspringen
            if isAdminLine(lower) {
                pendingName = nil; pendingPrice = nil; continue
            }
            // Reine Zahlenzeilen (EAN, Artikelnr.) überspringen
            if trimmed.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) {
                pendingName = nil; pendingPrice = nil; continue
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
                        pendingPrice = nil
                        continue
                    }
                }
                pendingName = nil
                pendingPrice = nil
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

                // Allow names starting with numbers ("2er Pack", "3M") —
                // only reject names that are entirely digits/spaces (article codes).
                guard rawName.count >= 2,
                      !rawName.allSatisfy({ $0.isNumber || $0 == " " })
                else { continue }

                // Stornierende Zeile: unabhängig von IHREM Preis (Vorzeichen/Wert je nach
                // Kassensystem unterschiedlich) die zuletzt erfasste Position mit demselben Namen
                // wieder entfernen, statt eine neue (und garantiert falsche) Position daraus zu
                // machen. Siehe `pendingStornoCancel`-Deklaration oben für den beobachteten Fall.
                if pendingStornoCancel {
                    pendingStornoCancel = false
                    removingMostRecentMatch(named: rawName, from: &results)
                    pendingName = nil
                    pendingPrice = nil
                    continue
                }

                let rawPrice = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: ".")
                guard let price = Double(rawPrice), price > 0.05, price < 999 else { continue }

                results.append(ReceiptLine(name: smartCapitalize(rawName), price: price))
                pendingName = nil
                pendingPrice = nil

            } else if let priceMatch = priceOnlyRegex.firstMatch(in: trimmed, range: nsRange),
                      let priceRange = Range(priceMatch.range(at: 1), in: trimmed) {
                // Storno-Zeile ohne erkennbaren Namen (z. B. wenn die Rekonstruktion Name und
                // Preis auf getrennte Zeilen aufteilt) — die letzte erfasste Position ist die
                // einzig sinnvolle Kandidatin zum Entfernen, da Stornos immer unmittelbar auf
                // die zu korrigierende Position folgen.
                if pendingStornoCancel {
                    pendingStornoCancel = false
                    if !results.isEmpty { results.removeLast() }
                    pendingName = nil
                    pendingPrice = nil
                    continue
                }
                // Zeile besteht nur aus einem Preis (+ optionalem MwSt-Kürzel) — als pendingPrice
                // merken (siehe Gewichtszeilen-Zweig oben), NICHT als möglichen Produktnamen
                // behandeln (der `hasLetters`-Zweig unten würde sonst z. B. "0,75 A" wegen des
                // MwSt-Buchstabens fälschlich als Name durchlassen).
                let raw = String(trimmed[priceRange]).replacingOccurrences(of: ",", with: ".")
                pendingPrice = Double(raw)
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
                        // Eine evtl. noch offene pendingPrice aus einer früheren, nie verbrauchten
                        // Preiszeile darf nicht über diese neue Namenszeile hinweg an eine spätere,
                        // unabhängige Gewichtszeile "durchsickern" — pendingName/pendingPrice
                        // repräsentieren zwei alternative, sich gegenseitig ausschließende
                        // Bridging-Zustände, nie beide gleichzeitig.
                        pendingPrice = nil
                    }
                }
            }
        }

        return dedupAndSort(droppingLeakedTotal(results))
    }

    // Ein einzelnes Fremdzeichen + Leerzeichen ganz am Anfang, gefolgt von einem echten
    // (buchstaben-startenden) Namen — Vision liest das Aufzählungssymbol vor jeder Bon-Position
    // (Punkt/Häkchen-Icon) manchmal als eigenständiges Zeichen ("1 Handelkerne", "I Barane lose").
    private static let strayBulletPrefixRegex = try? NSRegularExpression(pattern: #"^\S\s+(?=[A-Za-zÀ-ÿ])"#)

    /// Extrahiert den Namens-Teil einer rekonstruierten Zeile, die Artikelname UND
    /// Gewichtsdetail gemeinsam enthält ("Banane lose  0,584 kg x 1,29  EUR/Kg") — der erste
    /// per Doppelleerzeichen abgetrennte Teil, der (nach Abstreifen eines evtl. angehängten
    /// Aufzählungs-Fremdzeichens) nicht mit einer Ziffer beginnt. Nur als Fallback genutzt, wenn
    /// keine separate vorherige Namenszeile (pendingName) vorliegt.
    private static func nameChunkBeforeWeightDetail(_ line: String) -> String? {
        let chunks = line.components(separatedBy: "  ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard var first = chunks.first else { return nil }
        if let rx = strayBulletPrefixRegex {
            let range = NSRange(first.startIndex..., in: first)
            if let match = rx.firstMatch(in: first, range: range), match.range.location == 0,
               let matchRange = Range(match.range, in: first) {
                first = String(first[matchRange.upperBound...])
            }
        }
        guard let firstChar = first.first, !firstChar.isNumber else { return nil }
        return smartCapitalize(first)
    }

    /// Bei sehr engem Zeilenabstand kann der Bon-Gesamtbetrag an die letzte echte Artikelzeile
    /// "andocken" (deren eigener Preis geht dabei verloren) — beobachtet z. B. bei "Vollkorn
    /// Toast" direkt vor der "zu zahlen"-Zeile. Sehr sicheres Erkennungsmerkmal: der Preis der
    /// letzten Zeile entspricht (fast) exakt der Summe aller vorherigen — dass ein echter
    /// Einzelposten zufällig genau der Summe aller anderen entspricht, ist praktisch
    /// ausgeschlossen.
    private static func droppingLeakedTotal(_ results: [ReceiptLine]) -> [ReceiptLine] {
        guard results.count >= 2, let last = results.last else { return results }
        let othersSum = results.dropLast().reduce(0.0) { $0 + $1.price }
        guard othersSum > 0, abs(last.price - othersSum) < 0.01 else { return results }
        return Array(results.dropLast())
    }

    /// Duplikate entfernen (letzter Preis gewinnt bei gleichem Namen), dann alphabetisch sortiert.
    private static func dedupAndSort(_ results: [ReceiptLine]) -> [ReceiptLine] {
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
            let lineLower = line.lowercased()
            // "Consigne" (frz. Pfand) gehört zur VORHERIGEN Position, analog zu "Pfand" im
            // klassischen Pfad — statt den Betrag wie jede andere Admin-Zeile spurlos zu verwerfen.
            if adminWords(lineLower).contains("consigne"), !results.isEmpty,
               let consignePrice = extractTrailingEuroPrice(from: line) {
                // Gleiches Vorzeichen-Problem wie beim deutschen Pfand-Pfad (siehe dortiger
                // Kommentar): extractTrailingEuroPrice verliert ein führendes "-".
                let isRefund = hasNegativeTrailingAmount(line)
                results[results.count - 1].price += isRefund ? -consignePrice : consignePrice
                pendingName = nil
                continue
            }
            if isAdminLine(lineLower) { pendingName = nil; continue }

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

        return dedupAndSort(droppingLeakedTotal(results))
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

    // Erkennt "0,436 kg x 12,49" / "0,500 kg x 2,29 EUR/Kg" / "3 Stk x 0,79 EUR/Stk" — Gewicht
    // bzw. Stückzahl × Grundpreis-Rate — irgendwo in der Zeile (nicht zeilenend-verankert, im
    // Gegensatz zu extractTrailingPrice), damit auch ein nachfolgender "EUR/Kg"-Textrest die
    // Erkennung nicht blockiert. Die Einheit (Gruppe 2) wird mit zurückgegeben, weil "kg" und
    // "stk" beim Aufrufer unterschiedlich behandelt werden (Gewichts-Divisor vs. echte Stückzahl).
    private static let weightTimesRateRegex = try? NSRegularExpression(
        pattern: #"(\d{1,3}(?:[,\.]\d{1,3})?)\s*(kg|stk)\s*[x×]\s*(\d{1,4}[,\.]\d{2})"#,
        options: [.caseInsensitive]
    )

    private static let sizeInNameRegex = try? NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|dl|l)\b"#,
        options: [.caseInsensitive]
    )

    /// Extrahiert eine im Produktnamen selbst gedruckte Füllmenge (z. B. "SKYR NATUR 500G" → 500,
    /// "Cola 1,5l" → 1500) — Fallback-Quelle für `EditableReceiptLine.learningQuantity`, wenn KEINE
    /// separate Gewichts-/Mengenzeile existiert (siehe `weightBasis`-Doc oben: die deckt nur
    /// gewogene Frischware mit eigener "0,500 kg x 2,29"-Zeile ab). Ein abgepacktes Produkt mit
    /// festem Gesamtpreis (z. B. ein Skyr-Becher, Bon-Zeile nur "SKYR NATUR 500G   2,29", ohne
    /// "x"/"kg"-Rechenzeile) hatte dadurch bisher KEINEN Divisor — `learningQuantity` fiel auf 1
    /// zurück und lernte den vollen Zeilenpreis (2,29€) als vermeintlichen PRO-GRAMM-Preis. Bei
    /// späterer Artikel-Anlage mit `quantityAmount: 500, unit: "g"` (z. B. über `QuickAddParser`)
    /// ergab das 2,29 × 500 = 1145€ (`ShoppingItem.estimatedLineTotal`) — der wiederholt gemeldete
    /// "Skyr-Bug". Sucht bewusst den LETZTEN Treffer im Namen (Größenangabe steht typischerweise am
    /// Ende), damit eine zufällige führende Ziffernfolge (Artikelnummer) nicht fälschlich matcht.
    /// Normiert auf dieselbe Gramm-/Milliliter-Basis wie der `weightTimesRate`-Zweig oben (kg/l ×
    /// 1000, cl × 10, dl × 100), damit der Divisor zur später angelegten `ShoppingItem.unit`
    /// ("g"/"ml") passt.
    static func weightBasisFromName(_ name: String) -> Double? {
        guard let rx = sizeInNameRegex else { return nil }
        let range = NSRange(name.startIndex..., in: name)
        guard let match = rx.matches(in: name, range: range).last,
              let amountRange = Range(match.range(at: 1), in: name),
              let unitRange = Range(match.range(at: 2), in: name),
              let amount = Double(name[amountRange].replacingOccurrences(of: ",", with: ".")),
              amount > 0
        else { return nil }
        switch name[unitRange].lowercased() {
        case "kg", "l": return amount * 1000
        case "cl": return amount * 10
        case "dl": return amount * 100
        default: return amount // g, ml
        }
    }

    private static func weightTimesRate(in line: String) -> (weight: Double, unit: String, rate: Double)? {
        guard let rx = weightTimesRateRegex,
              let match = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let weightRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let rateRange = Range(match.range(at: 3), in: line),
              let weight = Double(line[weightRange].replacingOccurrences(of: ",", with: ".")),
              let rate = Double(line[rateRange].replacingOccurrences(of: ",", with: ".")),
              weight > 0, rate > 0
        else { return nil }
        return (weight, line[unitRange].lowercased(), rate)
    }

    // Erkennt "2,29 x 3" / "0,39 x  2" — Stückpreis × Anzahl OHNE Einheiten-Wort dazwischen
    // (Lidl-Mehrfachkauf-Format). Bewusst getrennt von `weightTimesRateRegex`: dort steht IMMER
    // ein Einheiten-Wort ("kg"/"stk") zwischen den beiden Zahlen — hier nie; die Abwesenheit
    // eines Einheiten-Worts ist gerade das Unterscheidungsmerkmal. `count` mindestens 2 (wie
    // `euroQtyRegex` in `parseEuroSuffixStyle`): eine Zeile "x 1" auf einem echten Bon kommt
    // praktisch nicht vor und wäre kein sinnvoller Mehrfachkauf-Hinweis. Negative Lookahead
    // verhindert einen Teiltreffer auf eine längere Zahl (z. B. "35" oder "3,50") direkt nach der
    // vermeintlichen Anzahl.
    private static let priceTimesCountRegex = try? NSRegularExpression(
        pattern: #"(\d{1,4}[,\.]\d{2})\s*[x×]\s*(\d{1,2})(?![\d,\.])"#
    )

    private static func priceTimesCount(in line: String) -> (unitPrice: Double, count: Double)? {
        guard let rx = priceTimesCountRegex,
              let match = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let priceRange = Range(match.range(at: 1), in: line),
              let countRange = Range(match.range(at: 2), in: line),
              let unitPrice = Double(line[priceRange].replacingOccurrences(of: ",", with: ".")),
              let count = Double(line[countRange]),
              unitPrice > 0, count >= 2, count <= 99
        else { return nil }
        return (unitPrice, count)
    }

    // Preis am Zeilenende extrahieren (für Gewichtszeilen)
    private static func extractTrailingPrice(from line: String) -> Double? {
        let pattern = #"(\d{1,4}[,\.]\d{2})\s*[ABM12E\*]?\s*$"#
        guard let rx = try? NSRegularExpression(pattern: pattern),
              let match = rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        let raw = String(line[range]).replacingOccurrences(of: ",", with: ".")
        let price = Double(raw)
        return (price ?? 0) > 0.05 ? price : nil
    }

    // Prüft, ob dem End-Preis einer Zeile ein Minus-artiges Zeichen UNMITTELBAR vorausgeht (nur
    // Leerraum dazwischen) — genauer als eine simple "enthält die Zeile irgendwo einen
    // Bindestrich"-Prüfung, die z. B. bei einer Artikel-/Belegnummer wie "Art-Nr 4011-8" fälschlich
    // anschlagen würde, obwohl der eigentliche Preis am Ende positiv ist. `\D*$` statt einer der
    // spezifischen Endungs-Zeichenklassen oben, damit dieselbe Prüfung für beide Preisformate
    // (deutsches "M"/"A"/… -Kürzel UND französisches Währungssymbol) funktioniert. Deckt neben dem
    // ASCII-Bindestrich auch die Gedankenstrich-/Minus-Varianten ab, die Vision bei OCR gelegentlich
    // statt eines echten Minus liefert (vgl. die x/х-Behandlung weiter oben in dieser Datei).
    private static func hasNegativeTrailingAmount(_ line: String) -> Bool {
        let pattern = #"[-–—−]\s*\d{1,4}[,\.]\d{2}\D*$"#
        guard let rx = try? NSRegularExpression(pattern: pattern) else { return false }
        return rx.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
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

    // MARK: - Kürzel-Auflösung (Stufe 2: statisches Wörterbuch)

    /// Bekannte Kassenbon-Kürzel (FR/DE) → volles Wort. Wortweiser Match (nicht Substring), damit
    /// z. B. "past" nicht in "Pastete" hineingreift. Startsatz, bewusst nicht vollständig — wächst
    /// über Zeit; für alles, was hier nicht drinsteht, greifen die nachgelagerten Stufen (Abgleich
    /// mit den gerade abgehakten Artikeln, dann Kaufhistorie-Fuzzy-Match, dann optional Apple
    /// Intelligence, siehe ReceiptScannerView.process()).
    /// Bewusst nur Kürzel, die (fast) nie ein eigenständiges, anders gemeintes Wort sind — z. B.
    /// NICHT "frais" (frisch) → "Fraise" (Erdbeere), das hätte "LAIT FRAIS"/"POISSON FRAIS" verfälscht,
    /// und NICHT "conf" (Confit vs. Confiture nicht eindeutig unterscheidbar). Eine falsche Stufe-2-
    /// Zuordnung ist final (überschreibt keine spätere Stufe), daher lieber ein Kürzel weniger als
    /// eines, das im Zweifel auf ein häufiges, harmloses Wort zugreift.
    private static let abbreviationExpansions: [String: String] = [
        // Französische Kassenbon-Kürzel
        "shak": "Shaker", "sach": "Sachet", "past": "Pâtes",
        "choc": "Chocolat", "framb": "Framboise", "yaou": "Yaourt",
        "legu": "Légumes", "surg": "Surgelé", "marg": "Margarine", "beurr": "Beurre",
        "fromag": "Fromage", "biscu": "Biscuit",
        // Deutsche Kassenbon-Kürzel
        "jogh": "Joghurt", "btr": "Butter", "kaffe": "Kaffee", "schok": "Schokolade",
        "geb": "Gebäck", "tk": "Tiefkühl",
        // dm-/Drogerie-Kürzel (reales Beispiel, gemeldet 13.08.2026: "Hakle ToiPa Traumweich
        // 8x130Bl" wurde mangels dieses Eintrags an Stufe 5 [Apple Intelligence] durchgereicht,
        // die es fälschlich zu "Flaschenbürste" statt "Toilettenpapier" "expandierte" — ein
        // deterministischer Wörterbuch-Treffer hier schaltet die unzuverlässige KI-Stufe für
        // diesen sehr verbreiteten Artikel komplett aus, statt sie zu korrigieren.
        "toipa": "Toilettenpapier", "prem": "Premium"
    ]

    /// Mehrwort-Kürzel, die NACH dem Punkt-Split in zwei separate Tokens zerfallen würden und
    /// deshalb über die einfache `abbreviationExpansions`-Wort-für-Wort-Zuordnung nicht lösbar
    /// sind (z. B. "Fl.buerste" → Tokens "Fl" + "buerste", von denen keins für sich allein
    /// eindeutig genug wäre — "Fl" ist ein zu generisches Kürzel für Auto-Übernahme). Wird VOR
    /// dem Punkt-Split als zusammenhängende Phrase (case-insensitive) ersetzt. Reales Beispiel
    /// (13.08.2026, DM-Bon): "babylove Prem. Fl.buerste 1St" — die Flaschenbürste für
    /// Babyflaschen, nicht zu verwechseln mit einer generischen Flasche.
    private static let phraseExpansions: [String: String] = [
        "fl.buerste": "Flaschenbürste", "fl buerste": "Flaschenbürste",
        "fl.bürste": "Flaschenbürste", "fl bürste": "Flaschenbürste",
    ]

    /// Wendet zuerst `phraseExpansions` (Mehrwort-Kürzel, siehe dort), dann `abbreviationExpansions`
    /// wortweise an. Trennt dabei auch an Punkten ohne Leerzeichen ("Shak.Moutarde" wie
    /// "Shak. Moutarde" wie "Shak Moutarde" → gleiche Tokens), da Kassenbons Kürzel-Punkte mal
    /// mit, mal ohne Leerzeichen drucken — ABER nie an einem Punkt zwischen zwei Ziffern
    /// (Dezimalzahl wie "3.5" bleibt unangetastet, sonst würde ein Treffer an anderer Stelle im
    /// Namen sie beim Zusammenfügen in "3 5" zerreißen). Liefert nil, wenn nichts im Wörterbuch
    /// stand, damit der Aufrufer zur nächsten Stufe weiterreicht.
    static func expandAbbreviations(_ name: String) -> String? {
        var working = name
        var matchedAny = false
        for (phrase, full) in phraseExpansions {
            if let range = working.range(of: phrase, options: [.caseInsensitive]) {
                working.replaceSubrange(range, with: full)
                matchedAny = true
            }
        }

        let splittable = working.replacingOccurrences(
            of: #"(?<!\d)\.|\.(?!\d)"#, with: " ", options: .regularExpression)
        let words = splittable.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !words.isEmpty else { return matchedAny ? working : nil }
        let expanded = words.map { word -> String in
            if let full = abbreviationExpansions[word.lowercased()] {
                matchedAny = true
                return full
            }
            return word
        }
        return matchedAny ? expanded.joined(separator: " ") : nil
    }

    // MARK: - Kürzel-Auflösung (Stufe 3: Abgehakte Artikel dieses Einkaufs)

    /// Wie gut `token` (ein OCR-Bon-Text) zu `name` (ein Artikelname) passt — Dice-Koeffizient
    /// über der längsten gemeinsamen Teilsequenz (LCS), nicht reines `contains` wie bei
    /// `historyMatch` unten: reine Substring-Suche findet Kürzungen ("Mozzar" → "Mozzarella"),
    /// aber nicht das andere verbreitete Bon-Kürzel-Muster, bei dem Zeichen mittendrin fehlen
    /// ("Mzzrll" → "Mozzarella") — eine Teilsequenz erfasst beide Fälle gleich gut. Bewusst NICHT
    /// Levenshtein-Distanz: die ist stark bei Zeichen-VERWECHSLUNGEN (OCR liest "0" als "O"), das
    /// eigentliche Problem bei Kassenbons ist aber Kürzung/Auslassung, nicht Verwechslung.
    /// Ehrlich gesagt: ein völlig beliebiger Code ohne jeden Bezug zur Buchstaben-Reihenfolge
    /// (z. B. "MDHSZ" für "Mozzarella") bleibt auch hiermit ein schwacher Score — dafür gibt es
    /// die antippbaren Auswahlzeilen im Review (`ReceiptReviewCard`), nicht eine noch bessere Formel.
    ///
    /// Nicht `private`: `ReceiptScannerView.save()` braucht dieselbe Bewertung auch für die laxe,
    /// namensbasierte Fallback-Suche über ALLE PurchaseRecords (nicht nur die abgehakten Artikel
    /// dieses Stores) — ohne diese Prüfung könnte ein zufälliger Substring-Treffer (z. B. "Milch"
    /// matcht einen bestehenden "Kondensmilch"-Datensatz) einen fremden Artikel verfälschen.
    static func lcsSimilarity(_ a: String, _ b: String) -> Double {
        let aChars = Array(a.lowercased())
        let bChars = Array(b.lowercased())
        guard !aChars.isEmpty, !bChars.isEmpty else { return 0 }
        let lcs = longestCommonSubsequenceLength(aChars, bChars)
        // Ein Teilstring-Bonus ("Red Bull" in "Red Bull White Peach" höher werten) wurde erwogen
        // und wieder verworfen: deutsche Komposita machen "kurzes echtes Wort ist Teilstring eines
        // LÄNGEREN, ANDEREN Produkts" extrem häufig ("Milch" in "Kondensmilch", "Apfel" in
        // "Apfelsaft", "Sahne" in "Schlagsahne") — ein pauschaler Bonus hätte genau die
        // Verwechslungsgefahr verschärft, die er lösen sollte (durch echten Test bestätigt: der
        // Bonus hob "Milch"/"Kondensmilch" von 0,588 auf 0,788 an — über die Auto-Übernahme-
        // Schwelle). Der reine Ratio-Wert unten kann echte Kürzungen (0,57-0,65) ohnehin nicht
        // immer von Komposita-Kollisionen (ebenfalls 0,57-0,71) unterscheiden — ohne echtes
        // Sprachwissen (Kompositazerlegung) ist das mit reiner String-Ähnlichkeit nicht
        // zuverlässig lösbar. Bewusster Kompromiss stattdessen in der Schwelle unten: hoch genug,
        // dass die im echten Bon aufgetretenen Fälle korrekt fallen, auch wenn dadurch ein paar
        // legitime kurze Markennamen (z. B. "Red Bull" als Kürzung von "Red Bull White Peach")
        // auf den Vorschlags-Chip statt Auto-Übernahme zurückfallen — ein falscher Tipp-Vorschlag
        // ist ungefährlicher als eine still falsch umbenannte/gelernte Position.
        return (2.0 * Double(lcs)) / Double(aChars.count + bChars.count)
    }

    private static func longestCommonSubsequenceLength(_ a: [Character], _ b: [Character]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: b.count + 1)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    current[j] = previous[j - 1] + 1
                } else {
                    current[j] = max(previous[j], current[j - 1])
                }
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    /// Automatisch übernehmen, wenn der beste Treffer mindestens diesen Score erreicht.
    /// 0,6 statt (früher) 0,5 — hebt die Schwelle über den konkret beobachteten Fehltreffer
    /// "Bananen"/"Mandeln" (0,571) hinaus, OHNE das Verhältnis selbst zu verändern (siehe
    /// Kommentar in `lcsSimilarity` oben, warum ein Teilstring-Bonus dort verworfen wurde).
    /// Bleibt trotzdem unvollständig: manche echte Komposita-Kollisionen liegen noch darüber
    /// (z. B. "Apfel"/"Apfelsaft" ≈ 0,71) — bekannte, nicht in dieser Runde gelöste Grenze.
    static let completedItemAutoApplyThreshold: Double = 0.6
    /// Trotzdem als antippbaren Vorschlags-Chip anzeigen, auch ohne automatische Übernahme.
    /// 0,45 statt (früher) 0,2 — über den beobachteten Fehltreffern im Bon-Prüf-Screen
    /// ("Fisch"/"Hafersahne" ≈ 0,40, siehe Issue #29), unter der Auto-Übernahme-Schwelle oben
    /// und unter echten Kürzungen (0,57 aufwärts, siehe Kommentar zu `completedItemAutoApplyThreshold`).
    static let completedItemSuggestionFloor: Double = 0.45

    /// Sucht unter den gerade abgehakten Artikeln DIESES Stores nach den plausibelsten Treffern
    /// für `token` (ein OCR-Bon-Text) — stärkeres Signal als `historyMatch`, weil es exakt das
    /// erfasst, was gerade an diesem Store eingekauft wurde, statt irgendeines Kaufs der letzten
    /// 7 Tage. `linePrice` (die Bon-Zeilen-GESAMTsumme) ist ein optionaler kleiner Tie-Breaker
    /// gegen `item.estimatedLineTotal` (ebenfalls ein Gesamtpreis, keine Umrechnung nötig) — hebt
    /// einen bereits plausiblen Text-Match weiter an, rettet aber nie einen schwachen.
    static func completedItemCandidates(
        for token: String,
        in items: [ShoppingItem],
        linePrice: Double? = nil,
        limit: Int = 5
    ) -> [(item: ShoppingItem, score: Double)] {
        guard !items.isEmpty, token.count >= 2 else { return [] }
        let scored: [(item: ShoppingItem, score: Double)] = items.map { item in
            var score = lcsSimilarity(token, item.name)
            if score >= completedItemSuggestionFloor,
               let linePrice, let estimate = item.estimatedLineTotal, estimate > 0 {
                let priceCloseness = 1 - min(abs(linePrice - estimate) / estimate, 1)
                score += 0.1 * priceCloseness
            }
            return (item, score)
        }
        // Nach Name deduplizieren (höchsten Score behalten) — sonst ergeben zwei an
        // unterschiedlichen Tagen abgehakte, gleichnamige Artikel (z. B. zwei "Mandeln"-Käufe)
        // zwei identische Vorschlags-Chips in der UI.
        var bestByName: [String: (item: ShoppingItem, score: Double)] = [:]
        for entry in scored {
            let key = entry.item.name.lowercased()
            if let existing = bestByName[key], existing.score >= entry.score { continue }
            bestByName[key] = entry
        }
        return Array(
            bestByName.values
                .filter { $0.score >= completedItemSuggestionFloor }
                // Namen als zweites Sortierkriterium: `bestByName.values` iteriert in
                // unspezifizierter (pro Prozess zufälliger) Dictionary-Reihenfolge — ohne
                // deterministischen Tie-Breaker könnte die Reihenfolge zweier exakt
                // gleich bewerteter, unterschiedlich benannter Artikel zwischen App-Starts
                // wechseln.
                .sorted { $0.score != $1.score ? $0.score > $1.score : $0.item.name < $1.item.name }
                .prefix(limit)
        )
    }

    // MARK: - Kürzel-Auflösung (Stufe 4: Kaufhistorie-Fuzzy-Match)

    /// Sucht in der Kaufhistorie DESSELBEN Stores nach dem Artikelnamen, der am stärksten mit dem
    /// OCR-Token überlappt — z. B. "Mozarela" (OCR) → "Mozzarella Di Bufala 125g" (frühere Käufe an
    /// diesem Store). Hilft vor allem bei wiederkehrenden Artikeln; bei einem komplett neuen Kürzel
    /// ohne Bezug zu vergangenen Käufen liefert das nichts (siehe Stufe 5, Apple Intelligence).
    ///
    /// Nutzt dieselbe Fuzzy-Bewertung (`lcsSimilarity`) und denselben Schwellwert
    /// (`completedItemAutoApplyThreshold`) wie Stufe 3 (`completedItemCandidates`) statt reinem
    /// `contains` — vorher gewann der ERSTE textlich überlappende Treffer, nicht der beste, und ein
    /// eigener, vom Nutzer tatsächlich verwendeter Name (z. B. "Burger Brötchen") konnte an einem
    /// schwächeren `contains`-Zufallstreffer vorbeigehen und fiel dadurch bis zur KI-Stufe durch,
    /// die ohne jeden Nutzerkontext rät. Store-Scope bleibt bewusst erhalten: kein
    /// store-übergreifendes Auto-Apply, um keine Namen von einem anderen Store fälschlich
    /// zuzuordnen.
    static func historyMatch(for token: String, in records: [PurchaseRecord], storeName: String) -> String? {
        guard token.count >= 3 else { return nil }
        let storeLower = storeName.lowercased()
        let sameStore = records.filter { $0.storeName.lowercased() == storeLower }
        guard !sameStore.isEmpty else { return nil }

        var bestByName: [String: Double] = [:]
        for record in sameStore {
            let score = lcsSimilarity(token, record.itemName)
            let key = record.itemName.lowercased()
            if let existing = bestByName[key], existing >= score { continue }
            bestByName[key] = score
        }
        // Wie completedItemCandidates oben: bestByName.max(by:) allein iteriert in
        // unspezifizierter (pro Prozess zufälliger) Dictionary-Reihenfolge — ohne
        // deterministischen Tie-Breaker könnte bei zwei exakt gleich bewerteten,
        // unterschiedlich benannten Kaufhistorie-Einträgen das Ergebnis zwischen App-Starts
        // wechseln (gefunden 19.08.2026, gleiche Ursache/Lösung wie dort).
        guard let best = bestByName.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }),
              best.value >= completedItemAutoApplyThreshold else { return nil }
        return sameStore.first { $0.itemName.lowercased() == best.key }?.itemName
    }
}

// MARK: - Kürzel-Auflösung (Stufe 5: Apple Intelligence, optional)

/// Letzte Stufe der Kassenbon-Namensauflösung (siehe ReceiptScannerView.process()) — nur wenn
/// gelernter Alias, Wörterbuch, abgehakte Artikel UND Kaufhistorie-Match nichts liefern. Spiegelt exakt das
/// Guard-/Timeout-Muster von `MealIngredientService.aiIngredients`
/// (RecipeRecognitionService.swift), inklusive 25-Sekunden-Timeout-Rennen, damit ein hängender
/// Modellaufruf den Scan-Review-Bildschirm nie blockiert. Nur auf iOS 26+ mit verfügbarer Apple
/// Intelligence aktiv; auf jedem anderen Gerät liefert `expand` einfach nil und die bisherige
/// Stufe (unveränderter Roh-Text) bleibt stehen. Der User sieht/bearbeitet jede Zeile ohnehin vor
/// dem Speichern, ein gelegentlich falscher Vorschlag ist daher kein Datenrisiko.
actor ReceiptNameAIResolver {
    static let shared = ReceiptNameAIResolver()

    /// Antwort-Marker für "das ist gar kein Produkt" — siehe Prompt in `aiExpand` und `sanitize`
    /// unten. Ohne diesen Ausweg musste das Modell für JEDEN Text, der Stufe 5 erreicht
    /// (`ReceiptResolutionService.resolve`), einen Produktnamen erfinden — auch für Fragmente aus
    /// nicht sauber gefilterten Tabellen-/Zahlungs-Metadaten-Zeilen. Gemeldet 24.08.2026: vier
    /// erfundene "Pizza Baguette"-Positionen, deren Preise exakt der MwSt-Tabelle + Bon-Summe
    /// entsprachen — kein echter Artikel, aber das Modell musste trotzdem etwas Plausibles raten.
    /// Nicht `private`: `RestockTests` braucht ihn, um `sanitize` direkt zu testen, ohne den
    /// String zu duplizieren (der eigentliche LLM-Aufruf selbst ist in der Test-Umgebung nicht
    /// verfügbar — Apple Intelligence läuft im Simulator/CI nicht — deshalb testet
    /// `ReceiptNameAIResolverSanitizeTests` nur die deterministische Nachbearbeitung).
    static let nonProductSentinel = "KEIN_PRODUKT"

    static func isAIAvailable() -> Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    /// Öffentlicher Einstiegspunkt — kapselt Verfügbarkeits-Check, iOS-Version-Guard und
    /// Fehlerbehandlung, damit der Aufrufer nur ein einfaches optionales String bekommt.
    /// `knownNames` sind die eigenen, bereits bekannten Artikelnamen des Nutzers (siehe
    /// `ReceiptResolutionService.knownItemNames`) — rein empfehlender Kontext für den Prompt,
    /// keine harte Vorgabe.
    func expand(_ raw: String, knownNames: [String] = []) async -> String? {
        guard #available(iOS 26, *) else { return nil }
        return (try? await aiExpand(raw, knownNames: knownNames)) ?? nil
    }

    @available(iOS 26, *)
    private func aiExpand(_ raw: String, knownNames: [String]) async throws -> String? {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        // Empfehlend, nicht bindend ("bevorzuge... falls plausibel") — bei einem echten neuen
        // Produkt, das nicht in `knownNames` vorkommt, soll das Modell weiterhin frei raten dürfen.
        let knownHint = knownNames.isEmpty ? "" : """

        Der Nutzer verwendet u. a. diese eigenen Artikelnamen (bevorzuge eine Übereinstimmung/Ähnlichkeit hiermit, falls plausibel): \(knownNames.joined(separator: ", "))
        """
        let prompt = """
        Dies ist eine abgekürzte Positionszeile von einem Kassenbon (Deutsch oder Französisch): "\(raw)"

        Antworte NUR mit einem KURZEN, generischen Produktnamen, wie er normalerweise auf einer
        Einkaufsliste steht — z. B. "Sahne" oder "Bio Sahne", NICHT "Bio Schlagsahne 30% Fett
        Weihenstephan Frischebecher" — in derselben Sprache, ohne Erklärung, ohne
        Anführungszeichen, ohne Preis oder Menge.

        Falls der Text KEIN Produkt ist (z. B. ein Zahlungs-/Steuer-/Transaktionscode, eine reine
        Zahlenfolge, ein Tabellen-Fragment oder sonstiger Kassenbon-Verwaltungstext ohne
        erkennbaren Produktbezug), antworte NUR mit \(Self.nonProductSentinel), sonst nichts.\(knownHint)
        """
        // FoundationModels kann in iOS 26 Beta hängen — nach 25 s abbrechen. Nutzt `withRealTimeout`
        // (RecipeRecognitionService.swift) statt eines TaskGroup-Rennens, das einen wirklich
        // hängenden Aufruf nicht begrenzt hätte (siehe dessen Dokumentation).
        return await withRealTimeout(
            seconds: 25,
            operation: {
                guard let response = try? await LanguageModelSession().respond(to: prompt) else { return nil }
                return self.sanitize(response.content)
            },
            onTimeout: { nil }
        )
        #else
        return nil
        #endif
    }

    nonisolated func sanitize(_ text: String) -> String? {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !trimmed.isEmpty, trimmed.count <= 60, !trimmed.contains("\n") else { return nil }
        guard trimmed.caseInsensitiveCompare(Self.nonProductSentinel) != .orderedSame else { return nil }
        return trimmed
    }
}
