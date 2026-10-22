// Issue #164, Entscheidung 4: Nachweis der KI-Preisstufe mit dem ECHTEN Gerätemodell, bevor sie
// eingeschaltet wird. Läuft nur mit der Kompilierbedingung AI_EVAL (`scripts/run-ai-price-eval.sh`)
// auf einem Mac mit eingeschalteter Apple Intelligence; in CI, Xcode und auf Restock-Validate ist
// diese Datei leer (Grund wie bei #159: kein Modell im Simulator der CI).
//
// Prüfsatz: 100 Katalogartikel (jeder fünfte Eintrag aus `PriceCatalog.entries` ohne die 32
// Alt-Stichwörter, erster Name, Großschreibung), Referenz = Katalogwert. Kennzahlen: Anteil
// angenommener Antworten, mittlerer absoluter Fehler (%), Anteil innerhalb ±30 %, Ausreißer
// (Faktor > 3), Zeitüberschreitungen, Dauer. Gate: ≥ 70 % der angenommenen Antworten innerhalb ±30 %
// UND ≥ 70 % des Prüfsatzes überhaupt angenommen. Der Bericht steht zwischen AI-PRICE-EVAL-REPORT-BEGIN/END.
#if AI_EVAL
import XCTest
@testable import Restock

final class AIPriceEvaluationTests: XCTestCase {

    static let sampleSize = 100
    static let gateWithin30 = 0.70
    static let gateAccepted = 0.70

    struct Row {
        let name: String
        let group: String
        let reference: PriceCatalogEntry
        let guess: AIPriceGuess?
        let accepted: AIPriceEstimation.Resolution?
        let seconds: Double
        /// Modellwert und Referenz auf dieselbe Basis gebracht (je Packung des Katalogs); `nil` bei
        /// unvereinbaren Packungsarten (Stück gegen Gewicht).
        var comparablePair: (model: Double, reference: Double)? {
            guard let accepted else { return nil }
            let g = accepted.guess
            if reference.packageUnit == "stk" {
                guard g.packageUnit == "stk" else { return nil }
                return (g.typical, reference.typical)
            }
            guard g.packageUnit != "stk", g.packageAmount > 0 else { return nil }
            return (g.typical / g.packageAmount * reference.packageAmount, reference.typical)
        }
        var errorPercent: Double? {
            guard let pair = comparablePair, pair.reference > 0 else { return nil }
            return abs(pair.model - pair.reference) / pair.reference * 100
        }
        var isOutlier: Bool {
            guard let pair = comparablePair, pair.reference > 0, pair.model > 0 else { return false }
            return max(pair.model / pair.reference, pair.reference / pair.model) > 3
        }
    }

    static var sample: [(name: String, group: String, entry: PriceCatalogEntry)] {
        let groups: [(String, [PriceCatalogEntry])] = [
            ("dairy", PriceCatalog.dairy), ("meatAndFish", PriceCatalog.meatAndFish), ("produce", PriceCatalog.produce),
            ("bakery", PriceCatalog.bakery), ("drinks", PriceCatalog.drinks), ("frozen", PriceCatalog.frozen),
            ("snacks", PriceCatalog.snacks), ("spicesAndBaking", PriceCatalog.spicesAndBaking), ("pantry", PriceCatalog.pantry),
            ("personalCare", PriceCatalog.personalCare), ("household", PriceCatalog.household),
            ("foodAdditions", PriceCatalog.foodAdditions), ("drugstore", PriceCatalog.drugstore),
            ("householdMore", PriceCatalog.householdMore), ("sports", PriceCatalog.sports),
        ]
        var all: [(String, String, PriceCatalogEntry)] = []
        for (group, entries) in groups {
            for entry in entries where entry.typical <= PriceEstimator.maxPlausibleLineTotal {
                guard let first = entry.names.first, !first.contains(" ") || first.count > 6 else { continue }
                all.append((first.prefix(1).uppercased() + first.dropFirst(), group, entry))
            }
        }
        return stride(from: 0, to: all.count, by: max(1, all.count / sampleSize)).prefix(sampleSize)
            .map { (name: all[$0].0, group: all[$0].1, entry: all[$0].2) }
    }

    func testMeasureAgainstCatalog() async throws {
        let model = SystemPriceLanguageModel()
        try XCTSkipUnless(model.isAvailable, "Apple Intelligence nicht verfügbar")
        print("AI-PRICE-EVAL-PROBE: Modell verfügbar, Prüfsatz \(Self.sample.count) Artikel")
        var rows: [Row] = []
        for s in Self.sample {
            let request = AIPriceRequest(itemName: s.name, quantityAmount: 1, unit: s.entry.packageUnit == "stk" ? "" : "g",
                                         category: AssignmentService.category(for: s.name))
            let start = Date()
            let guess = await model.estimate(request)
            let seconds = Date().timeIntervalSince(start)
            let accepted = guess.flatMap { AIPriceEstimation.validate($0, for: request) }
            rows.append(Row(name: s.name, group: s.group, reference: s.entry, guess: guess, accepted: accepted, seconds: seconds))
        }
        print("AI-PRICE-EVAL-REPORT-BEGIN\n\(report(rows))\nAI-PRICE-EVAL-REPORT-END")
    }

    private func report(_ rows: [Row]) -> String {
        func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%.0f %%", 100.0 * Double(n) / Double(d)) }
        let accepted = rows.filter { $0.accepted != nil }
        let comparable = rows.filter { $0.errorPercent != nil }
        let within = comparable.filter { $0.errorPercent! <= 30 }
        let outliers = rows.filter(\.isOutlier)
        let timeouts = rows.filter { $0.guess == nil && $0.seconds >= SystemPriceLanguageModel.timeoutSeconds - 0.5 }
        let meanError = comparable.isEmpty ? 0 : comparable.map { $0.errorPercent! }.reduce(0, +) / Double(comparable.count)
        let medianError: Double = {
            let sorted = comparable.map { $0.errorPercent! }.sorted()
            guard !sorted.isEmpty else { return 0 }
            return sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }()
        let avgSeconds = rows.isEmpty ? 0 : rows.map(\.seconds).reduce(0, +) / Double(rows.count)
        let acceptedShare = rows.isEmpty ? 0 : Double(accepted.count) / Double(rows.count)
        let withinShare = comparable.isEmpty ? 0 : Double(within.count) / Double(comparable.count)
        let gate = acceptedShare >= Self.gateAccepted && withinShare >= Self.gateWithin30
        var out = "| Prüfsatz | angenommen | vergleichbar | innerhalb ±30 % | Ø Fehler | Median Fehler | Ausreißer (>×3) | Timeouts | Ø s |\n|---|---|---|---|---|---|---|---|---|\n"
        out += "| \(rows.count) | \(pct(accepted.count, rows.count)) | \(comparable.count) | \(pct(within.count, comparable.count)) | \(String(format: "%.0f %%", meanError)) | \(String(format: "%.0f %%", medianError)) | \(outliers.count) | \(timeouts.count) | \(String(format: "%.1f", avgSeconds)) |\n\n"
        out += "GATE (≥ \(Int(Self.gateAccepted * 100)) % angenommen UND ≥ \(Int(Self.gateWithin30 * 100)) % innerhalb ±30 %): \(gate ? "BESTANDEN" : "NICHT BESTANDEN")\n\n"
        out += "### Je Gruppe\n| Gruppe | n | angenommen | innerhalb ±30 % |\n|---|---|---|---|\n"
        for group in Array(Set(rows.map(\.group))).sorted() {
            let g = rows.filter { $0.group == group }
            let gc = g.filter { $0.errorPercent != nil }
            out += "| \(group) | \(g.count) | \(pct(g.filter { $0.accepted != nil }.count, g.count)) | \(pct(gc.filter { $0.errorPercent! <= 30 }.count, gc.count)) |\n"
        }
        out += "\n### Einzelzeilen\n| Artikel | Referenz | Modell (Packung, Spanne) | Fehler | Urteil |\n|---|---|---|---|---|\n"
        for r in rows {
            let ref = "\(r.reference.typical.formatted(.number.precision(.fractionLength(2)))) € / \(r.reference.packageAmount.formatted()) \(r.reference.packageUnit)"
            let model = r.guess.map { "\($0.packageAmount.formatted()) \($0.packageUnit): \($0.low)–\($0.typical)–\($0.high)" } ?? "<keine Antwort>"
            let verdict = r.accepted == nil ? (r.guess == nil ? "keine Antwort" : "verworfen") : (r.errorPercent == nil ? "Packungsart anders" : (r.isOutlier ? "Ausreißer" : "ok"))
            out += "| \(r.name) | \(ref) | \(model) | \(r.errorPercent.map { String(format: "%.0f %%", $0) } ?? "–") | \(verdict) |\n"
        }
        return out
    }
}
#endif
