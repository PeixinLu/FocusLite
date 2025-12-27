import Foundation

struct PrefixEntry: Equatable {
    let id: String
    let providerID: String
    let title: String
    let subtitle: String?
    let icon: ItemIcon?
}

enum PrefixRegistry {
    static func entries() -> [PrefixEntry] {
        [
            clipboardEntry(),
            snippetsEntry(),
            translateEntry()
        ].compactMap { $0 }
    }

    private static func clipboardEntry() -> PrefixEntry? {
        let prefix = ClipboardPreferences.searchPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return nil }
        return PrefixEntry(
            id: prefix.lowercased(),
            providerID: ClipboardProvider.providerID,
            title: prefix,
            subtitle: "Clipboard",
            icon: .system("doc.on.clipboard")
        )
    }

    private static func snippetsEntry() -> PrefixEntry? {
        let prefix = SnippetsPreferences.searchPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return nil }
        return PrefixEntry(
            id: prefix.lowercased(),
            providerID: SnippetsProvider.providerID,
            title: prefix,
            subtitle: "Snippets",
            icon: .system("text.append")
        )
    }

    private static func translateEntry() -> PrefixEntry? {
        let prefix = "tr"
        return PrefixEntry(
            id: prefix,
            providerID: TranslateProvider.providerID,
            title: prefix,
            subtitle: "Translate",
            icon: .system("globe")
        )
    }
}
