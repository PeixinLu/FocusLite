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
    @Published var hotKeyText: String

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

    init() {
        mixedPolicy = TranslatePreferences.mixedTextPolicy
        enabledServices = TranslatePreferences.enabledServices
        translatePrefixText = TranslatePreferences.searchPrefix
        autoPasteEnabled = TranslatePreferences.autoPasteAfterSelect
        hotKeyText = TranslatePreferences.hotKeyText
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
    }

    func applyChanges() {
        TranslatePreferences.mixedTextPolicy = mixedPolicy
        TranslatePreferences.enabledServices = enabledServices
        TranslatePreferences.searchPrefix = translatePrefixText
        TranslatePreferences.autoPasteAfterSelect = autoPasteEnabled
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
    @State private var draggingService: String?

    init(viewModel: TranslateSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection("翻译前缀") {
                SettingsFieldRow(title: "前缀") {
                    TextField("如 Ts", text: $viewModel.translatePrefixText)
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
                SettingsFieldRow(title: "自动粘贴") {
                    Toggle("选中后自动粘贴到输入框", isOn: $viewModel.autoPasteEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.autoPasteEnabled) { _ in
                            applyAndNotify()
                        }
                }
            }

            SettingsSection("排序") {
                if viewModel.enabledServices.isEmpty {
                    Text("启用服务后可拖拽排序")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(viewModel.enabledServices, id: \.self) { rawValue in
                                HStack(spacing: 10) {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Text(displayName(for: rawValue))
                                        .font(.system(size: 13, weight: .medium))
                                    if rawValue == TranslateServiceID.deepseekAPI.rawValue {
                                        Text("推荐")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                            .padding(.vertical, 2)
                                            .padding(.horizontal, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.accentColor.opacity(0.12))
                                            )
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                )
                                .onDrag {
                                    draggingService = rawValue
                                    return NSItemProvider(object: rawValue as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: ServiceOrderDropDelegate(
                                        item: rawValue,
                                        items: $viewModel.enabledServices,
                                        draggingItem: $draggingService,
                                        onReordered: applyAndNotify
                                    )
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: min(CGFloat(viewModel.enabledServices.count) * 36 + 12, 220))
                }
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
    }

    private func serviceSection<Content: View>(
        title: String,
        note: String,
        id: TranslateServiceID,
        apiKeyURL: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SettingsSection(note: note) {
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

    private func displayName(for rawValue: String) -> String {
        guard let id = TranslateServiceID(rawValue: rawValue) else { return rawValue }
        switch id {
        case .youdaoAPI:
            return "有道 API"
        case .baiduAPI:
            return "百度 API"
        case .googleAPI:
            return "Google API"
        case .bingAPI:
            return "微软翻译 API"
        case .deepseekAPI:
            return "DeepSeek API"
        }
    }
}

private struct ServiceOrderDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggingItem: String?
    let onReordered: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem, dragging != item else { return }
        guard let fromIndex = items.firstIndex(of: dragging),
              let toIndex = items.firstIndex(of: item) else { return }
        if items[toIndex] == dragging { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onReordered()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
