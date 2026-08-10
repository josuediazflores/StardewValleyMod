import Foundation

enum LenientJSONDecoder {
    /// Strips C-style comments and trailing commas from JSON, then decodes.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard var jsonString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Could not read data as UTF-8")
            )
        }

        // Strip BOM
        if jsonString.hasPrefix("\u{FEFF}") {
            jsonString = String(jsonString.dropFirst())
        }

        // Strip block comments /* ... */
        jsonString = jsonString.replacingOccurrences(
            of: #"/\*[\s\S]*?\*/"#,
            with: "",
            options: .regularExpression
        )

        // Strip line comments // ... (but not inside strings)
        // Simple approach: remove // comments that appear after common JSON constructs
        jsonString = jsonString.replacingOccurrences(
            of: #"(?<=^|\n)\s*//[^\n]*"#,
            with: "",
            options: .regularExpression
        )
        // Also handle inline // comments after values
        jsonString = jsonString.replacingOccurrences(
            of: #"(?<=,|{|\[)\s*//[^\n]*"#,
            with: "",
            options: .regularExpression
        )

        // Remove trailing commas before } or ]
        jsonString = jsonString.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )

        guard let cleanedData = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Could not re-encode cleaned JSON")
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: cleanedData)
    }
}
