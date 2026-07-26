import UIKit
import Vision

// Vision (VNImageRequestHandler) works on raw pixel buffers and knows nothing about
// UIImage.imageOrientation — without telling it the orientation explicitly, a portrait
// photo (whose pixels are usually stored landscape-rotated by the camera sensor, with
// iOS only tagging the rotation instead of physically rotating the pixels) gets read as
// sideways text and OCR fails silently. This mapping is Apple's standard sample-code
// pattern (there is no built-in UIImage.Orientation -> CGImagePropertyOrientation
// converter in the SDK). Lives in its own file (not folded into ReceiptScannerView.swift
// or RecipeRecognitionService.swift, where earlier copies of this same extension lived)
// so it can be given target membership in the Share Extension too, without pulling in
// either of those much larger, UI-/Apple-Intelligence-heavy files.
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

// MARK: - Real (non-cooperative) timeout

/// Thematisch unabhängig vom Rest dieser Datei (reine Nebeneinander-Ablage, kein inhaltlicher
/// Zusammenhang) — lebt hier statt in einer eigenen Datei, weil `ReceiptParserService.swift`s
/// `ReceiptNameAIResolver` sie braucht und dieser Ort bereits Ziel-Mitgliedschaft in BEIDEN
/// Targets (Haupt-App + Share Extension) hat, ohne eine weitere Datei extra registrieren zu
/// müssen. War ursprünglich in `RecipeRecognitionService.swift`, das für die Extension viel zu
/// viele weitere Abhängigkeiten (MenuPlanView, DesignSystem, SyncCoordinator, …) mitgezogen hätte.
///
/// A `TaskGroup`/`withThrowingTaskGroup` race does NOT actually bound a hanging `operation`:
/// per Swift's structured-concurrency contract, the group awaits ALL of its child tasks before
/// the enclosing `await withTaskGroup(...)` call itself returns — `cancelAll()` only sets a
/// cooperative flag that `operation` would have to check itself, it does not stop execution. This
/// was live-reproduced: a `withThrowingTaskGroup`-based 25s "timeout" race around a
/// `LanguageModelSession` call still hung for well over a minute with no result. Here, both
/// branches run as independent `Task.detached` work (NOT children of any group the caller has to
/// wait for) racing to resume a single continuation — whichever finishes first genuinely lets the
/// caller return; the loser keeps running orphaned in the background but blocks no one.
func withRealTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async -> T,
    onTimeout: @escaping @Sendable () -> T
) async -> T {
    await withCheckedContinuation { (continuation: CheckedContinuation<T, Never>) in
        let lock = NSLock()
        var didResume = false
        func resumeOnce(_ value: T) {
            lock.lock()
            let alreadyResumed = didResume
            didResume = true
            lock.unlock()
            guard !alreadyResumed else { return }
            continuation.resume(returning: value)
        }
        Task.detached {
            resumeOnce(await operation())
        }
        Task.detached {
            try? await Task.sleep(for: .seconds(seconds))
            resumeOnce(onTimeout())
        }
    }
}
