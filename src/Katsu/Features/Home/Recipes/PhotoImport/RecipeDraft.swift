import Foundation

/// Editable recipe produced on-device from photos before it is sent to
/// Mealie. Encodes to a schema.org `Recipe` JSON-LD object so Mealie's own
/// scraper (`POST /api/recipes/create/html-or-json`) can import it without a
/// server-side AI provider.
struct RecipeDraft: Equatable {
    struct Line: Identifiable, Equatable {
        let id: UUID
        var text: String

        init(id: UUID = UUID(), text: String) {
            self.id = id
            self.text = text
        }
    }

    var name: String = ""
    var summary: String = ""
    var recipeYield: String = ""
    var prepMinutes: Int?
    var cookMinutes: Int?
    var totalMinutes: Int?
    var ingredients: [Line] = []
    var steps: [Line] = []
    var notes: String = ""

    var trimmedIngredients: [String] {
        ingredients.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var trimmedSteps: [String] {
        steps.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var isImportable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!trimmedIngredients.isEmpty || !trimmedSteps.isEmpty)
    }

    /// schema.org `Recipe` JSON string understood by Mealie's scraper.
    func schemaOrgJSON() throws -> String {
        var object: [String: Any] = [
            "@context": "https://schema.org",
            "@type": "Recipe",
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "recipeIngredient": trimmedIngredients,
            "recipeInstructions": trimmedSteps.map { ["@type": "HowToStep", "text": $0] },
        ]

        let description = [summary, notes]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        if !description.isEmpty {
            object["description"] = description
        }
        let trimmedYield = recipeYield.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedYield.isEmpty {
            object["recipeYield"] = trimmedYield
        }
        if let prepMinutes, prepMinutes > 0 {
            object["prepTime"] = Self.isoDuration(minutes: prepMinutes)
        }
        if let cookMinutes, cookMinutes > 0 {
            object["cookTime"] = Self.isoDuration(minutes: cookMinutes)
        }
        if let total = totalMinutes ?? Self.sum(prepMinutes, cookMinutes), total > 0 {
            object["totalTime"] = Self.isoDuration(minutes: total)
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppError.unknown(String(localized: "The recipe could not be prepared for import."))
        }
        return json
    }

    static func isoDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _):
            return "PT\(remainder)M"
        case (_, 0):
            return "PT\(hours)H"
        default:
            return "PT\(hours)H\(remainder)M"
        }
    }

    private static func sum(_ lhs: Int?, _ rhs: Int?) -> Int? {
        guard let lhs, let rhs else { return nil }
        return lhs + rhs
    }
}

// MARK: - Heuristic parsing

extension RecipeDraft {
    /// Best-effort structure from raw OCR text, used when the on-device
    /// language model is unavailable. Looks for common ingredient and
    /// instruction headings in the languages Katsu ships.
    static func heuristic(from text: String, standardizingMeasurements: Bool = true) -> RecipeDraft {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }

        var draft = RecipeDraft()
        guard !lines.isEmpty else { return draft }

        let ingredientsIndex = lines.firstIndex { matchesHeading($0, ingredientHeadings) }
        let stepsIndex = lines.firstIndex { matchesHeading($0, instructionHeadings) }

        var headerLines: ArraySlice<String>
        var ingredientLines: ArraySlice<String> = []
        var stepLines: ArraySlice<String> = []

        switch (ingredientsIndex, stepsIndex) {
        case let (ingredients?, steps?) where ingredients < steps:
            headerLines = lines[..<ingredients]
            ingredientLines = lines[(ingredients + 1)..<steps]
            stepLines = lines[(steps + 1)...]
        case let (ingredients?, steps?):
            headerLines = lines[..<steps]
            stepLines = lines[(steps + 1)..<ingredients]
            ingredientLines = lines[(ingredients + 1)...]
        case let (ingredients?, nil):
            headerLines = lines[..<ingredients]
            let remainder = lines[(ingredients + 1)...]
            let firstStep = remainder.firstIndex { isLikelyStep($0) } ?? remainder.endIndex
            ingredientLines = remainder[..<firstStep]
            stepLines = remainder[firstStep...]
        case let (nil, steps?):
            headerLines = lines[..<steps]
            stepLines = lines[(steps + 1)...]
        case (nil, nil):
            // Cards without headings: measurement lines are ingredients and
            // the prose that follows them is the method.
            if let first = lines.indices.dropFirst().first(where: { MeasurementNormalizer.looksLikeIngredient(lines[$0]) }) {
                let proseStart = lines[first...].firstIndex { isLikelyProse($0) } ?? lines.endIndex
                headerLines = lines[..<first]
                ingredientLines = lines[first..<proseStart]
                stepLines = lines[proseStart...]
            } else {
                headerLines = lines[...]
            }
        }

        if let title = headerLines.first {
            draft.name = title
            headerLines = headerLines.dropFirst()
        }

        var summaryLines: [String] = []
        for line in headerLines {
            var isMetadata = false
            if draft.recipeYield.isEmpty, let yield = yieldValue(in: line) {
                draft.recipeYield = yield
                isMetadata = true
            }
            if draft.prepMinutes == nil, let minutes = minutes(in: line, after: prepLabels) {
                draft.prepMinutes = minutes
                isMetadata = true
            }
            if draft.cookMinutes == nil, let minutes = minutes(in: line, after: cookLabels) {
                draft.cookMinutes = minutes
                isMetadata = true
            }
            if draft.totalMinutes == nil, let minutes = minutes(in: line, after: totalLabels) {
                draft.totalMinutes = minutes
                isMetadata = true
            }
            if !isMetadata {
                summaryLines.append(line)
            }
        }
        draft.summary = summaryLines.joined(separator: " ")

        // A "Tip:" line starts a note that runs to the end of its section.
        var noteLines: [String] = []
        func splittingNotes(_ section: ArraySlice<String>) -> ArraySlice<String> {
            guard let start = section.firstIndex(where: { $0.firstMatch(of: noteMarker) != nil }) else { return section }
            noteLines += section[start...].map { $0.replacing(noteMarker, with: "") }
            return section[..<start]
        }
        ingredientLines = splittingNotes(ingredientLines)
        stepLines = splittingNotes(stepLines)

        draft.ingredients = ingredients(from: ingredientLines, standardizing: standardizingMeasurements).map { Line(text: $0) }
        draft.steps = groupSteps(Array(stepLines)).map { Line(text: $0) }
        draft.notes = noteLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return draft
    }

    private static let ingredientHeadings = ["ingredients", "ingredient", "you will need", "zutaten", "ingredientes", "材料"]
    private static let instructionHeadings = [
        "instructions", "directions", "method", "preparation", "steps", "how to make it",
        "zubereitung", "anleitung", "preparación", "elaboración", "instrucciones", "作り方", "手順",
    ]
    private static let prepLabels = ["prep", "vorbereitung", "arbeitszeit", "preparación", "下ごしらえ", "準備"]
    private static let cookLabels = ["cook", "bake", "kochzeit", "backzeit", "cocción", "調理"]
    private static let totalLabels = ["total", "ready in", "gesamt", "zubereitungszeit", "合計"]

    private static func matchesHeading(_ line: String, _ headings: [String]) -> Bool {
        let normalized = line
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ":：-–—").union(.whitespaces))
        return normalized.count <= 30 && headings.contains { normalized == $0 || normalized.hasPrefix($0 + " ") }
    }

    /// Cleans ingredient lines: rejoins short wrapped fragments ("pastry"
    /// under "1 recipe plain") and splits lines that hold two columns.
    private static func ingredients(from lines: ArraySlice<String>, standardizing: Bool) -> [String] {
        var merged: [String] = []
        for rawLine in lines {
            let line = stripBullet(rawLine)
            guard !line.isEmpty else { continue }
            let isFragment = !MeasurementNormalizer.looksLikeIngredient(line)
                && line.first?.isLowercase == true
                && line.split(separator: " ").count <= 3
            if isFragment, let last = merged.popLast() {
                merged.append(last + " " + line)
            } else {
                merged.append(line)
            }
        }
        let normalized = standardizing ? merged.map(MeasurementNormalizer.normalizeIngredient) : merged
        return normalized
            .flatMap(MeasurementNormalizer.splitColumns)
            .filter { !$0.isEmpty }
    }

    private static func isLikelyProse(_ line: String) -> Bool {
        guard let last = line.last else { return false }
        if ".!?。".contains(last), line.first?.isNumber != true {
            return true
        }
        return line.split(separator: " ").count >= 7 && !MeasurementNormalizer.looksLikeIngredient(line)
    }

    private static func isLikelyStep(_ line: String) -> Bool {
        line.firstMatch(of: stepMarker) != nil && line.count > 40
    }

    private static func stripBullet(_ line: String) -> String {
        line.replacing(bulletMarker, with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Joins OCR lines that wrap mid-sentence into whole steps. Numbered
    /// markers start a new step; otherwise a terminal period does.
    private static func groupSteps(_ lines: [String]) -> [String] {
        let hasMarkers = lines.contains { $0.firstMatch(of: stepMarker) != nil }
        var steps: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { steps.append(trimmed) }
            current = ""
        }

        for rawLine in lines {
            let line = stripBullet(rawLine)
            if hasMarkers, line.firstMatch(of: stepMarker) != nil {
                flush()
                current = line.replacing(stepMarker, with: "")
                continue
            }
            current += current.isEmpty ? line : " " + line
            if !hasMarkers, let last = line.last, ".!?。".contains(last) {
                flush()
            }
        }
        flush()
        return steps
    }

    private static let metadataLineLimit = 80

    /// Servings text after a yield label, stopping before any time label that
    /// shares the line (e.g. "Serves 4   Prep: 10 min").
    private static func yieldValue(in line: String) -> String? {
        guard line.count <= metadataLineLimit, let match = line.firstMatch(of: yieldPattern) else { return nil }
        var value = Substring(match.output.1)
        let timeLabels = prepLabels + cookLabels + totalLabels
        if let cut = timeLabels.compactMap({ value.range(of: $0, options: .caseInsensitive)?.lowerBound }).min() {
            value = value[..<cut]
        }
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: ",;|·•").union(.whitespaces))
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Minutes in a duration that directly follows one of `labels`, as in
    /// "Prep: 10 min" or "Cook time 1 hr 15 min". Prose such as "Bake at
    /// 350° for 40 minutes" doesn't count.
    private static func minutes(in line: String, after labels: [String]) -> Int? {
        guard line.count <= metadataLineLimit else { return nil }
        for label in labels {
            guard let range = line.range(of: label, options: .caseInsensitive) else { continue }
            if range.lowerBound > line.startIndex, line[line.index(before: range.lowerBound)].isLetter {
                continue
            }
            var rest = line[range.upperBound...].drop(while: \.isLetter)
            rest = rest.drop(while: \.isWhitespace)
            for word in ["time", "zeit", "tiempo", "時間"] where rest.lowercased().hasPrefix(word) {
                rest = rest.dropFirst(word.count)
            }
            rest = rest.drop(while: { $0.isWhitespace || ":：-–".contains($0) })
            guard let match = rest.prefixMatch(of: durationPattern) else { continue }
            let hours = match.output.1.flatMap { Int($0) } ?? 0
            let minutes = match.output.2.flatMap { Int($0) } ?? 0
            let total = hours * 60 + minutes
            if total > 0 { return total }
        }
        return nil
    }

    /// Prep, cook, and total times the source labels explicitly, anywhere on
    /// the page.
    static func labeledTimes(in text: String) -> (prep: Int?, cook: Int?, total: Int?) {
        var times: (prep: Int?, cook: Int?, total: Int?) = (nil, nil, nil)
        for line in text.components(separatedBy: .newlines) {
            times.prep = times.prep ?? minutes(in: line, after: prepLabels)
            times.cook = times.cook ?? minutes(in: line, after: cookLabels)
            times.total = times.total ?? minutes(in: line, after: totalLabels)
        }
        return times
    }

    static func hasYieldLabel(in text: String) -> Bool {
        text.contains(yieldLabelPattern)
    }

    /// Drops model output the source doesn't support: times and servings
    /// without a label on the page, and a description that only repeats the
    /// method.
    func grounded(in recognizedText: String) -> RecipeDraft {
        var draft = self
        let times = Self.labeledTimes(in: recognizedText)
        draft.prepMinutes = times.prep
        draft.cookMinutes = times.cook
        draft.totalMinutes = times.total
        if !Self.hasYieldLabel(in: recognizedText) {
            draft.recipeYield = ""
        }
        if Self.mostlyRepeats(draft.summary, of: draft.steps.map(\.text).joined(separator: " ")) {
            draft.summary = ""
        }
        return draft
    }

    private static func mostlyRepeats(_ text: String, of source: String) -> Bool {
        func words(_ value: String) -> Set<String> {
            Set(value.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 3 })
        }
        let textWords = words(text)
        guard textWords.count >= 4 else { return false }
        let shared = textWords.intersection(words(source))
        return Double(shared.count) / Double(textWords.count) >= 0.6
    }

    private static var stepMarker: Regex<Substring> {
        #/^(?i:step\s*)?\d{1,2}\s*[.):]\s*/#
    }

    private static var noteMarker: Regex<Substring> {
        #/^(?i:tips?|notes?|cook's note|tipps?|hinweis|consejos?|notas?|ポイント|メモ|コツ)\s*[:：]\s*/#
    }

    private static var bulletMarker: Regex<Substring> {
        #/^[•·\-–—*▪◦●○]\s*/#
    }

    private static var yieldPattern: Regex<(Substring, Substring)> {
        #/^(?i:serves|servings|makes|yields|yield|portionen|für|raciones|porciones|rinde)\s*:?\s*(.+)$/#
    }

    private static var yieldLabelPattern: Regex<Substring> {
        #/(?i:\b(?:serves|servings|makes|yields?|portions?|portionen|personen|raciones|porciones|rinde)\b|人分|人前)/#
    }

    private static var durationPattern: Regex<(Substring, Substring?, Substring?)> {
        #/(?i:(\d+)\s*(?:hours|hour|hrs|hr|h|stunden|stunde|std|horas|hora|時間)\.?\s*)?(?i:(\d+)\s*(?:minuten|minutes|minute|minutos|minuto|mins|min|m|分))?/#
    }
}
