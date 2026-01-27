import Foundation

struct TranslateProject: Codable, Hashable, Identifiable {
    let id: UUID
    var serviceID: String
    var primaryLanguage: String
    var secondaryLanguage: String
}

struct TranslateLanguageOption: Hashable {
    let code: String
    let name: String
}

enum TranslatePreferences {
    private static let targetModeKey = "translate.targetMode"
    private static let mixedPolicyKey = "translate.mixedPolicy"
    private static let prefixKey = "translate.prefix"
    private static let servicesKey = "translate.services"
    private static let projectsKey = "translate.projects"
    private static let youdaoAppKey = "translate.youdao.appKey"
    private static let youdaoSecret = "translate.youdao.secret"
    private static let baiduAppID = "translate.baidu.appID"
    private static let baiduSecret = "translate.baidu.secret"
    private static let googleAPIKey = "translate.google.apiKey"
    private static let bingAPIKey = "translate.bing.apiKey"
    private static let bingRegion = "translate.bing.region"
    private static let bingEndpoint = "translate.bing.endpoint"
    private static let deepseekAPIKey = "translate.deepseek.apiKey"
    private static let deepseekEndpoint = "translate.deepseek.endpoint"
    private static let deepseekModel = "translate.deepseek.model"
    private static let autoPasteKey = "translate.autoPasteAfterSelect"
    private static let hotKeyTextKey = "translate.hotKeyText"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    enum TargetMode: String {
        case auto
    }

    enum MixedTextPolicy: String {
        case auto
        case none
    }

    static var targetMode: TargetMode {
        get {
            let raw = UserDefaults.standard.string(forKey: targetModeKey)
            return TargetMode(rawValue: raw ?? TargetMode.auto.rawValue) ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: targetModeKey)
        }
    }

    static var mixedTextPolicy: MixedTextPolicy {
        get {
            let raw = UserDefaults.standard.string(forKey: mixedPolicyKey)
            return MixedTextPolicy(rawValue: raw ?? MixedTextPolicy.auto.rawValue) ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: mixedPolicyKey)
        }
    }

    static var searchPrefix: String {
        get { UserDefaults.standard.string(forKey: prefixKey) ?? "Ts" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: prefixKey) }
    }

    static var autoPasteAfterSelect: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPasteKey) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: autoPasteKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoPasteKey)
        }
    }

    static var hotKeyText: String {
        get { UserDefaults.standard.string(forKey: hotKeyTextKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: hotKeyTextKey) }
    }

    static var enabledServices: [String] {
        get {
            if let values = UserDefaults.standard.array(forKey: servicesKey) as? [String], !values.isEmpty {
                let cleaned = values.filter { TranslateServiceID(rawValue: $0) != nil }
                return cleaned
            }
            return [
                TranslateServiceID.deepseekAPI.rawValue,
                TranslateServiceID.youdaoAPI.rawValue,
                TranslateServiceID.baiduAPI.rawValue,
                TranslateServiceID.googleAPI.rawValue,
                TranslateServiceID.bingAPI.rawValue
            ]
        }
        set {
            let cleaned = newValue.filter { !$0.isEmpty }
            UserDefaults.standard.set(cleaned, forKey: servicesKey)
        }
    }

    static var languageOptions: [TranslateLanguageOption] {
        [
            TranslateLanguageOption(code: "zh-Hans", name: "中文（简体）"),
            TranslateLanguageOption(code: "en", name: "英语"),
            TranslateLanguageOption(code: "ja", name: "日语"),
            TranslateLanguageOption(code: "ko", name: "韩语"),
            TranslateLanguageOption(code: "fr", name: "法语"),
            TranslateLanguageOption(code: "de", name: "德语"),
            TranslateLanguageOption(code: "es", name: "西班牙语"),
            TranslateLanguageOption(code: "it", name: "意大利语"),
            TranslateLanguageOption(code: "pt", name: "葡萄牙语"),
            TranslateLanguageOption(code: "ru", name: "俄语"),
            TranslateLanguageOption(code: "th", name: "泰语"),
            TranslateLanguageOption(code: "vi", name: "越南语"),
            TranslateLanguageOption(code: "id", name: "印尼语")
        ]
    }

    static func displayName(for code: String) -> String {
        let normalized = code.lowercased()
        if let option = languageOptions.first(where: { $0.code.lowercased() == normalized }) {
            return option.name
        }
        return code
    }

    static func normalizedLanguageCode(_ code: String) -> String {
        let lower = code.lowercased()
        if lower.hasPrefix("zh") {
            return "zh"
        }
        if lower.hasPrefix("en") {
            return "en"
        }
        if let base = lower.split(separator: "-").first {
            return String(base)
        }
        return lower
    }

    static func projects() -> [TranslateProject] {
        if let data = UserDefaults.standard.data(forKey: projectsKey) {
            if let decoded = try? decoder.decode([TranslateProject].self, from: data) {
                return sanitizeProjects(decoded)
            }
        }
        let defaults = defaultProjects()
        saveProjects(defaults)
        return defaults
    }

    static func saveProjects(_ projects: [TranslateProject]) {
        let sanitized = sanitizeProjects(projects)
        guard let data = try? encoder.encode(sanitized) else { return }
        UserDefaults.standard.set(data, forKey: projectsKey)
    }

    static func defaultProject(for serviceID: TranslateServiceID) -> TranslateProject {
        TranslateProject(
            id: UUID(),
            serviceID: serviceID.rawValue,
            primaryLanguage: "zh-Hans",
            secondaryLanguage: "en"
        )
    }

    static func activeProjects() -> [TranslateProject] {
        let enabled = Set(enabledServices)
        return projects().filter { project in
            guard enabled.contains(project.serviceID),
                  let id = TranslateServiceID(rawValue: project.serviceID) else {
                return false
            }
            return isConfigured(serviceID: id)
        }
    }

    private static func defaultProjects() -> [TranslateProject] {
        let enabled = enabledServices.compactMap { TranslateServiceID(rawValue: $0) }
        return enabled.map { defaultProject(for: $0) }
    }

    private static func sanitizeProjects(_ projects: [TranslateProject]) -> [TranslateProject] {
        var cleaned: [TranslateProject] = []
        for project in projects {
            let primary = project.primaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
            let secondary = project.secondaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !project.serviceID.isEmpty,
                  TranslateServiceID(rawValue: project.serviceID) != nil,
                  !primary.isEmpty,
                  !secondary.isEmpty else { continue }
            if primary.caseInsensitiveCompare(secondary) == .orderedSame { continue }
            cleaned.append(TranslateProject(
                id: project.id,
                serviceID: project.serviceID,
                primaryLanguage: primary,
                secondaryLanguage: secondary
            ))
        }
        return cleaned
    }

    static var youdaoAppKeyValue: String {
        get { UserDefaults.standard.string(forKey: youdaoAppKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: youdaoAppKey) }
    }

    static var youdaoSecretValue: String {
        get { UserDefaults.standard.string(forKey: youdaoSecret) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: youdaoSecret) }
    }

    static var baiduAppIDValue: String {
        get { UserDefaults.standard.string(forKey: baiduAppID) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: baiduAppID) }
    }

    static var baiduSecretValue: String {
        get { UserDefaults.standard.string(forKey: baiduSecret) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: baiduSecret) }
    }

    static var googleAPIKeyValue: String {
        get { UserDefaults.standard.string(forKey: googleAPIKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: googleAPIKey) }
    }

    static var bingAPIKeyValue: String {
        get { UserDefaults.standard.string(forKey: bingAPIKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: bingAPIKey) }
    }

    static var bingRegionValue: String {
        get { UserDefaults.standard.string(forKey: bingRegion) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: bingRegion) }
    }

    static var bingEndpointValue: String {
        get { UserDefaults.standard.string(forKey: bingEndpoint) ?? "https://api.cognitive.microsofttranslator.com" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: bingEndpoint) }
    }

    static var deepseekAPIKeyValue: String {
        get { UserDefaults.standard.string(forKey: deepseekAPIKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deepseekAPIKey) }
    }

    static var deepseekEndpointValue: String {
        get { UserDefaults.standard.string(forKey: deepseekEndpoint) ?? "https://api.deepseek.com/chat/completions" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deepseekEndpoint) }
    }

    static var deepseekModelValue: String {
        get { UserDefaults.standard.string(forKey: deepseekModel) ?? "deepseek-chat" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: deepseekModel) }
    }

    static func isConfigured(serviceID: TranslateServiceID) -> Bool {
        switch serviceID {
        case .youdaoAPI:
            return !youdaoAppKeyValue.isEmpty && !youdaoSecretValue.isEmpty
        case .baiduAPI:
            return !baiduAppIDValue.isEmpty && !baiduSecretValue.isEmpty
        case .googleAPI:
            return !googleAPIKeyValue.isEmpty
        case .bingAPI:
            return !bingAPIKeyValue.isEmpty
        case .deepseekAPI:
            return !deepseekAPIKeyValue.isEmpty
        }
    }
}
