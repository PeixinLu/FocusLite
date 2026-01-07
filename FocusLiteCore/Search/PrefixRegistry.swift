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
            subtitle: "在剪贴板历史记录中搜索",
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
            subtitle: "在文本片段中搜索",
            icon: .system("text.append")
        )
    }

    private static func translateEntry() -> PrefixEntry? {
        let prefix = TranslatePreferences.searchPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return nil }
        return PrefixEntry(
            id: prefix.lowercased(),
            providerID: TranslateProvider.providerID,
            title: prefix,
            subtitle: "翻译文本",
            icon: .system("globe")
        )
    }
}
