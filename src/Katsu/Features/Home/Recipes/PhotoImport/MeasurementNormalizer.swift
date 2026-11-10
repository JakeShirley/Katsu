import Foundation
import NaturalLanguage

/// Rewrites the measurement shorthand common on handwritten and printed
/// recipe cards into unambiguous units Mealie's ingredient parser
/// understands, and repairs spacing that OCR loses in handwriting.
///
/// Capitalization is significant: `T.` is a tablespoon and `t.` a teaspoon.
enum MeasurementNormalizer {
    /// A quantity: `2`, `1.5`, `1/2`, `1 1/2`, `½`, or `1½`.
    static let quantity = #"(?:\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?[½¼¾⅓⅔⅛⅜⅝⅞]?|[½¼¾⅓⅔⅛⅜⅝⅞])"#

    private static let tablespoon = #"(?:T|Tb|TB|Tbs|TBS|Tbsp|TBSP|Tbl|Tbls|tbs|tbsp|tbl|tbls|tblsp|tablesp)"#
    private static let teaspoon = #"(?:t|ts|tsp|Tsp|TSP|teasp)"#
    private static let unitWords = #"(?:teaspoons?|tablespoons?|cups?|ounces?|pounds?|pints?|quarts?|gallons?|grams?|kilograms?|milliliters?|liters?|sticks?|cans?|packages?|cloves?|pinch|dash)"#
    private static let unitAbbreviations = #"(?:tsp|tbsp|cup|oz|lb|pt|qt|gal|g|kg|ml|l|pkg)"#
    /// Unit following a quantity, used to recognise a second ingredient on a line.
    static let unit = "(?:\(unitWords)|\(unitAbbreviations))"

    /// The shorthand rules are English conventions (in Spanish, "c." is a
    /// tablespoon), so only apply them to English or undetermined text.
    static func applies(to recognizedText: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(recognizedText)
        guard let language = recognizer.dominantLanguage else { return true }
        return language == .english
    }

    /// Normalizes one ingredient line.
    static func normalizeIngredient(_ line: String) -> String {
        var text = line

        // OCR reads a handwritten 1 as I, l, or | before a unit: "It." → "1t.".
        text = replace(#"(?<![\w/])[Il|](?=\s*(?:[Tt]|[Cc])\.)"#, in: text, with: "1")
        text = replace(#"(?<![\w/])[Il|](?=\s+(?:tsp|tbsp|cups?|teaspoons?|tablespoons?)\b)"#, in: text, with: "1")

        // Space out quantities and ranges run into words: "5to7apples" → "5 to 7 apples".
        text = replace(#"(?<=[\d½¼¾⅓⅔⅛⅜⅝⅞])(?=[A-Za-z])"#, in: text, with: " ")
        text = replace(#"\b(to|or)(?=\d)"#, in: text, with: "$1 ")

        text = expandShorthand(in: text, allowBareLetters: true)

        // Unit words run into the ingredient: "teaspoonsalt" → "teaspoon salt".
        text = separateGluedUnitWords(in: text)
        text = replace("(\\b\(quantity) )(tsp|tbsp|oz|lb)(?=[a-z]{3,})", in: text, with: "$1$2 ")

        return collapseWhitespace(text)
    }

    /// Normalizes shorthand inside instruction prose, e.g. "Put the 2T. butter
    /// on top". Bare letters without a period are left alone so temperatures
    /// such as "180 C" aren't mistaken for cups.
    static func normalizeStep(_ step: String) -> String {
        collapseWhitespace(expandShorthand(in: step, allowBareLetters: false))
    }

    /// Splits a line holding two ingredients side by side, as OCR reads
    /// two-column recipe cards: "5 to 7 apples 1 tsp cinnamon".
    static func splitColumns(_ line: String) -> [String] {
        // Only quantity-first lines are split, so name-first lines such as
        // "Butter 2 tbsp" stay intact.
        guard matches("^\(quantity)\\s", line) else { return [line] }
        let pattern = "(?<=[\\p{L}.)])\\s+(?=\(quantity)\\s*(?:\(unit)\\b|\\s+\\p{L}{3,}))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [line] }
        let ns = line as NSString
        let connectors: Set<String> = ["to", "or", "and", "plus", "x", "about", "of", "minus", "&"]

        for match in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            let before = ns.substring(to: match.range.location)
            let lastWord = before.split(whereSeparator: \.isWhitespace).last.map { $0.lowercased() } ?? ""
            guard !connectors.contains(lastWord), before.trimmingCharacters(in: .whitespaces).count >= 2 else { continue }
            let rest = ns.substring(from: match.range.location + match.range.length)
            return [before.trimmingCharacters(in: .whitespaces)] + splitColumns(rest)
        }
        return [line]
    }

    /// Whether `line` reads like an ingredient: it starts with a quantity or
    /// carries a quantity followed by a unit.
    static func looksLikeIngredient(_ line: String) -> Bool {
        let normalized = normalizeIngredient(line)
        return matches("^\(quantity)\\b", normalized)
            || matches("\(quantity)\\s*\(unit)\\b", normalized)
    }

    // MARK: - Helpers

    private static func expandShorthand(in text: String, allowBareLetters: Bool) -> String {
        let end = #"(?=[\s,;:)]|$)"#
        var text = text
        if allowBareLetters {
            text = replace("(\(quantity))\\s*\(tablespoon)\\.?\(end)", in: text, with: "$1 tbsp")
            text = replace("(\(quantity))\\s*\(teaspoon)\\.?\(end)", in: text, with: "$1 tsp")
            text = replace("(\(quantity))\\s*[cC]\\.?\(end)", in: text, with: "$1 cup")
        } else {
            text = replace("(\(quantity))\\s*(?:T|Tb|Tbs|tbs|tbl)\\.\(end)", in: text, with: "$1 tbsp")
            text = replace("(\(quantity))\\s*(?:t|ts|tsp)\\.\(end)", in: text, with: "$1 tsp")
            text = replace("(\(quantity))\\s*(?:Tbsp|TBSP|tbsp)\\.?\(end)", in: text, with: "$1 tbsp")
        }
        text = replace("(\(quantity))\\s*lbs?\\.?\(end)", in: text, with: "$1 lb")
        text = replace("(\(quantity))\\s*oz\\.\(end)", in: text, with: "$1 oz")
        text = replace("(\(quantity))\\s*(pt|qt|gal|pkg)\\.\(end)", in: text, with: "$1 $2")
        return text
    }

    /// Inserts the missing space after a unit word that OCR joined to the
    /// next word. "cupsugar" splits as "cup sugar" because a vowel follows the
    /// "s"; "cupsflour" splits as "cups flour".
    private static func separateGluedUnitWords(in text: String) -> String {
        let pattern = "(\(quantity)\\s+)(teaspoon|tablespoon|cup|ounce|pound)([A-Za-z]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: text),
                  let prefixRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let restRange = Range(match.range(at: 3), in: text) else { continue }
            let unit = String(text[unitRange])
            var rest = String(text[restRange])
            var plural = ""
            if rest.first == "s" {
                let afterS = rest.dropFirst().first
                let followedByVowel = afterS.map { "aeiou".contains($0.lowercased()) } ?? false
                if rest.count == 1 || !followedByVowel {
                    plural = "s"
                    rest.removeFirst()
                }
            }
            let replacement = rest.isEmpty
                ? "\(text[prefixRange])\(unit)\(plural)"
                : "\(text[prefixRange])\(unit)\(plural) \(rest)"
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
    }
}

extension RecipeDraft {
    /// Standardizes measurement shorthand in ingredients and steps.
    mutating func standardizeMeasurements() {
        for index in ingredients.indices {
            ingredients[index].text = MeasurementNormalizer.normalizeIngredient(ingredients[index].text)
        }
        for index in steps.indices {
            steps[index].text = MeasurementNormalizer.normalizeStep(steps[index].text)
        }
    }
}
