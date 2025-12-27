import SwiftUI

struct TranslateServiceTestStatus: Hashable {
    var isTesting: Bool
    var message: String
    var isSuccess: Bool
}

final class TranslateSettingsViewModel: ObservableObject {
    @Published var mixedPolicy: TranslatePreferences.MixedTextPolicy
    @Published var enabledServices: [String]

    @Published var youdaoAppKey: String
    @Published var youdaoSecret: String

    @Published var baiduAppID: String
    @Published var baiduSecret: String

    @Published var googleAPIKey: String

    @Published var bingAPIKey: String
    @Published var bingRegion: String
    @Published var bingEndpoint: String

    @Published var testStatus: [String: TranslateServiceTestStatus] = [:]

    init() {
        mixedPolicy = TranslatePreferences.mixedTextPolicy
        enabledServices = TranslatePreferences.enabledServices
        youdaoAppKey = TranslatePreferences.youdaoAppKeyValue
        youdaoSecret = TranslatePreferences.youdaoSecretValue
        baiduAppID = TranslatePreferences.baiduAppIDValue
        baiduSecret = TranslatePreferences.baiduSecretValue
        googleAPIKey = TranslatePreferences.googleAPIKeyValue
        bingAPIKey = TranslatePreferences.bingAPIKeyValue
        bingRegion = TranslatePreferences.bingRegionValue
        bingEndpoint = TranslatePreferences.bingEndpointValue
    }

    func applyChanges() {
        TranslatePreferences.mixedTextPolicy = mixedPolicy
        TranslatePreferences.enabledServices = enabledServices
        TranslatePreferences.youdaoAppKeyValue = youdaoAppKey
        TranslatePreferences.youdaoSecretValue = youdaoSecret
        TranslatePreferences.baiduAppIDValue = baiduAppID
        TranslatePreferences.baiduSecretValue = baiduSecret
        TranslatePreferences.googleAPIKeyValue = googleAPIKey
        TranslatePreferences.bingAPIKeyValue = bingAPIKey
        TranslatePreferences.bingRegionValue = bingRegion
        TranslatePreferences.bingEndpointValue = bingEndpoint
    }

    func toggleService(_ id: String, isOn: Bool) {
        if isOn {
            if !enabledServices.contains(id) {
                enabledServices.append(id)
            }
        } else {
            enabledServices.removeAll { $0 == id }
        }
    }

    @MainActor
    func testService(_ id: TranslateServiceID) {
        let key = id.rawValue
        applyChanges()
        testStatus[key] = TranslateServiceTestStatus(isTesting: true, message: "测试中…", isSuccess: false)

        Task {
            let result = await TranslationProxy.test(serviceID: id)
            await MainActor.run {
                testStatus[key] = TranslateServiceTestStatus(
                    isTesting: false,
                    message: result.message,
                    isSuccess: result.success
                )
            }
        }
    }
}

struct TranslateSettingsView: View {
    @StateObject var viewModel: TranslateSettingsViewModel

    var body: some View {
        VStack(spacing: 16) {
            header

            Form {
                Picker("混合文本", selection: $viewModel.mixedPolicy) {
                    Text("自动判断").tag(TranslatePreferences.MixedTextPolicy.auto)
                    Text("不翻译").tag(TranslatePreferences.MixedTextPolicy.none)
                }
                .frame(width: 240)

                serviceSection(
                    title: "有道翻译（官方 API）",
                    note: "需要有道智云应用密钥",
                    id: .youdaoAPI
                ) {
                    TextField("App Key", text: $viewModel.youdaoAppKey)
                    SecureField("App Secret", text: $viewModel.youdaoSecret)
                }

                serviceSection(
                    title: "百度翻译（官方 API）",
                    note: "需要百度翻译开放平台密钥",
                    id: .baiduAPI
                ) {
                    TextField("App ID", text: $viewModel.baiduAppID)
                    SecureField("App Secret", text: $viewModel.baiduSecret)
                }

                serviceSection(
                    title: "Google 翻译（官方 API）",
                    note: "需要 Google Cloud API Key",
                    id: .googleAPI
                ) {
                    SecureField("API Key", text: $viewModel.googleAPIKey)
                }

                serviceSection(
                    title: "微软翻译（官方 API）",
                    note: "需要 Azure Translator Key",
                    id: .bingAPI
                ) {
                    SecureField("API Key", text: $viewModel.bingAPIKey)
                    TextField("Region (可选)", text: $viewModel.bingRegion)
                    TextField("Endpoint", text: $viewModel.bingEndpoint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("系统翻译（本地）", isOn: serviceBinding(.system))
                    Toggle("Mock（调试）", isOn: serviceBinding(.mock))
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("保存") {
                    viewModel.applyChanges()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 620, height: 640)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("翻译设置")
                .font(.system(size: 20, weight: .semibold))
            Text("配置合规的翻译 API，结果会按服务顺序返回。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func serviceSection<Content: View>(
        title: String,
        note: String,
        id: TranslateServiceID,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(title, isOn: serviceBinding(id))
                Spacer()
                Button("测试") {
                    viewModel.testService(id)
                }
                .disabled(isTesting(id))
            }
            Text(note)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            content()
            testStatusView(id)
        }
    }

    private func serviceBinding(_ id: TranslateServiceID) -> Binding<Bool> {
        Binding(
            get: { viewModel.enabledServices.contains(id.rawValue) },
            set: { viewModel.toggleService(id.rawValue, isOn: $0) }
        )
    }

    private func isTesting(_ id: TranslateServiceID) -> Bool {
        viewModel.testStatus[id.rawValue]?.isTesting == true
    }

    @ViewBuilder
    private func testStatusView(_ id: TranslateServiceID) -> some View {
        if let status = viewModel.testStatus[id.rawValue] {
            Text(status.message)
                .font(.system(size: 11))
                .foregroundColor(status.isSuccess ? .green : .red)
        }
    }
}
