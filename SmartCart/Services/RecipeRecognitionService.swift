import Foundation
import Vision
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// Apple Intelligence (FoundationModels, iOS 26+) as primary engine.
// Vision OCR + rule-based parsing as fallback.

struct RecognizedIngredient: Identifiable {
    let id = UUID()
    var name: String
    var quantity: String
    var unit: String
}

// MARK: - Meal Ingredient Service

actor MealIngredientService {
    static let shared = MealIngredientService()

    enum Source { case ai, database, none }

    func ingredients(for mealName: String) async -> (names: [String], source: Source) {
        let trimmed = mealName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ([], .none) }

        if #available(iOS 26, *) {
            if let result = try? await aiIngredients(for: trimmed), !result.isEmpty {
                return (result, .ai)
            }
        }

        let db = MealDatabase.ingredients(for: trimmed)
        return db.isEmpty ? ([], .none) : (db, .database)
    }

    static func isAIAvailable() -> Bool {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return false }
        if case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    @available(iOS 26, *)
    private func aiIngredients(for mealName: String) async throws -> [String]? {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let prompt = """
        Gib mir die Hauptzutaten für das Gericht "\(mealName)" als JSON-Array von Strings auf Deutsch.
        Nur Zutatennamen, keine Mengen, keine Einheiten, 4–8 Zutaten.
        Antworte NUR mit dem JSON-Array, z.B.: ["Mehl","Eier","Milch"]
        """
        // FoundationModels kann in iOS 26 Beta hängen — nach 25 s abbrechen
        return try await withThrowingTaskGroup(of: [String]?.self) { group in
            group.addTask {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                return self.parseStringArray(from: response.content)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(25))
                return nil
            }
            defer { group.cancelAll() }
            for try await result in group { return result }
            return nil
        }
        #else
        return nil
        #endif
    }

    nonisolated private func parseStringArray(from text: String) -> [String]? {
        guard let start = text.range(of: "["),
              let end = text.range(of: "]", options: .backwards),
              start.lowerBound <= end.lowerBound else { return nil }
        let jsonStr = String(text[start.lowerBound...end.upperBound])
        guard let data = jsonStr.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
        return arr.filter { !$0.isEmpty }
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
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
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
                    results.append(RecognizedIngredient(
                        name: name,
                        quantity: "\(Int(firstNum))",
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
