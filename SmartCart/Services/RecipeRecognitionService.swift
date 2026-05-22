import Foundation
import Vision
import UIKit

// Uses Apple Intelligence (FoundationModels, iOS 26+) as primary engine.
// Falls back to Vision OCR + rule-based parsing on older OS or unsupported devices.

struct RecognizedIngredient: Identifiable {
    let id = UUID()
    var name: String
    var quantity: String
    var unit: String
}

actor RecipeRecognitionService {
    static let shared = RecipeRecognitionService()

    func recognizeIngredients(from image: UIImage) async throws -> [RecognizedIngredient] {
        if #available(iOS 26, *) {
            if let results = try? await recognizeWithFoundationModels(image: image) {
                return results
            }
        }
        return try await recognizeWithVision(image: image)
    }

    // MARK: - Apple Intelligence (iOS 26+)

    @available(iOS 26, *)
    private func recognizeWithFoundationModels(image: UIImage) async throws -> [RecognizedIngredient]? {
        // FoundationModels framework usage
        // This requires import FoundationModels — gated at runtime to avoid compile issues on older SDK
        // Implementation added when FoundationModels is confirmed available in build environment
        return nil
    }

    // MARK: - Vision OCR fallback

    private func recognizeWithVision(image: UIImage) async throws -> [RecognizedIngredient] {
        guard let cgImage = image.cgImage else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let ingredients = Self.parseIngredients(from: lines)
                continuation.resume(returning: ingredients)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Ingredient parsing

    private static func parseIngredients(from lines: [String]) -> [RecognizedIngredient] {
        let unitPatterns = ["g", "kg", "ml", "l", "cl", "dl", "tbsp", "tsp", "el", "tl", "stück", "prise", "bund", "dose", "glas", "pkg", "pck"]
        var results: [RecognizedIngredient] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 1 else { continue }

            // Pattern: "200g Mehl", "2 Eier", "1 EL Öl", "Salz"
            let pattern = #"^(\d+[\.,]?\d*)\s*([a-zA-ZäöüÄÖÜß]*)\s+(.+)$"#
            if let match = trimmed.range(of: pattern, options: .regularExpression) {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let firstNum = Double(parts[0].replacingOccurrences(of: ",", with: ".")) {
                    let possibleUnit = parts.count > 2 ? parts[1].lowercased() : ""
                    let nameStart = unitPatterns.contains(possibleUnit) ? 2 : 1
                    let name = parts[nameStart...].joined(separator: " ")
                    let unit = unitPatterns.contains(possibleUnit) ? parts[1] : ""
                    results.append(RecognizedIngredient(
                        name: name,
                        quantity: "\(Int(firstNum))",
                        unit: unit
                    ))
                    continue
                }
                _ = match
            }

            // Fallback: treat whole line as ingredient name if it looks like a food word
            if !trimmed.first!.isNumber && trimmed.count > 2 {
                results.append(RecognizedIngredient(name: trimmed, quantity: "1", unit: ""))
            }
        }

        return results
    }
}
