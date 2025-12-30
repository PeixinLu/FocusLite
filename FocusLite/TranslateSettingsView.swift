import SwiftUI

struct TranslateServiceTestStatus: Hashable {
    var isTesting: Bool
    var message: String
    var isSuccess: Bool
}

final class TranslateSettingsViewModel: ObservableObject {
    @Published var mixedPolicy: TranslatePreferences.MixedTextPolicy
    @Published var enabledServices: [String]
    @Published var translatePrefixText: String
    @Published var autoPasteEnabled: Bool

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
        translatePrefixText = TranslatePreferences.searchPrefix
        autoPasteEnabled = TranslatePreferences.autoPasteAfterSelect
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
        TranslatePreferences.searchPrefix = translatePrefixText
        TranslatePreferences.autoPasteAfterSelect = autoPasteEnabled
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
    let onSaved: (() -> Void)?

    init(viewModel: TranslateSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection("翻译前缀") {
                SettingsFieldRow(title: "前缀") {
                    TextField("如 tr", text: $viewModel.translatePrefixText)
                        .frame(width: 120)
                        .onChange(of: viewModel.translatePrefixText) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "自动粘贴") {
                    Toggle("选中后自动粘贴到输入框", isOn: $viewModel.autoPasteEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.autoPasteEnabled) { _ in
                            applyAndNotify()
                        }
                }
            }

            SettingsSection("混合文本") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("是否翻译中英混合输入文本")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("是否翻译中英混合输入文本", selection: $viewModel.mixedPolicy) {
                        Text("自动判断").tag(TranslatePreferences.MixedTextPolicy.auto)
                        Text("不翻译").tag(TranslatePreferences.MixedTextPolicy.none)
                    }
                    .frame(width: 160)
                    .labelsHidden()
                    .onChange(of: viewModel.mixedPolicy) { _ in
                        applyAndNotify()
                    }
                }
            }

            serviceSection(
                title: "有道翻译（官方 API）",
                note: "需要有道智云应用密钥",
                id: .youdaoAPI
            ) {
                SettingsFieldRow(title: "App Key") {
                    TextField("应用 ID", text: $viewModel.youdaoAppKey)
                        .frame(width: 220)
                        .onChange(of: viewModel.youdaoAppKey) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "App Secret") {
                    SecureField("应用密钥", text: $viewModel.youdaoSecret)
                        .frame(width: 220)
                        .onChange(of: viewModel.youdaoSecret) { _ in
                            applyAndNotify()
                        }
                }
            }

            serviceSection(
                title: "百度翻译（官方 API）",
                note: "需要百度翻译开放平台密钥",
                id: .baiduAPI
            ) {
                SettingsFieldRow(title: "App ID") {
                    TextField("应用 ID", text: $viewModel.baiduAppID)
                        .frame(width: 220)
                        .onChange(of: viewModel.baiduAppID) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "App Secret") {
                    SecureField("应用密钥", text: $viewModel.baiduSecret)
                        .frame(width: 220)
                        .onChange(of: viewModel.baiduSecret) { _ in
                            applyAndNotify()
                        }
                }
            }

            serviceSection(
                title: "Google 翻译（官方 API）",
                note: "需要 Google Cloud API Key",
                id: .googleAPI
            ) {
                SettingsFieldRow(title: "API Key") {
                    SecureField("密钥", text: $viewModel.googleAPIKey)
                        .frame(width: 220)
                        .onChange(of: viewModel.googleAPIKey) { _ in
                            applyAndNotify()
                        }
                }
            }

            serviceSection(
                title: "微软翻译（官方 API）",
                note: "需要 Azure Translator Key",
                id: .bingAPI
            ) {
                SettingsFieldRow(title: "API Key") {
                    SecureField("密钥", text: $viewModel.bingAPIKey)
                        .frame(width: 220)
                        .onChange(of: viewModel.bingAPIKey) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "区域") {
                    TextField("可选", text: $viewModel.bingRegion)
                        .frame(width: 160)
                        .onChange(of: viewModel.bingRegion) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "接口地址") {
                    TextField("https://...", text: $viewModel.bingEndpoint)
                        .frame(width: 240)
                        .onChange(of: viewModel.bingEndpoint) { _ in
                            applyAndNotify()
                        }
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func serviceSection<Content: View>(
        title: String,
        note: String,
        id: TranslateServiceID,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SettingsSection(note: note) {
            HStack {
                Toggle(title, isOn: serviceBinding(id))
                    .toggleStyle(.switch)
                Spacer()
                Button("测试") {
                    viewModel.testService(id)
                    onSaved?()
                }
                .disabled(isTesting(id))
            }
            content()
            testStatusView(id)
        }
    }

    private func serviceBinding(_ id: TranslateServiceID) -> Binding<Bool> {
        Binding(
            get: { viewModel.enabledServices.contains(id.rawValue) },
            set: { isOn in
                viewModel.toggleService(id.rawValue, isOn: isOn)
                applyAndNotify()
            }
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

    private func applyAndNotify() {
        viewModel.applyChanges()
        onSaved?()
    }
}
