import Foundation

enum L {
    static func s(_ key: String) -> String {
        // A selected-language sub-bundle (e.g. de.lproj) has only one table and no fallback
        // chain, so a key missing from it returns the key itself (value: key). When that
        // happens, retry against en.lproj so the string degrades to English rather than
        // showing the raw key. (Proper translations of the missing keys are a separate task.)
        let bundle = Bundle.localizedAppBundle
        let value = bundle.localizedString(forKey: key, value: key, table: "Localizable")
        guard value == key, bundle !== Bundle.englishAppBundle else { return value }
        return Bundle.englishAppBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func s(_ key: String, _ args: CVarArg...) -> String {
        // Delegates to s(key), so the format string gets the same English fallback before
        // the arguments are applied.
        String(format: s(key), arguments: args)
    }

    // MARK: - Date Formatting

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func formatISO(_ isoString: String?) -> String? {
        guard let str = isoString else { return nil }
        let date = iso8601.date(from: str) ?? iso8601NoFrac.date(from: str)
        guard let date else { return nil }
        return relativeOrShort(date)
    }

    static func formatTimestamp(_ timestamp: Int?) -> String? {
        guard let ts = timestamp else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        return relativeOrShort(date)
    }

    private static func relativeOrShort(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 30 { return "\(days)d ago" }
        if days < 365 { return "\(days / 30)mo ago" }
        return shortDate.string(from: date)
    }
}
