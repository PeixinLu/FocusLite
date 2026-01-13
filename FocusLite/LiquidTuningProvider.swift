import AppKit
import Foundation

struct LiquidTuningProvider: ResultProvider {
    static let providerID = "liquid.tuning"
    static let prefixEntry = PrefixEntry(
        id: "liquid",
        providerID: LiquidTuningProvider.providerID,
        title: "Liquid",
        subtitle: "调节液态玻璃效果",
        icon: .system("paintbrush")
    )

    var id: String { Self.providerID }
    var displayName: String { "Liquid Tuning" }

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        guard isScoped else { return [] }

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groups = LiquidTuningGroup.allCases
        let filtered = normalized.isEmpty ? groups : groups.filter { $0.matches(query: normalized) }

        return filtered.enumerated().map { index, group in
            ResultItem(
                title: group.title,
                subtitle: group.subtitle,
                icon: .system(group.iconName),
                score: 1.0 - Double(index) * 0.05,
                action: .none,
                providerID: Self.providerID,
                category: .standard,
                preview: nil
            )
        }
    }
}

enum LiquidTuningGroup: CaseIterable {
    case search
    case rows
    case animation

    var title: String {
        switch self {
        case .search: return "搜索框外观"
        case .rows: return "候选项外观"
        case .animation: return "过渡动画"
        }
    }

    var subtitle: String {
        switch self {
        case .search: return "风格 / 色调 / 圆角"
        case .rows: return "候选项风格"
        case .animation: return "候选项过渡速度"
        }
    }

    var iconName: String {
        switch self {
        case .search: return "magnifyingglass.circle"
        case .rows: return "list.bullet.rectangle"
        case .animation: return "sparkles"
        }
    }

    func matches(query: String) -> Bool {
        let haystack = (title + subtitle).lowercased()
        return haystack.contains(query)
    }
}
