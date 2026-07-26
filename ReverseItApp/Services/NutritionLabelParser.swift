import Foundation

/// Nutrition values extracted from a scanned label.
///
/// Every field is optional because a label may omit a value, and an omitted value must
/// never be reported as zero — the difference matters when the form decides whether to
/// keep auto-calculating calories from macros.
struct ScannedNutrition: Equatable, Sendable {
    var calories: Double?
    var carbs: Double?    // grams
    var protein: Double?  // grams
    var fat: Double?      // grams

    /// `true` when no nutrition field was recognized.
    var isEmpty: Bool {
        calories == nil && carbs == nil && protein == nil && fat == nil
    }
}

/// A pure, Vision-independent parser that turns already-extracted label text into
/// structured nutrition values.
///
/// It deliberately has no UIKit or Vision dependency so it can be unit tested without a
/// device or camera. `NutritionLabelScanner` performs the on-device OCR and feeds the
/// recognized rows here.
enum NutritionLabelParser {
    /// Parses flattened label rows, where each row is the ordered cells (or tokens) of a
    /// single line on the label.
    ///
    /// - Parameter rows: One entry per label line; each entry holds that line's cells.
    /// - Returns: The recognized nutrition values, with unrecognized fields left `nil`.
    static func parse(rows: [[String]]) -> ScannedNutrition {
        var result = ScannedNutrition()

        for row in rows {
            let label = row.joined(separator: " ")
            guard let field = field(for: label) else { continue }

            // First match wins per field so a total row is never overwritten by a later
            // sub-row that slipped past the keyword exclusions.
            switch field {
            case .calories where result.calories == nil:
                result.calories = value(in: row, for: .calories)
            case .fat where result.fat == nil:
                result.fat = value(in: row, for: .fat)
            case .carbs where result.carbs == nil:
                result.carbs = value(in: row, for: .carbs)
            case .protein where result.protein == nil:
                result.protein = value(in: row, for: .protein)
            default:
                continue
            }
        }

        return result
    }

    /// Convenience for line-based OCR: wraps each line as a single-cell row.
    static func parse(lines: [String]) -> ScannedNutrition {
        parse(rows: lines.map { [$0] })
    }

    // MARK: - Field classification

    private enum Field {
        case calories, fat, carbs, protein
    }

    /// Classifies a label line into a nutrition field, or `nil` if it is a sub-row,
    /// heading, or unrelated line. Matching is case-insensitive.
    private static func field(for label: String) -> Field? {
        let text = label.lowercased()

        // Ignore known sub-rows and headings outright, even though they contain a keyword.
        if text.contains("calories from fat") || text.contains("fat calories") { return nil }
        if text.contains("daily value") { return nil }

        if text.contains("calories") || text.contains("energy") { return .calories }

        // Total fat only — exclude the fatty-acid breakdown sub-rows.
        if text.contains("fat") {
            let fatSubRows = ["saturated", "trans", "polyunsaturated", "monounsaturated"]
            return fatSubRows.contains(where: text.contains) ? nil : .fat
        }

        // "carbohydrate" is unique to the total-carb row; fiber/sugars rows never contain it.
        if text.contains("carbohydrate") || text.contains("carbs") { return .carbs }

        if text.contains("protein") { return .protein }

        return nil
    }

    // MARK: - Numeric extraction

    private enum Unit {
        case grams, milligrams, micrograms, kilocalories, kilojoules, percent, none

        init(rawUnit: Substring?) {
            switch rawUnit?.lowercased() {
            case "g": self = .grams
            case "mg": self = .milligrams
            case "mcg": self = .micrograms
            case "kcal": self = .kilocalories
            case "kj": self = .kilojoules
            case "%": self = .percent
            default: self = .none
            }
        }
    }

    private struct NumericToken {
        let value: Double
        let unit: Unit
    }

    /// Extracts the value for a field from its row.
    ///
    /// Macros are reported in grams, so a gram-annotated number is preferred and `mg`/`mcg`
    /// values (sodium, cholesterol, vitamins) and `% Daily Value` numbers are ignored.
    /// Calories prefer a `kcal`-annotated or bare number and ignore `kJ`.
    ///
    /// When a row carries two value columns (per serving vs. per 100 g / per container),
    /// the first matching value is used — that is the per-serving figure the app records.
    private static func value(in row: [String], for field: Field) -> Double? {
        let tokens = numericTokens(in: row.joined(separator: " "))

        switch field {
        case .calories:
            if let kcal = tokens.first(where: { $0.unit == .kilocalories }) { return kcal.value }
            return tokens.first(where: { $0.unit == .none })?.value
        case .fat, .carbs, .protein:
            if let grams = tokens.first(where: { $0.unit == .grams }) { return grams.value }
            return tokens.first(where: { $0.unit == .none })?.value
        }
    }

    private static func numericTokens(in text: String) -> [NumericToken] {
        let pattern = /([0-9]+(?:\.[0-9]+)?)\s*(mcg|mg|kcal|kj|g|%)?/.ignoresCase()
        return text.matches(of: pattern).compactMap { match in
            guard let value = Double(match.1) else { return nil }
            return NumericToken(value: value, unit: Unit(rawUnit: match.2))
        }
    }
}
