import Foundation

enum L {
    static func s(_ key: String) -> String {
        Bundle.localizedAppBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func s(_ key: String, _ args: CVarArg...) -> String {
        String(format: s(key), arguments: args)
    }
}
