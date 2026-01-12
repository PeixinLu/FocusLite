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
    case base
    case gradient
    case blur
    case animation

    var title: String {
        switch self {
        case .base: return "基础参数"
        case .gradient: return "高光与渐变"
        case .blur: return "额外模糊"
        case .animation: return "动画与过渡"
        }
    }

    var subtitle: String {
        switch self {
        case .base: return "风格 / Tint / 圆角"
        case .gradient: return "渐变"
        case .blur: return "清晰玻璃的额外模糊"
        case .animation: return "动画时长与交互节奏"
        }
    }

    var iconName: String {
        switch self {
        case .base: return "slider.horizontal.3"
        case .gradient: return "sun.max"
        case .blur: return "drop.degreesign"
        case .animation: return "sparkles"
        }
    }

    func matches(query: String) -> Bool {
        let haystack = (title + subtitle).lowercased()
        return haystack.contains(query)
    }
}

extension AppearancePreferences.ExtraBlurMaterial {
    var material: NSVisualEffectView.Material {
        switch self {
        case .system:
            return .hudWindow
        case .ultraThin:
            return .popover
        case .thin:
            return .menu
        case .regular:
            return .popover
        case .thick:
            return .sidebar
        case .ultraThick:
            return .headerView
        }
    }
}
