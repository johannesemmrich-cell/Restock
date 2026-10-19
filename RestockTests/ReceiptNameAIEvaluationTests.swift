// Issue #159: Messung von Stufe 5 (Apple Intelligence) mit dem ECHTEN Modell. Läuft nur mit der
// Kompilierbedingung AI_EVAL (nur `scripts/run-ai-eval.sh` setzt sie) auf einem Mac mit
// eingeschaltetem Apple Intelligence; in CI, Xcode und auf Restock-Validate ist diese Datei leer.
// Kein Pass/Fail-Test im klassischen Sinn: die Klasse misst Raten und schreibt einen Bericht
// zwischen die Marker AI-EVAL-REPORT-BEGIN/END ins Testprotokoll; das Skript hebt ihn auf.
// Einziges hartes Urteil (`testCurrentPromptNeverRepeatsBroet`): Mit der vergifteten Namensliste
// darf die heutige Kette kein „Bröt.“ und keine Antwort für ≥ 3 fremde Zeilen liefern.
#if AI_EVAL
import XCTest
@testable import Restock

final class ReceiptNameAIEvaluationTests: XCTestCase {

    // MARK: - Messdaten

    struct Sample {
        let raw: String
        /// Akzeptierte Antworten (eine reicht; Vergleich gefaltet, Teilwort in beide Richtungen).
        /// Leer = kein Produkt, erwartet wird `nil` (KEIN_PRODUKT).
        let accepted: [String]
        let group: String
    }

    static let dmSamples: [Sample] = [
        ("Soft&Sicher Pocket 6x8St", ["Taschentücher"]), ("dmBio Espresso gemahlen 250g", ["Espresso", "Kaffee"]),
        ("Ricola Bonbon Salbei", ["Salbeibonbons", "Bonbons", "Hustenbonbons"]), ("Mentos Gum 3 Fruity Fresh", ["Kaugummi"]),
        ("dmBio Noisette Schokol", ["Schokolade", "Nussschokolade"]), ("Schoko Lolli Vollmilch", ["Lolli", "Schokolade", "Schokololli"]),
        ("dmBio Schneebälle Marzipan 30g", ["Marzipan", "Schneebälle"]), ("dmBio Schokolierte Brezeln ZB", ["Brezeln", "Schokobrezeln"]),
        ("dmBio Gemüsebrühe Nachfüllbt.", ["Gemüsebrühe"]), ("Elmex Zahncr. Sens. Prof. 75ml", ["Zahnpasta", "Zahncreme"]),
        ("Balea Tuchmaske Ultra Sensitiv", ["Tuchmaske", "Gesichtsmaske"]), ("lavera Lippenbalsam Basis Sens", ["Lippenbalsam", "Lippenpflege"]),
        ("ShirinBeauty LipOil Strawberry", ["Lippenöl", "Lippenpflege"]), ("SEINZ. Tuchmaske Hydro Effect", ["Tuchmaske", "Gesichtsmaske"]),
        ("Balea Fuß-Maske Socken 1 Paar", ["Fußmaske"]), ("ebelin Scunchie Kugel 1St", ["Haargummi", "Scrunchie"]),
    ].map { Sample(raw: $0.0, accepted: $0.1, group: "dm") }

    static let lidlAccepted: [String: [String]] = [
        "banane": ["Bananen", "Banane"], "nektarinen": ["Nektarinen"], "bistrobaguet": ["Baguette", "Salamibaguette"],
        "gouda": ["Gouda", "Käse"], "schlagsahne": ["Sahne", "Schlagsahne"], "maultas": ["Maultaschen"],
        "penne": ["Penne", "Nudeln"], "spaghetti": ["Spaghetti", "Nudeln"], "eier": ["Eier"], "haferflocken": ["Haferflocken"],
        "olivenöl": ["Olivenöl"], "red bull": ["Red Bull", "Energy Drink"], "mandelkerne": ["Mandeln", "Mandelkerne"],
        "brötchen": ["Brötchen", "Laugenbrötchen"],
    ]
    static var lidlSamples: [Sample] {
        ReceiptParserService.parse(ReceiptParserLidlFullReceiptTests.lidlLines).compactMap { line in
            let key = line.name.lowercased()
            guard let accepted = lidlAccepted.first(where: { key.contains($0.key) })?.value else { return nil }
            return Sample(raw: line.name, accepted: accepted, group: "lidl")
        }
    }

    static let reweAccepted: [String: [String]] = [
        "gouda": ["Gouda", "Käse"], "laugenbroetchen": ["Brötchen", "Laugenbrötchen"], "maultaschen": ["Maultaschen"],
        "butterbaguett": ["Baguette", "Butterbaguette"], "banane": ["Bananen", "Banane"], "mandeln": ["Mandeln"],
        "eier": ["Eier"], "butter": ["Butter"], "skyr": ["Skyr"], "haferfl": ["Haferflocken"],
        "lungo": ["Kaffee", "Kaffeekapseln"], "espr": ["Espresso", "Kaffee"], "spuelm": ["Spülmittel"], "gefrierbeutel": ["Gefrierbeutel"],
    ]
    static var reweSamples: [Sample] {
        ReceiptParserService.parse(ReceiptParserReweTests.reweLines).compactMap { line in
            let key = line.name.lowercased()
            guard let accepted = reweAccepted.first(where: { key.contains($0.key) })?.value else { return nil }
            return Sample(raw: line.name, accepted: accepted, group: "rewe")
        }
    }

    static let adminSamples: [Sample] = [
        "TSE Transaktionsnummer: 2111061", "Kartennr. ##########1002 00", "A 7 % 1,92 27,46 29,38",
        "Summe 2,96 32,91 35,87", "Autorisierungsnummer 050783", "Steuer % Netto Steuer Brutto", "Nr. XXXX7224",
    ].map { Sample(raw: $0, accepted: [], group: "admin") }

    static var allSamples: [Sample] { dmSamples + lidlSamples + reweSamples + adminSamples }

    /// Eigene Artikelnamen, wie sie `knownItemNames` am 18.10.2026 vermutlich lieferte: das als
    /// Rohtext gespeicherte Kürzel ganz vorn (jüngster Kauf).
    static let poisonedKnownNames = ["Bröt.", "Salbeibonbons", "Zahnpasta", "Milch", "Butter", "Eier", "Kaffee", "Brötchen"]
    static let cleanKnownNames = Array(poisonedKnownNames.dropFirst())

    // MARK: - Varianten

    enum Variant: String, CaseIterable {
        case current = "heutiger Prompt + Prüfungen"
        case legacy = "alter Prompt (vor #157), alte Prüfung"

        func prompt(raw: String, knownNames: [String]) -> String {
            switch self {
            case .current: return ReceiptNameAIResolver.prompt(for: raw, knownNames: knownNames)
            case .legacy:
                let hint = knownNames.isEmpty ? "" : """

                Der Nutzer verwendet u. a. diese eigenen Artikelnamen (bevorzuge eine Übereinstimmung/Ähnlichkeit hiermit, falls plausibel): \(knownNames.joined(separator: ", "))
                """
                return """
                Dies ist eine abgekürzte Positionszeile von einem Kassenbon (Deutsch oder Französisch): "\(raw)"

                Antworte NUR mit einem KURZEN, generischen Produktnamen, wie er normalerweise auf einer
                Einkaufsliste steht — z. B. "Sahne" oder "Bio Sahne", NICHT "Bio Schlagsahne 30% Fett
                Weihenstephan Frischebecher" — in derselben Sprache, ohne Erklärung, ohne
                Anführungszeichen, ohne Preis oder Menge.

                Falls der Text KEIN Produkt ist (z. B. ein Zahlungs-/Steuer-/Transaktionscode, eine reine
                Zahlenfolge, ein Tabellen-Fragment oder sonstiger Kassenbon-Verwaltungstext ohne
                erkennbaren Produktbezug), antworte NUR mit \(ReceiptNameAIResolver.nonProductSentinel), sonst nichts.\(hint)
                """
            }
        }

        /// Alte Nachbearbeitung: ohne Kürzel-Prüfung, ohne Wiederholungs-Regel.
        func sanitize(_ text: String, resolver: ReceiptNameAIResolver) -> String? {
            switch self {
            case .current: return resolver.sanitize(text)
            case .legacy:
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= 60, !trimmed.contains("\n") else { return nil }
                guard trimmed.caseInsensitiveCompare(ReceiptNameAIResolver.nonProductSentinel) != .orderedSame else { return nil }
                return trimmed
            }
        }

        /// Kürzel aus den eigenen Namen filtern wie `knownItemNames` heute; früher nicht.
        func knownNames(_ names: [String]) -> [String] {
            self == .current ? names.filter { !ReceiptNameAIResolver.endsWithAbbreviation($0) } : names
        }
    }

    struct Row {
        let variant: Variant; let list: String; let sample: Sample
        let rawAnswer: String?; let name: String?; let seconds: Double
        var hit: Bool {
            guard let name else { return sample.accepted.isEmpty }
            guard !sample.accepted.isEmpty else { return false }
            let a = fold(name)
            return sample.accepted.contains { let e = fold($0); return a == e || a.contains(e) || e.contains(a) }
        }
        var isAbbreviation: Bool { name.map(ReceiptNameAIResolver.endsWithAbbreviation) ?? false }
        var falseNonProduct: Bool { name == nil && !sample.accepted.isEmpty && rawAnswer != nil }
        var timedOut: Bool { rawAnswer == nil }
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespaces)
    }
    private func fold(_ s: String) -> String { Self.fold(s) }

    private let model = SystemReceiptNameLanguageModel()

    // MARK: - Vorprobe (Simulator meldet „verfügbar“, hat aber ggf. keine Modell-Assets)

    func testProbeModelReallyGenerates() async throws {
        print("AI-EVAL-PROBE: isAvailable=\(model.isAvailable)")
        try XCTSkipUnless(model.isAvailable, "Apple Intelligence nicht verfügbar — Messung übersprungen")
        let answer = await withRealTimeout(seconds: 25, operation: { await self.model.respond(to: "Antworte nur mit dem Wort Ja.") }, onTimeout: { nil })
        print("AI-EVAL-PROBE: answer=\(answer ?? "<nil>")")
        XCTAssertNotNil(answer, "Modell meldet verfügbar, generiert aber nicht (vgl. CI-Runner: UnifiedAssetFramework 5000) — Messung wäre wertlos")
    }

    // MARK: - Messung

    private func run(_ variant: Variant, list: String, knownNames: [String]) async -> [Row] {
        var rows: [Row] = []
        let names = variant.knownNames(knownNames)
        for sample in Self.allSamples {
            let prompt = variant.prompt(raw: sample.raw, knownNames: names)
            let start = Date()
            let raw = await withRealTimeout(seconds: 25, operation: { await self.model.respond(to: prompt) }, onTimeout: { nil })
            let seconds = Date().timeIntervalSince(start)
            let name = raw.flatMap { variant.sanitize($0, resolver: ReceiptNameAIResolver(model: model)) }
            rows.append(Row(variant: variant, list: list, sample: sample, rawAnswer: raw, name: name, seconds: seconds))
        }
        // Wiederholungs-Regel nur in der heutigen Kette, über alle Zeilen eines Laufs.
        guard variant == .current else { return rows }
        let answers = Dictionary(uniqueKeysWithValues: rows.enumerated().compactMap { i, r in r.name.map { (i, $0) } })
        let raws = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($0.offset, $0.element.sample.raw) })
        let kept = ReceiptNameAIResolver.discardingRepeatedUnrelatedAnswers(answers, rawNames: raws)
        return rows.enumerated().map { i, r in
            answers[i] != nil && kept[i] == nil
                ? Row(variant: r.variant, list: r.list, sample: r.sample, rawAnswer: r.rawAnswer, name: nil, seconds: r.seconds) : r
        }
    }

    private func report(_ rows: [Row]) -> String {
        func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%.0f %%", 100.0 * Double(n) / Double(d)) }
        var out = "| Variante | Namensliste | Zeilen | Treffer | Kürzel | gleiche Antwort verworfen | KEIN_PRODUKT falsch | Timeouts | Ø s |\n|---|---|---|---|---|---|---|---|---|\n"
        for variant in Variant.allCases {
            for list in ["sauber", "vergiftet"] {
                let r = rows.filter { $0.variant == variant && $0.list == list }
                guard !r.isEmpty else { continue }
                let repeated = r.filter { $0.rawAnswer != nil && $0.name == nil && !$0.sample.accepted.isEmpty && !Self.fold($0.rawAnswer!).hasPrefix("kein_produkt") }.count
                let avg = r.map(\.seconds).reduce(0, +) / Double(r.count)
                out += "| \(variant.rawValue) | \(list) | \(r.count) | \(pct(r.filter(\.hit).count, r.count)) | \(r.filter(\.isAbbreviation).count) | \(repeated) | \(r.filter(\.falseNonProduct).count) | \(r.filter(\.timedOut).count) | \(String(format: "%.1f", avg)) |\n"
            }
        }
        out += "\n### Einzelzeilen\n| Variante | Liste | Gruppe | Bontext | Rohantwort | Name | Treffer |\n|---|---|---|---|---|---|---|\n"
        for r in rows {
            out += "| \(r.variant == .current ? "heute" : "alt") | \(r.list) | \(r.sample.group) | \(r.sample.raw) | \((r.rawAnswer ?? "<timeout>").replacingOccurrences(of: "\n", with: " ")) | \(r.name ?? "–") | \(r.hit ? "✓" : "✗") |\n"
        }
        return out
    }

    func testMeasureAllVariants() async throws {
        try XCTSkipUnless(model.isAvailable, "Apple Intelligence nicht verfügbar")
        var rows: [Row] = []
        for variant in Variant.allCases {
            rows += await run(variant, list: "sauber", knownNames: Self.cleanKnownNames)
            rows += await run(variant, list: "vergiftet", knownNames: Self.poisonedKnownNames)
        }
        print("AI-EVAL-REPORT-BEGIN\n\(report(rows))\nAI-EVAL-REPORT-END")
        XCTAssertEqual(rows.filter(\.timedOut).count, 0, "Timeouts im Lauf — Messung unvollständig")
    }

    /// Das harte Urteil: die heutige Kette mit vergifteter Liste darf den gemeldeten Fehler nicht
    /// mehr zeigen.
    func testCurrentPromptNeverRepeatsBroet() async throws {
        try XCTSkipUnless(model.isAvailable, "Apple Intelligence nicht verfügbar")
        let rows = await run(.current, list: "vergiftet", knownNames: Self.poisonedKnownNames)
        let broet = rows.filter { $0.name.map { Self.fold($0) == "bröt." || Self.fold($0) == "brot." } ?? false }
        XCTAssertTrue(broet.isEmpty, "„Bröt.“ kam durch bei: \(broet.map(\.sample.raw))")
        let counts = Dictionary(grouping: rows.compactMap(\.name), by: Self.fold).mapValues(\.count)
        let repeated = counts.filter { $0.value >= 3 }
        // Mehrfach erlaubt nur bei echtem Bezug (zwei Tuchmasken, Baguette/Brötchen …) — darum nur melden:
        if !repeated.isEmpty { print("AI-EVAL-HINWEIS: mehrfach vergebene Namen (geprüft durch Wortbezug): \(repeated)") }
    }
}
#endif
