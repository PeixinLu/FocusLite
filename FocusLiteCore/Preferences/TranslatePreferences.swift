import Foundation

enum TranslatePreferences {
    private static let targetModeKey = "translate.targetMode"
    private static let mixedPolicyKey = "translate.mixedPolicy"
    private static let prefixKey = "translate.prefix"
    private static let servicesKey = "translate.services"
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
        get { UserDefaults.standard.string(forKey: prefixKey) ?? "tr" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: prefixKey) }
    }

    static var autoPasteAfterSelect: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoPasteKey) == nil {
                return true
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
