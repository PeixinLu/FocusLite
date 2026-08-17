import SwiftUI
import UniformTypeIdentifiers

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
    @Published var autoCaptureSelectedText: Bool
    @Published var showTranslationBubble: Bool
    @Published var hotKeyText: String
    @Published var accessibilityTrusted: Bool

    @Published var youdaoAppKey: String
    @Published var youdaoSecret: String

    @Published var baiduAppID: String
    @Published var baiduSecret: String

    @Published var googleAPIKey: String

    @Published var bingAPIKey: String
    @Published var bingRegion: String
    @Published var bingEndpoint: String

    @Published var deepseekAPIKey: String
    @Published var deepseekEndpoint: String
    @Published var deepseekModel: String

    @Published var testStatus: [String: TranslateServiceTestStatus] = [:]
    @Published var primaryLanguage: String
    @Published var secondaryLanguage: String

    init() {
        mixedPolicy = TranslatePreferences.mixedTextPolicy
        enabledServices = TranslatePreferences.enabledServices
        translatePrefixText = TranslatePreferences.searchPrefix
        autoPasteEnabled = TranslatePreferences.autoPasteAfterSelect
        autoCaptureSelectedText = TranslatePreferences.autoCaptureSelectedText
        showTranslationBubble = TranslatePreferences.showTranslationBubble
        hotKeyText = TranslatePreferences.hotKeyText
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        youdaoAppKey = TranslatePreferences.youdaoAppKeyValue
        youdaoSecret = TranslatePreferences.youdaoSecretValue
        baiduAppID = TranslatePreferences.baiduAppIDValue
        baiduSecret = TranslatePreferences.baiduSecretValue
        googleAPIKey = TranslatePreferences.googleAPIKeyValue
        bingAPIKey = TranslatePreferences.bingAPIKeyValue
        bingRegion = TranslatePreferences.bingRegionValue
        bingEndpoint = TranslatePreferences.bingEndpointValue
        deepseekAPIKey = TranslatePreferences.deepseekAPIKeyValue
        deepseekEndpoint = TranslatePreferences.deepseekEndpointValue
        deepseekModel = TranslatePreferences.deepseekModelValue
        primaryLanguage = TranslatePreferences.primaryLanguage
        secondaryLanguage = TranslatePreferences.secondaryLanguage
    }

    func applyChanges() {
        TranslatePreferences.mixedTextPolicy = mixedPolicy
        TranslatePreferences.enabledServices = enabledServices
        TranslatePreferences.searchPrefix = translatePrefixText
        TranslatePreferences.autoPasteAfterSelect = autoPasteEnabled
        TranslatePreferences.autoCaptureSelectedText = autoCaptureSelectedText
        TranslatePreferences.showTranslationBubble = showTranslationBubble
        TranslatePreferences.hotKeyText = hotKeyText
        TranslatePreferences.youdaoAppKeyValue = youdaoAppKey
        TranslatePreferences.youdaoSecretValue = youdaoSecret
        TranslatePreferences.baiduAppIDValue = baiduAppID
        TranslatePreferences.baiduSecretValue = baiduSecret
        TranslatePreferences.googleAPIKeyValue = googleAPIKey
        TranslatePreferences.bingAPIKeyValue = bingAPIKey
        TranslatePreferences.bingRegionValue = bingRegion
        TranslatePreferences.bingEndpointValue = bingEndpoint
        TranslatePreferences.deepseekAPIKeyValue = deepseekAPIKey
        TranslatePreferences.deepseekEndpointValue = deepseekEndpoint
        TranslatePreferences.deepseekModelValue = deepseekModel
        TranslatePreferences.primaryLanguage = primaryLanguage
        TranslatePreferences.secondaryLanguage = secondaryLanguage
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

    func languageDisplayName(_ code: String) -> String {
        TranslatePreferences.displayName(for: code)
    }

    func keepLanguagesDistinct() {
        guard TranslatePreferences.normalizedLanguageCode(primaryLanguage) ==
                TranslatePreferences.normalizedLanguageCode(secondaryLanguage) else { return }
        secondaryLanguage = TranslatePreferences.normalizedLanguageCode(primaryLanguage) == "en"
            ? "zh-Hans"
            : "en"
    }

    func ensureAccessibilityForAutoPaste() -> Bool {
        if autoPasteEnabled && !AccessibilityPermission.isTrusted(prompt: false) {
            let granted = AccessibilityPermission.requestIfNeeded()
            if !granted {
                autoPasteEnabled = false
                return false
            }
        }
        return true
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
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: TranslateSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    @State private var appleNativeStatus: String?
    @State private var appleNativeInstalled = false

    private func checkAppleNativeStatus() async {
        let source = viewModel.primaryLanguage
        let target = viewModel.secondaryLanguage
        let installed = await AppleNativeTranslationService.isInstalled(
            sourceLanguage: source, targetLanguage: target
        )
        await MainActor.run {
            appleNativeInstalled = installed
            if installed {
                let targetName = TranslatePreferences.displayName(for: target)
                appleNativeStatus = "\(targetName)语言包已就绪 ✅"
            } else {
                appleNativeStatus = "未下载语言包"
            }
        }
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            // Apple 系统翻译 — 推荐首选
            SettingsSection(
                "Apple 系统翻译",
                note: "推荐 · 无需配置密钥，macOS 26+ 离线可用，数据不离开设备"
            ) {
                HStack {
                    Toggle("Apple 系统翻译", isOn: Binding(
                        get: { viewModel.enabledServices.contains(TranslateServiceID.appleNative.rawValue) },
                        set: { isOn in
                            viewModel.toggleService(TranslateServiceID.appleNative.rawValue, isOn: isOn)
                            applyAndNotify()
                        }
                    ))
                    .toggleStyle(.switch)
                    Spacer()
                    if let status = appleNativeStatus {
                        Text(status)
                            .font(.system(size: 11))
                            .foregroundColor(appleNativeInstalled ? .green : .orange)
                    }
                }
                if !appleNativeInstalled, appleNativeStatus != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("翻译语言包未下载，请在系统设置中下载后使用")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button("打开系统翻译语言设置...") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.Localization")!
                            )
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.link)
                    }
                    .padding(.top, 2)
                }
            }

            SettingsSection(
                "翻译前缀",
                note: "快捷键需包含 ⌘/⌥/⌃ 中至少一个。示例：⌥+Space 或 ⌥+K。"
            ) {
                SettingsFieldRow(title: "前缀") {
                    TextField("如 Ts", text: $viewModel.translatePrefixText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onChange(of: viewModel.translatePrefixText) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "快捷键") {
                    HotKeyRecorderField(
                        text: $viewModel.hotKeyText,
                        conflictHotKeys: [GeneralPreferences.launcherHotKeyText, ClipboardPreferences.hotKeyText, SnippetsPreferences.hotKeyText]
                    ) {
                        applyAndNotify()
                    }
                }
                SettingsFieldRow(title: "自动获取选中文本") {
                    Toggle("快捷键唤起时自动将选中的文本带入翻译", isOn: $viewModel.autoCaptureSelectedText)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.autoCaptureSelectedText) { _ in
                            applyAndNotify()
                        }
                }
                if viewModel.autoCaptureSelectedText && !viewModel.accessibilityTrusted {
                    Text("此功能需要辅助功能权限，请在「系统设置 > 隐私与安全 > 辅助功能」中添加 FocusLite")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                SettingsFieldRow(title: "翻译气泡") {
                    Toggle("以浮动气泡显示翻译结果，不打开主搜索窗口", isOn: $viewModel.showTranslationBubble)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.showTranslationBubble) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "自动粘贴") {
                    Toggle("选中后自动粘贴到输入框", isOn: $viewModel.autoPasteEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.autoPasteEnabled) { _ in
                            ensureAccessibilityIfNeeded()
                        }
                    if viewModel.autoPasteEnabled && !viewModel.accessibilityTrusted {
                        Text("请检查 FocusLite 的辅助功能权限")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
            }

            SettingsSection(
                "翻译语言",
                note: "主语言内容默认翻译为常用外语；其他语言内容默认翻译为主语言。主语言首次根据 macOS 首选语言初始化。"
            ) {
                SettingsFieldRow(title: "主语言") {
                    Picker("主语言", selection: $viewModel.primaryLanguage) {
                        ForEach(TranslatePreferences.languageOptions, id: \.code) { option in
                            Text(option.name).tag(option.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: viewModel.primaryLanguage) { _ in
                        viewModel.keepLanguagesDistinct()
                        applyAndNotify()
                    }
                }
                SettingsFieldRow(title: "常用外语") {
                    Picker("常用外语", selection: $viewModel.secondaryLanguage) {
                        ForEach(TranslatePreferences.languageOptions, id: \.code) { option in
                            Text(option.name).tag(option.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: viewModel.secondaryLanguage) { _ in
                        viewModel.keepLanguagesDistinct()
                        applyAndNotify()
                    }
                }
                Text("自动规则：\(viewModel.languageDisplayName(viewModel.primaryLanguage))内容 → \(viewModel.languageDisplayName(viewModel.secondaryLanguage))；其他语言 → \(viewModel.languageDisplayName(viewModel.primaryLanguage))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            SettingsSection("混合文本") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("是否翻译中英混合输入文本")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("是否翻译中英混合输入文本", selection: $viewModel.mixedPolicy) {
                        Text("自动交给服务处理").tag(TranslatePreferences.MixedTextPolicy.auto)
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
                title: "DeepSeek 翻译（开放平台）· 推荐",
                note: "需要 DeepSeek API Key",
                id: .deepseekAPI,
                apiKeyURL: "https://platform.deepseek.com/api_keys"
            ) {
                SettingsFieldRow(title: "API Key") {
                    SecureField("密钥", text: $viewModel.deepseekAPIKey)
                        .frame(width: 220)
                        .onChange(of: viewModel.deepseekAPIKey) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "模型") {
                    TextField("deepseek-chat", text: $viewModel.deepseekModel)
                        .frame(width: 220)
                        .onChange(of: viewModel.deepseekModel) { _ in
                            applyAndNotify()
                        }
                }
                SettingsFieldRow(title: "接口地址") {
                    TextField("https://api.deepseek.com/chat/completions", text: $viewModel.deepseekEndpoint)
                        .frame(width: 240)
                        .onChange(of: viewModel.deepseekEndpoint) { _ in
                            applyAndNotify()
                        }
                }
            }

            serviceSection(
                title: "有道翻译（官方 API）",
                note: "需要有道智云应用密钥",
                id: .youdaoAPI,
                apiKeyURL: "https://ai.youdao.com/console/#/"
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
                id: .baiduAPI,
                apiKeyURL: "https://fanyi-api.baidu.com/manage/developer"
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
        .onAppear {
            refreshPermissionStatus()
        }
        .task {
            await checkAppleNativeStatus()
        }
        .onChange(of: viewModel.primaryLanguage) { _ in
            Task { await checkAppleNativeStatus() }
        }
        .onChange(of: viewModel.secondaryLanguage) { _ in
            Task { await checkAppleNativeStatus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .permissionsShouldRefresh)) { _ in
            refreshPermissionStatus()
        }
        .onChange(of: scenePhase) { _ in
            refreshPermissionStatus()
        }
    }

    private func serviceSection<Content: View>(
        title: String,
        note: String,
        id: TranslateServiceID,
        apiKeyURL: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let isEnabled = viewModel.enabledServices.contains(id.rawValue)
        return SettingsSection(note: note) {
            HStack {
                Toggle(title, isOn: serviceBinding(id))
                    .toggleStyle(.switch)
                Spacer()
                if let apiKeyURL, let url = URL(string: apiKeyURL) {
                    Link("申请 API Key", destination: url)
                        .font(.system(size: 12, weight: .semibold))
                }
                Button("测试") {
                    viewModel.testService(id)
                    onSaved?()
                }
                .disabled(isTesting(id))
            }
            if isEnabled {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                testStatusView(id)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
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

    private func ensureAccessibilityIfNeeded() {
        let granted = viewModel.ensureAccessibilityForAutoPaste()
        if granted {
            applyAndNotify()
        } else {
            // still apply to persist toggled-off state
            applyAndNotify()
        }
    }

    private func refreshPermissionStatus() {
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        if trusted != viewModel.accessibilityTrusted {
            viewModel.accessibilityTrusted = trusted
        }
    }

    private func displayName(for rawValue: String) -> String {
        guard let id = TranslateServiceID(rawValue: rawValue) else { return rawValue }
        return TranslatePreferences.serviceDisplayName(for: id)
    }

    private func serviceDisplayName(for rawValue: String) -> String {
        displayName(for: rawValue)
    }

    private func serviceDisplayName(for rawValue: Binding<String>) -> String {
        serviceDisplayName(for: rawValue.wrappedValue)
    }

}
