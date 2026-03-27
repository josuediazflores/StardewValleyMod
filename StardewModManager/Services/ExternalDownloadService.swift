import Foundation

actor ExternalDownloadService {

    enum URLType {
        case directZIP
        case googleDrive
        case nexusCollection
        case unknown
    }

    enum DownloadError: LocalizedError {
        case invalidURL
        case downloadFailed(String)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The URL is invalid."
            case .downloadFailed(let msg): return "Download failed: \(msg)"
            case .unsupportedFormat: return "The file format is not supported."
            }
        }
    }

    // MARK: - URL Detection

    static func detectURLType(_ urlString: String) -> URLType {
        let lowered = urlString.lowercased()

        if lowered.contains("drive.google.com") {
            return .googleDrive
        }

        if lowered.contains("nexusmods.com") && lowered.contains("collection") {
            return .nexusCollection
        }

        if lowered.hasSuffix(".zip") || lowered.hasSuffix(".7z") || lowered.hasSuffix(".rar") {
            return .directZIP
        }

        // Check for archive in query parameters (e.g., download.php?file=mod.zip)
        if let url = URL(string: urlString),
           let query = url.query?.lowercased(),
           query.contains(".zip") || query.contains(".7z") || query.contains(".rar") {
            return .directZIP
        }

        return .unknown
    }

    // MARK: - Google Drive Transform

    static func transformGoogleDriveURL(_ urlString: String) -> String? {
        // Pattern: https://drive.google.com/file/d/{FILE_ID}/view...
        guard urlString.lowercased().contains("drive.google.com") else { return nil }

        guard let url = URL(string: urlString) else { return nil }
        let pathComponents = url.pathComponents

        // Find "d" component and the file ID following it
        guard let dIndex = pathComponents.firstIndex(of: "d"),
              dIndex + 1 < pathComponents.count else {
            return nil
        }

        let fileID = pathComponents[dIndex + 1]
        return "https://drive.google.com/uc?export=download&id=\(fileID)"
    }

    // MARK: - Download

    func downloadFile(from urlString: String, to destinationDir: URL) async throws -> URL {
        var effectiveURLString = urlString

        // Transform Google Drive URLs to direct download links
        if ExternalDownloadService.detectURLType(urlString) == .googleDrive {
            if let transformed = ExternalDownloadService.transformGoogleDriveURL(urlString) {
                effectiveURLString = transformed
            }
        }

        guard let url = URL(string: effectiveURLString) else {
            throw DownloadError.invalidURL
        }

        let fm = FileManager.default
        if !fm.fileExists(atPath: destinationDir.path(percentEncoded: false)) {
            try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        }

        let (tempFileURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw DownloadError.downloadFailed("Server returned status code \(statusCode)")
        }

        // Determine the file name from the response or URL
        let fileName = suggestedFileName(from: httpResponse, requestURL: url)
        let destinationURL = destinationDir.appending(path: fileName)

        // Remove existing file if present
        if fm.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            try fm.removeItem(at: destinationURL)
        }

        try fm.moveItem(at: tempFileURL, to: destinationURL)
        return destinationURL
    }

    // MARK: - Helpers

    private func suggestedFileName(from response: HTTPURLResponse, requestURL: URL) -> String {
        // Try Content-Disposition header first
        if let disposition = response.value(forHTTPHeaderField: "Content-Disposition") {
            if let range = disposition.range(of: "filename=\""),
               let endRange = disposition[range.upperBound...].range(of: "\"") {
                let name = String(disposition[range.upperBound..<endRange.lowerBound])
                if !name.isEmpty { return name }
            }
            if let range = disposition.range(of: "filename=") {
                let startIndex = range.upperBound
                let remaining = disposition[startIndex...]
                let name = remaining.split(separator: ";").first.map(String.init)?.trimmingCharacters(in: .whitespaces)
                if let name, !name.isEmpty { return name }
            }
        }

        // Try the suggested filename from the response
        if let suggested = response.suggestedFilename, !suggested.isEmpty {
            return suggested
        }

        // Fall back to the last path component of the URL
        let lastComponent = requestURL.lastPathComponent
        if !lastComponent.isEmpty && lastComponent != "/" {
            return lastComponent
        }

        return "download.zip"
    }
}
