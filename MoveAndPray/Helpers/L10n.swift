import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .autoupdatingCurrent, arguments: arguments)
    }

    static func plural(_ key: String, value: Int) -> String {
        String.localizedStringWithFormat(text(key), value)
    }

    static var usesRussian: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("ru") == true
    }
}
