import Foundation
import CryptoKit

struct TranslationServiceTestResult: Sendable {
    let success: Bool
    let message: String
}

enum TranslationProxy {
    static func translateText(request: TranslationRequest, serviceID: TranslateServiceID) async -> String? {
        guard TranslatePreferences.isConfigured(serviceID: serviceID) else { return nil }
        switch serviceID {
        case .youdaoAPI:
            return await translateWithYoudao(request: request).text
        case .baiduAPI:
            return await translateWithBaidu(request: request).text
        case .googleAPI:
            return await translateWithGoogle(request: request).text
        case .bingAPI:
            return await translateWithBing(request: request).text
        case .deepseekAPI:
            return await translateWithDeepSeek(request: request).text
        }
    }

    static func test(serviceID: TranslateServiceID) async -> TranslationServiceTestResult {
        guard TranslatePreferences.isConfigured(serviceID: serviceID) else {
            return TranslationServiceTestResult(success: false, message: "未配置密钥")
        }

        let request = TranslationRequest(text: "hello", sourceLanguage: "en", targetLanguage: "zh-Hans")
        switch serviceID {
        case .youdaoAPI:
            let response = await translateWithYoudao(request: request)
            return TranslationServiceTestResult(success: response.text != nil, message: response.message)
        case .baiduAPI:
            let response = await translateWithBaidu(request: request)
            return TranslationServiceTestResult(success: response.text != nil, message: response.message)
        case .googleAPI:
            let response = await translateWithGoogle(request: request)
            return TranslationServiceTestResult(success: response.text != nil, message: response.message)
        case .bingAPI:
            let response = await translateWithBing(request: request)
            return TranslationServiceTestResult(success: response.text != nil, message: response.message)
        case .deepseekAPI:
            let response = await translateWithDeepSeek(request: request)
            return TranslationServiceTestResult(success: response.text != nil, message: response.message)
        }
    }

    private static func translateWithYoudao(request: TranslationRequest) async -> (text: String?, message: String) {
        let appKey = TranslatePreferences.youdaoAppKeyValue
        let secret = TranslatePreferences.youdaoSecretValue
        guard !appKey.isEmpty, !secret.isEmpty else {
            return (nil, "缺少 App Key 或 Secret")
        }

        let salt = UUID().uuidString
        let from = youdaoLanguageCode(request.sourceLanguage)
        let to = youdaoLanguageCode(request.targetLanguage)
        let sign = md5("\(appKey)\(request.text)\(salt)\(secret)")

        var components = URLComponents(string: "https://openapi.youdao.com/api")
        components?.queryItems = [
            URLQueryItem(name: "q", value: request.text),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "appKey", value: appKey),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign)
        ]

        guard let url = components?.url else {
            return (nil, "参数错误")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (nil, "请求失败")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "解析失败")
            }
            let errorCode = json["errorCode"] as? String ?? "0"
            if errorCode != "0" {
                return (nil, "错误码 \(errorCode)")
            }
            if let translation = json["translation"] as? [String], let text = translation.first, !text.isEmpty {
                return (text, "成功")
            }
            return (nil, "无翻译结果")
        } catch {
            return (nil, "网络错误")
        }
    }

    private static func translateWithBaidu(request: TranslationRequest) async -> (text: String?, message: String) {
        let appID = TranslatePreferences.baiduAppIDValue
        let secret = TranslatePreferences.baiduSecretValue
        guard !appID.isEmpty, !secret.isEmpty else {
            return (nil, "缺少 App ID 或 Secret")
        }

        let salt = String(Int.random(in: 10000...99999))
        let from = baiduLanguageCode(request.sourceLanguage)
        let to = baiduLanguageCode(request.targetLanguage)
        let sign = md5("\(appID)\(request.text)\(salt)\(secret)")

        var components = URLComponents(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")
        components?.queryItems = [
            URLQueryItem(name: "q", value: request.text),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "appid", value: appID),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "sign", value: sign)
        ]

        guard let url = components?.url else {
            return (nil, "参数错误")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (nil, "请求失败")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "解析失败")
            }
            if let errorCode = json["error_code"] as? String {
                return (nil, "错误码 \(errorCode)")
            }
            if let results = json["trans_result"] as? [[String: Any]],
               let first = results.first,
               let text = first["dst"] as? String,
               !text.isEmpty {
                return (text, "成功")
            }
            return (nil, "无翻译结果")
        } catch {
            return (nil, "网络错误")
        }
    }

    private static func translateWithGoogle(request: TranslationRequest) async -> (text: String?, message: String) {
        let apiKey = TranslatePreferences.googleAPIKeyValue
        guard !apiKey.isEmpty else {
            return (nil, "缺少 API Key")
        }

        guard let url = URL(string: "https://translation.googleapis.com/language/translate/v2") else {
            return (nil, "参数错误")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let bodyItems = [
            URLQueryItem(name: "q", value: request.text),
            URLQueryItem(name: "source", value: googleLanguageCode(request.sourceLanguage)),
            URLQueryItem(name: "target", value: googleLanguageCode(request.targetLanguage)),
            URLQueryItem(name: "format", value: "text"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        var components = URLComponents()
        components.queryItems = bodyItems
        urlRequest.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (nil, "请求失败")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "解析失败")
            }
            if let data = json["data"] as? [String: Any],
               let translations = data["translations"] as? [[String: Any]],
               let first = translations.first,
               let text = first["translatedText"] as? String,
               !text.isEmpty {
                return (text, "成功")
            }
            return (nil, "无翻译结果")
        } catch {
            return (nil, "网络错误")
        }
    }

    private static func translateWithBing(request: TranslationRequest) async -> (text: String?, message: String) {
        let apiKey = TranslatePreferences.bingAPIKeyValue
        guard !apiKey.isEmpty else {
            return (nil, "缺少 API Key")
        }

        let endpoint = TranslatePreferences.bingEndpointValue
        var components = URLComponents(string: endpoint)
        components?.path = "/translate"
        components?.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "from", value: bingLanguageCode(request.sourceLanguage)),
            URLQueryItem(name: "to", value: bingLanguageCode(request.targetLanguage))
        ]

        guard let url = components?.url else {
            return (nil, "参数错误")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let region = TranslatePreferences.bingRegionValue
        if !region.isEmpty {
            urlRequest.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }
        let payload = [["text": request.text]]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (nil, "请求失败")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = json.first,
                  let translations = first["translations"] as? [[String: Any]],
                  let text = translations.first?["text"] as? String,
                  !text.isEmpty else {
                return (nil, "解析失败")
            }
            return (text, "成功")
        } catch {
            return (nil, "网络错误")
        }
    }

    private static func translateWithDeepSeek(request: TranslationRequest) async -> (text: String?, message: String) {
        let apiKey = TranslatePreferences.deepseekAPIKeyValue
        guard !apiKey.isEmpty else {
            return (nil, "缺少 API Key")
        }

        let endpoint = TranslatePreferences.deepseekEndpointValue
        guard let url = URL(string: endpoint) else {
            return (nil, "参数错误")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = "Translate from \(request.sourceLanguage) to \(request.targetLanguage). Only return the translated text."
        let payload: [String: Any] = [
            "model": TranslatePreferences.deepseekModelValue,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": request.text]
            ],
            "temperature": 1.3,
            "stream": false
        ]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (nil, "请求失败")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "解析失败")
            }
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return (nil, message)
            }
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let text = message["content"] as? String,
               !text.isEmpty {
                return (text.trimmingCharacters(in: .whitespacesAndNewlines), "成功")
            }
            return (nil, "无翻译结果")
        } catch {
            return (nil, "网络错误")
        }
    }

    private static func youdaoLanguageCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        if lowercased.hasPrefix("zh") {
            return "zh-CHS"
        }
        if lowercased.hasPrefix("en") {
            return "en"
        }
        return "auto"
    }

    private static func baiduLanguageCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        if lowercased.hasPrefix("zh") {
            return "zh"
        }
        if lowercased.hasPrefix("en") {
            return "en"
        }
        return "auto"
    }

    private static func googleLanguageCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        if lowercased.hasPrefix("zh") {
            return "zh-CN"
        }
        if lowercased.hasPrefix("en") {
            return "en"
        }
        return "auto"
    }

    private static func bingLanguageCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        if lowercased.hasPrefix("zh") {
            return "zh-Hans"
        }
        if lowercased.hasPrefix("en") {
            return "en"
        }
        return "auto"
    }

    private static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
