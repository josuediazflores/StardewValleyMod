import Foundation

enum ManifestParser {
    static func parse(at url: URL) -> ModManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? LenientJSONDecoder.decode(ModManifest.self, from: data)
    }
}
