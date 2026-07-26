import Foundation
import Vision
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// Apple Intelligence (FoundationModels, iOS 26+) as primary engine.
// Vision OCR + rule-based parsing as fallback.

// CGImagePropertyOrientation(_ uiOrientation:) lebt jetzt in
// SmartCart/Extensions/CGImagePropertyOrientation+UIImage.swift — dort auch von der Share
// Extension nutzbar, ohne den Rest dieser Datei (Apple-Intelligence-Rezepterkennung) mitzuziehen.

struct RecognizedIngredient: Identifiable {
    let id = UUID()
    var name: String
    var quantity: String
    var unit: String
}

// withRealTimeout(seconds:operation:onTimeout:) lebt jetzt in
// SmartCart/Extensions/CGImagePropertyOrientation+UIImage.swift — dort bereits Ziel-Mitgliedschaft
// in Haupt-App UND Share Extension, ohne das hier ebenfalls zu brauchen (ReceiptNameAIResolver in
// ReceiptParserService.swift nutzt sie, unabhängig von der Rezepterkennung dieser Datei).

// MARK: - Meal Ingredient Service

actor MealIngredientService {
    static let shared = MealIngredientService()

    enum Source: Sendable { case ai, database, none }

    func ingredients(for mealName: String) async -> (items: [MealIngredient], source: Source) {
        let trimmed = mealName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ([], .none) }

        // Bekannte Gerichte zuerst aus der lokalen Datenbank bedienen — sofort verfügbar, kein
        // Risiko eines hängenden Modellaufrufs. Apple Intelligence lohnt sich nur für Gerichte,
        // die die Datenbank nicht kennt (vorher lief AI IMMER zuerst, auch für exakte
        // DB-Treffer wie "Pasta" — jede Eingabe eines bekannten Gerichts zahlte damit unnötig
        // das volle Timeout-Risiko des KI-Pfads, siehe aiIngredients()).
        let db = MealDatabase.ingredients(for: trimmed)
        if !db.isEmpty { return (db, .database) }

        if #available(iOS 26, *) {
            if let result = try? await aiIngredients(for: trimmed), !result.isEmpty {
                return (result, .ai)
            }
        }

        return ([], .none)
    }

    static func isAIAvailable() -> Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    @available(iOS 26, *)
    private func aiIngredients(for mealName: String) async throws -> [MealIngredient]? {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let prompt = """
        Gib mir die Hauptzutaten für das Gericht "\(mealName)" für \(MealDatabase.baseServings) Portionen \
        als JSON-Array von Objekten auf Deutsch.
        Jede Zutat braucht: "name" (String), "amount" (Zahl als String, z.B. "400"), "unit" \
        (z.B. "g", "ml", "Stück", "EL", "TL", oder "" falls unpassend).
        Antworte NUR mit dem JSON-Array, z.B.: [{"name":"Mehl","amount":"200","unit":"g"}]
        """
        // FoundationModels kann in iOS 26 Beta hängen — nach 25 s abbrechen. Nutzt `withRealTimeout`
        // statt eines TaskGroup-Rennens, das den hängenden Aufruf nicht wirklich begrenzt hätte
        // (siehe dessen Dokumentation).
        return await withRealTimeout(
            seconds: 25,
            operation: {
                guard let response = try? await LanguageModelSession().respond(to: prompt) else { return nil }
                return self.parseMealIngredients(from: response.content)
            },
            onTimeout: { nil }
        )
        #else
        return nil
        #endif
    }

    nonisolated private func parseMealIngredients(from text: String) -> [MealIngredient]? {
        guard let start = text.range(of: "["),
              let end = text.range(of: "]", options: .backwards),
              start.lowerBound <= end.lowerBound else { return nil }
        let jsonStr = String(text[start.lowerBound...end.upperBound])
        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return nil }
        return arr.compactMap { dict in
            guard let name = dict["name"], !name.isEmpty else { return nil }
            let amount = Double(dict["amount"] ?? "") ?? 1
            return MealIngredient(name: name, amount: amount, unit: dict["unit"] ?? "")
        }
    }
}

// MARK: - Recipe Recognition Service

actor RecipeRecognitionService {
    static let shared = RecipeRecognitionService()

    func recognizeIngredients(from image: UIImage) async throws -> [RecognizedIngredient] {
        // Step 1: Always extract raw text via Vision OCR
        let rawText = try await extractText(from: image)
        guard !rawText.isEmpty else { return [] }

        // Step 2: Try Apple Intelligence first (iOS 26+)
        if #available(iOS 26, *) {
            if let results = try? await parseWithFoundationModels(text: rawText) {
                return results
            }
        }

        // Step 3: Rule-based fallback
        return parseIngredients(from: rawText.components(separatedBy: "\n"))
    }

    // MARK: - Vision OCR (text extraction)

    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true
            do {
                // WICHTIG: orientation muss mitgegeben werden — sonst verwirft Vision die
                // UIImage.imageOrientation-Metadaten und interpretiert Hochkant-Fotos (der
                // Sensor liefert die Pixel meist quer, iOS taggt nur die Rotation) als quer
                // liegenden Text, was die Ingredient-Erkennung scheitern lässt.
                try VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                ).perform([request])
            } catch {
                // perform() can throw synchronously (before the request's own completion handler
                // ever runs) — without catching this, the continuation above would never resume
                // and the caller would hang forever on this await.
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Apple Intelligence via FoundationModels

    @available(iOS 26, *)
    private func parseWithFoundationModels(text: String) async throws -> [RecognizedIngredient]? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }

        let session = LanguageModelSession()
        let prompt = """
        Extract all ingredients from this recipe text. Return them as a JSON array.
        Each ingredient must have: "name" (string), "quantity" (number as string, e.g. "200"), "unit" (e.g. "g", "ml", "EL", "TL", "Stück", or "" if none).
        Only return the JSON array, no other text.

        Recipe text:
        \(text)
        """

        let response = try await session.respond(to: prompt)
        return parseJSONIngredients(from: response.content)
    }

    private func parseJSONIngredients(from text: String) -> [RecognizedIngredient]? {
        // Extract JSON array from response
        guard let start = text.range(of: "["),
              let end = text.range(of: "]", options: .backwards) else { return nil }
        let jsonStr = String(text[start.lowerBound...end.upperBound])
        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return nil }

        return arr.compactMap { dict in
            guard let name = dict["name"], !name.isEmpty else { return nil }
            return RecognizedIngredient(
                name: name,
                quantity: dict["quantity"] ?? "1",
                unit: dict["unit"] ?? ""
            )
        }
    }

    // MARK: - Rule-based fallback parser

    private func parseIngredients(from lines: [String]) -> [RecognizedIngredient] {
        let units: Set<String> = ["g", "kg", "ml", "l", "cl", "dl", "el", "tl", "tbsp", "tsp",
                                   "stück", "prise", "bund", "dose", "glas", "pkg", "pck", "pkg"]
        var results: [RecognizedIngredient] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 1, !trimmed.hasPrefix("#"), !trimmed.hasPrefix("//") else { continue }

            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }

            // Try: "200g Mehl" or "200 g Mehl" or "2 Eier" or "1 EL Öl"
            if let firstNum = Double(parts[0].replacingOccurrences(of: ",", with: ".")) {
                let possibleUnit = parts.count > 2 ? parts[1].lowercased() : ""
                let hasUnit = units.contains(possibleUnit)
                let nameStart = (hasUnit && parts.count > 2) ? 2 : 1
                if nameStart < parts.count {
                    let name = parts[nameStart...].joined(separator: " ")
                    let unitStr = hasUnit ? parts[1] : ""
                    // OCR kann hier eine unplausible Zahl liefern (Barcode-/Seitenzahl-Fragment
                    // als lange Ziffernfolge, "inf", "nan") — Int(firstNum) stürzt dafür hart ab.
                    let safeQuantity = (firstNum.isFinite && abs(firstNum) < Double(Int.max))
                        ? "\(Int(firstNum))" : "1"
                    results.append(RecognizedIngredient(
                        name: name,
                        quantity: safeQuantity,
                        unit: unitStr
                    ))
                    continue
                }
                _ = firstNum
            }

            // Try combined "200g" prefix
            if let match = trimmed.range(of: #"^(\d+[\.,]?\d*)\s*(g|kg|ml|l|el|tl)\s+(.+)$"#,
                                         options: [.regularExpression, .caseInsensitive]) {
                let sub = String(trimmed[match])
                let p = sub.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if p.count >= 2 {
                    results.append(RecognizedIngredient(name: p[1...].joined(separator: " "), quantity: p[0], unit: ""))
                    continue
                }
            }

            // Fallback: whole line as ingredient name
            if !trimmed.first!.isNumber && trimmed.count > 2 && trimmed.count < 60 {
                results.append(RecognizedIngredient(name: trimmed, quantity: "1", unit: ""))
            }
        }

        return results
    }
}
