import Foundation

struct NXMLink {
    let modId: Int
    let fileId: Int
    let key: String?
    let expires: String?
    let userId: String?

    init?(url: URL) {
        guard url.scheme == "nxm" else { return nil }

        // nxm://stardewvalley/mods/{modId}/files/{fileId}?key=...&expires=...&user_id=...
        let host = url.host ?? ""
        guard host == "stardewvalley" else { return nil }

        let segments = url.pathComponents.filter { $0 != "/" }
        // segments: ["mods", "{modId}", "files", "{fileId}"]
        guard segments.count >= 4,
              segments[0] == "mods",
              let modId = Int(segments[1]),
              segments[2] == "files",
              let fileId = Int(segments[3]) else {
            return nil
        }

        self.modId = modId
        self.fileId = fileId

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        self.key = queryItems.first(where: { $0.name == "key" })?.value
        self.expires = queryItems.first(where: { $0.name == "expires" })?.value
        self.userId = queryItems.first(where: { $0.name == "user_id" })?.value
    }
}
