import CoreGraphics
import Foundation
import FoundationModels
import os

/// Shape the on-device model fills in through guided generation.
@Generable
struct GeneratedRecipe {
    @Guide(description: "The recipe title as printed")
    var name: String

    @Guide(description: "A sentence describing the dish itself, copied from the source, such as a headnote. Never put instructions here. Use an empty string when the source has no description")
    var summary: String

    @Guide(description: "Servings or yield only when the source labels it, such as \"Serves 4\" or \"Makes 24 cookies\". Otherwise an empty string")
    var recipeYield: String

    @Guide(description: "Preparation time in minutes only when the source labels it, such as \"Prep: 10 min\". Never estimate or add up times from the instructions; otherwise 0")
    var prepMinutes: Int

    @Guide(description: "Cooking time in minutes only when the source labels it, such as \"Cook time: 20 min\". Never estimate or add up times from the instructions; otherwise 0")
    var cookMinutes: Int

    @Guide(description: "Total time in minutes only when the source labels it, such as \"Total: 1 hr\". Never estimate or add up times; otherwise 0")
    var totalMinutes: Int

    @Guide(description: "Every ingredient in order, one per entry, keeping quantities and units as written. Ingredients printed side by side in columns are separate entries")
    var ingredients: [String]

    @Guide(description: "Every instruction step in order, one per entry, as complete sentences")
    var steps: [String]

    @Guide(description: "Tips, variations, or storage notes from the source, or an empty string")
    var notes: String
}

/// Structures OCR text (and, where supported, the photos themselves) into a
/// `RecipeDraft` with Apple's on-device foundation model. Nothing leaves the
/// device.
enum RecipeDraftGenerator {
    enum Availability: Equatable {
        case available
        case unavailable(reason: String)
    }

    /// Images beyond this are still OCR'd but not attached, to stay within
    /// the on-device context window.
    private static let maximumAttachedImages = 2

    private static let logger = Logger(subsystem: "org.odinseye.katsu", category: "PhotoImport")

    static var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable(reason: String(localized: "This device doesn't support Apple Intelligence."))
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(reason: String(localized: "Turn on Apple Intelligence in Settings to use on-device recipe reading."))
        case .unavailable(.modelNotReady):
            return .unavailable(reason: String(localized: "Apple Intelligence is still getting ready. Try again later."))
        case .unavailable:
            return .unavailable(reason: String(localized: "Apple Intelligence isn't available right now."))
        }
    }

    static var supportsImageInput: Bool {
        guard #available(iOS 27.0, *) else { return false }
        return SystemLanguageModel.default.capabilities.contains(.vision)
    }

    static func generate(text: String, images: [CGImage]) async throws -> RecipeDraft {
        if #available(iOS 27.0, *), supportsImageInput, !images.isEmpty {
            do {
                return try await generateWithImages(text: text, images: images)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Image input can exceed the context window; retry with text only.
                logger.error("Image-assisted recipe generation failed: \(String(describing: error), privacy: .public)")
            }
        }
        do {
            return try await generateFromText(text)
        } catch {
            logger.error("Recipe generation failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                return String(localized: "This recipe is too long for the on-device model.")
            case .unsupportedLanguageOrLocale:
                return String(localized: "The on-device model doesn't support this recipe's language yet.")
            case .guardrailViolation:
                return String(localized: "The on-device model declined to read this recipe.")
            default:
                break
            }
        }
        return String(localized: "The on-device model couldn't read this recipe.")
    }

    private static let instructions = """
    You turn text recognized from photos of a recipe into a structured recipe.
    Copy ingredient quantities, units, and names exactly; never invent \
    ingredients, steps, or times that aren't in the source.
    Fix obvious text recognition mistakes, such as "l cup" for "1 cup" or \
    broken fractions, separate words that handwriting ran together, such as \
    "cupsugar", and rejoin lines that were split by the page layout.
    Recipe cards often list ingredients in two columns; read each column as \
    its own ingredients.
    Keep measurement abbreviations with their original capitalization: "T." \
    means tablespoon and "t." means teaspoon.
    Ignore page numbers, headers, footers, advertisements, and text that \
    belongs to other recipes on the page.
    Leave a field empty rather than guessing; never move instructions into \
    the description.
    Keep the recipe in its original language.
    """

    private static var options: GenerationOptions {
        GenerationOptions(samplingMode: .greedy)
    }

    private static func generateFromText(_ text: String) async throws -> RecipeDraft {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: "Recognized recipe text:\n\n\(text)",
            generating: GeneratedRecipe.self,
            options: options
        )
        return RecipeDraft(response.content).grounded(in: text)
    }

    @available(iOS 27.0, *)
    private static func generateWithImages(text: String, images: [CGImage]) async throws -> RecipeDraft {
        let session = LanguageModelSession(instructions: instructions)
        let attachments = images.prefix(maximumAttachedImages).map { Attachment<ImageAttachmentContent>($0) }
        let response = try await session.respond(generating: GeneratedRecipe.self, options: options) {
            "Photos of the recipe follow, along with the text recognized from them. Use the photos to resolve layout and unclear text."
            for attachment in attachments {
                attachment
            }
            "Recognized recipe text:\n\n\(text)"
        }
        return RecipeDraft(response.content).grounded(in: text)
    }
}

extension RecipeDraft {
    init(_ generated: GeneratedRecipe) {
        self.init(
            name: generated.name,
            summary: generated.summary,
            recipeYield: generated.recipeYield,
            prepMinutes: generated.prepMinutes > 0 ? generated.prepMinutes : nil,
            cookMinutes: generated.cookMinutes > 0 ? generated.cookMinutes : nil,
            totalMinutes: generated.totalMinutes > 0 ? generated.totalMinutes : nil,
            ingredients: generated.ingredients.map { Line(text: $0) },
            steps: generated.steps.map { Line(text: $0) },
            notes: generated.notes
        )
    }
}
