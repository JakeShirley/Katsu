import CoreGraphics
import Foundation
import Vision

/// On-device OCR for recipe photos. Prefers Vision's document recognizer,
/// which keeps reading order across columns and lists, and falls back to
/// line-level text recognition when it fails.
enum RecipeTextRecognizer {
    static func recognizeText(in images: [CGImage]) async throws -> String {
        var pages: [String] = []
        for image in images {
            try Task.checkCancellation()
            let page = try await recognizeText(in: image)
            if !page.isEmpty {
                pages.append(page)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    private static func recognizeText(in image: CGImage) async throws -> String {
        if let document = try? await recognizeDocument(in: image), !document.isEmpty {
            return document
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image)
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func recognizeDocument(in image: CGImage) async throws -> String {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.automaticallyDetectLanguage = true
        let documents = try await request.perform(on: image)
        return documents
            .map { $0.document.text.transcript }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
