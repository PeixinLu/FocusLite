import SwiftUI

final class WebSearchSettingsViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var selectedEngine: WebSearchEngine
    @Published var customTemplate: String
    @Published var showFallback: Bool

    init() {
        isEnabled = WebSearchPreferences.isEnabled
        selectedEngine = WebSearchPreferences.engine
        customTemplate = WebSearchPreferences.customTemplate
        showFallback = WebSearchPreferences.showFallback
    }

    func applyChanges() {
        WebSearchPreferences.isEnabled = isEnabled
        WebSearchPreferences.engine = selectedEngine
        if selectedEngine == .custom {
            WebSearchPreferences.customTemplate = customTemplate
        }
        WebSearchPreferences.showFallback = showFallback
    }
}

struct WebSearchSettingsView: View {
    @StateObject var viewModel: WebSearchSettingsViewModel
    let onSaved: (() -> Void)?

    init(viewModel: WebSearchSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection("网页搜索") {
                SettingsFieldRow(title: "启用") {
                    Toggle("", isOn: $viewModel.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.isEnabled) { _ in apply() }
                }

                SettingsFieldRow(title: "搜索引擎") {
                    Picker("", selection: $viewModel.selectedEngine) {
                        ForEach(WebSearchEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .frame(width: 200)
                    .onChange(of: viewModel.selectedEngine) { _ in apply() }
                }

                if viewModel.selectedEngine == .custom {
                    SettingsFieldRow(title: "模板") {
                        TextField("包含 {query} 的 URL", text: $viewModel.customTemplate)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 320)
                            .onChange(of: viewModel.customTemplate) { _ in apply() }
                    }
                }

                SettingsFieldRow(title: "浏览器") {
                    Text("跟随系统默认浏览器")
                        .foregroundColor(.secondary)
                }

                SettingsFieldRow(title: "结果显示") {
                    Toggle("在全局搜索结果末尾追加浏览器搜索", isOn: $viewModel.showFallback)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.showFallback) { _ in apply() }
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func apply() {
        viewModel.applyChanges()
        onSaved?()
    }
}
