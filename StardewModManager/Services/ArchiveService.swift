import Foundation

enum ArchiveError: LocalizedError {
    case extractionFailed(String)
    case unsafeEntry(String)
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let msg): return "Failed to extract archive: \(msg)"
        case .unsafeEntry(let entry): return "Archive contains an unsafe entry: \(entry)"
        case .tooLarge: return "Archive is too large to extract safely."
        }
    }
}

/// Shared, validated extractor for UNTRUSTED archives. Wraps `/usr/bin/ditto -xk`
/// and then post-checks the extracted tree for symlink / path-traversal (zip-slip)
/// escapes and zip-bomb size before returning, so callers never operate on hostile
/// contents. Only use this for archives from outside the app; trusted local data
/// compressed by the app (ditto -c -k) does not need it.
enum ArchiveService {
    /// Cap on the number of extracted entries (zip-bomb guard).
    private static let maxEntryCount = 50_000
    /// Cap on total uncompressed size in bytes (zip-bomb guard): 5 GB.
    private static let maxTotalBytes: Int64 = 5 * 1024 * 1024 * 1024

    /// Extract `zip` into `dir` and validate the result. Throws `ArchiveError` if
    /// extraction fails, if any entry is a symlink or escapes `dir`, or if the
    /// entry count / total size caps are exceeded. Synchronous by design.
    static func extract(_ zip: URL, to dir: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-xk", zip.path(percentEncoded: false), dir.path(percentEncoded: false)]

        do {
            try process.run()
        } catch {
            throw ArchiveError.extractionFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ArchiveError.extractionFailed("ditto returned exit code \(process.terminationStatus)")
        }

        try validateExtractedContents(of: dir)
    }

    /// Recursively walk `dir`, rejecting any symlink and any entry whose resolved,
    /// standardized path is not contained within `dir`, and enforcing the zip-bomb
    /// entry-count / total-size caps.
    private static func validateExtractedContents(of dir: URL) throws {
        let fm = FileManager.default
        // resolvingSymlinksInPath() yields a directory path that may carry a trailing
        // slash; strip it before appending one, or baseWithSlash ends in "//" and no
        // legitimate child clears the hasPrefix check (rejecting every entry).
        var basePath = dir.resolvingSymlinksInPath().standardized.path(percentEncoded: false)
        while basePath.hasSuffix("/") { basePath.removeLast() }
        let baseWithSlash = basePath + "/"

        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            throw ArchiveError.extractionFailed("Could not enumerate extracted contents")
        }

        var entryCount = 0
        var totalBytes: Int64 = 0

        for case let fileURL as URL in enumerator {
            entryCount += 1
            if entryCount > maxEntryCount {
                throw ArchiveError.tooLarge
            }

            // Fail closed: an entry whose metadata cannot be read is treated as unsafe.
            let values: URLResourceValues
            do {
                values = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            } catch {
                throw ArchiveError.unsafeEntry(fileURL.lastPathComponent)
            }

            // Reject every symlink — a symlink can point outside the extraction dir,
            // and a later entry could be written "through" it.
            if values.isSymbolicLink == true {
                throw ArchiveError.unsafeEntry(fileURL.lastPathComponent)
            }

            // Reject any entry that resolves outside the extraction directory (zip-slip).
            let resolved = fileURL.resolvingSymlinksInPath().standardized.path(percentEncoded: false)
            if !resolved.hasPrefix(baseWithSlash) {
                throw ArchiveError.unsafeEntry(fileURL.lastPathComponent)
            }

            if values.isRegularFile == true, let size = values.fileSize {
                totalBytes += Int64(size)
                if totalBytes > maxTotalBytes {
                    throw ArchiveError.tooLarge
                }
            }
        }
    }
}
