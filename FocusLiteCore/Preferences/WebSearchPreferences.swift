import Foundation

enum WebSearchEngine: String, CaseIterable, Codable {
    case google
    case bing
    case baidu
    case systemDefault
    case custom

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .baidu: return "百度"
        case .systemDefault: return "跟随浏览器默认"
        case .custom: return "自定义"
        }
    }

    var defaultTemplate: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q={query}"
        case .bing:
            return "https://www.bing.com/search?q={query}"
        case .baidu:
            return "https://www.baidu.com/s?wd={query}"
        case .systemDefault:
            return "https://www.google.com/search?q={query}"
        case .custom:
            return "https://www.google.com/search?q={query}"
        }
    }
}

enum WebSearchPreferences {
    private static let enabledKey = "webSearch.enabled"
    private static let engineKey = "webSearch.engine"
    private static let templateKey = "webSearch.template"
    private static let showFallbackKey = "webSearch.showFallback"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var engine: WebSearchEngine {
        get {
            guard let raw = UserDefaults.standard.string(forKey: engineKey),
                  let parsed = WebSearchEngine(rawValue: raw) else {
                return .google
            }
            return parsed
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: engineKey)
            if newValue != .custom {
                UserDefaults.standard.set(newValue.defaultTemplate, forKey: templateKey)
            }
        }
    }

    static var customTemplate: String {
        get {
            let stored = UserDefaults.standard.string(forKey: templateKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stored?.isEmpty == false ? stored! : engine.defaultTemplate
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(
                trimmed.isEmpty ? engine.defaultTemplate : trimmed,
                forKey: templateKey
            )
        }
    }

    static var showFallback: Bool {
        get { UserDefaults.standard.object(forKey: showFallbackKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showFallbackKey) }
    }

    static func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let template = resolvedTemplate()
        if template.contains("{query}") {
            return URL(string: template.replacingOccurrences(of: "{query}", with: encoded))
        }
        if template.contains("%@") {
            return URL(string: String(format: template, encoded))
        }
        let separator = template.contains("?") ? "&" : "?"
        return URL(string: "\(template)\(separator)q=\(encoded)")
    }

    private static func resolvedTemplate() -> String {
        if engine == .custom {
            return customTemplate
        }
        if engine == .systemDefault {
            // system default browser search fallback
            return WebSearchEngine.google.defaultTemplate
        }
        return engine.defaultTemplate
    }
}
