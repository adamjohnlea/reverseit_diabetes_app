import Foundation
import Vision

/// Errors surfaced to the user when a nutrition-label scan can't produce values.
enum NutritionScanError: LocalizedError {
    /// Vision found no readable text in the image.
    case noTextFound
    /// Text was read, but none of it matched a nutrition field.
    case noNutritionFound

    var errorDescription: String? {
        switch self {
        case .noTextFound:
            return String(localized: "Couldn't read any text. Try again with the label in focus and well lit.")
        case .noNutritionFound:
            return String(localized: "No nutrition information found on this image.")
        }
    }
}

/// Runs on-device Vision document recognition over a nutrition-facts label and returns
/// the extracted values.
///
/// The Vision work is kept separate from `NutritionLabelParser` so the parsing logic stays
/// unit-testable without a device. This type only flattens the recognized document into
/// rows of strings and hands them to the parser.
enum NutritionLabelScanner {
    /// Scans the label image and extracts its nutrition values.
    ///
    /// - Parameter imageData: Encoded image data (JPEG or PNG) of the label.
    /// - Returns: The recognized nutrition values.
    /// - Throws: ``NutritionScanError`` when no text or no nutrition fields are found.
    static func scan(imageData: Data) async throws -> ScannedNutrition {
        let request = RecognizeDocumentsRequest()
        let observations = try await request.perform(on: imageData)

        guard let document = observations.first?.document else {
            throw NutritionScanError.noTextFound
        }

        // Prefer the structured table: each row becomes its ordered cell strings.
        var rows: [[String]] = document.tables.first.map { table in
            table.rows.map { row in row.map { $0.content.text.transcript } }
        } ?? []

        // If the label wasn't detected as a table, fall back — within this same recognition
        // result, not a second request — to the document's text split into lines.
        if rows.isEmpty {
            rows = document.text.transcript
                .split(whereSeparator: \.isNewline)
                .map { [String($0)] }
        }

        guard !rows.isEmpty else { throw NutritionScanError.noTextFound }

        let result = NutritionLabelParser.parse(rows: rows)
        guard !result.isEmpty else { throw NutritionScanError.noNutritionFound }

        return result
    }
}
