import SwiftUI

final class ClipboardSettingsViewModel: ObservableObject {
    @Published var isRecordingEnabled: Bool
    @Published var maxEntriesText: String
    @Published var ignoredAppsText: String
    @Published var hotKeyText: String
    @Published var searchPrefixText: String
    @Published var retentionHours: Int

    init() {
        isRecordingEnabled = !ClipboardPreferences.isPaused
        maxEntriesText = String(ClipboardPreferences.maxEntries)
        ignoredAppsText = ClipboardPreferences.ignoredBundleIDs.joined(separator: "\n")
        hotKeyText = ClipboardPreferences.hotKeyText
        searchPrefixText = ClipboardPreferences.searchPrefix
        retentionHours = ClipboardPreferences.historyRetentionHours
    }

    func applyChanges() {
        ClipboardPreferences.isPaused = !isRecordingEnabled
        if let maxEntries = Int(maxEntriesText) {
            ClipboardPreferences.maxEntries = maxEntries
        }
        let bundleIDs = ignoredAppsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        ClipboardPreferences.ignoredBundleIDs = bundleIDs
        ClipboardPreferences.hotKeyText = hotKeyText
        ClipboardPreferences.searchPrefix = searchPrefixText
        ClipboardPreferences.historyRetentionHours = retentionHours
    }
}

struct ClipboardSettingsView: View {
    @StateObject var viewModel: ClipboardSettingsViewModel
    let onSaved: (() -> Void)?

    init(viewModel: ClipboardSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            header
                .padding(.bottom, SettingsLayout.headerBottomPadding)

            ScrollView {
                VStack(spacing: SettingsLayout.sectionSpacing) {
                    SettingsSection("记录") {
                        Toggle("启用剪贴板记录", isOn: $viewModel.isRecordingEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: viewModel.isRecordingEnabled) { _ in
                                applyAndNotify()
                            }

                        TextField("剪贴板快捷键（如 option+v）", text: $viewModel.hotKeyText)
                            .frame(width: 240)
                            .onChange(of: viewModel.hotKeyText) { _ in
                                applyAndNotify()
                            }

                        TextField("搜索前缀（如 c）", text: $viewModel.searchPrefixText)
                            .frame(width: 160)
                            .onChange(of: viewModel.searchPrefixText) { _ in
                                applyAndNotify()
                            }

                        TextField("最大条目数（10-1000）", text: $viewModel.maxEntriesText)
                            .frame(width: 200)
                            .onChange(of: viewModel.maxEntriesText) { _ in
                                applyAndNotify()
                            }

                        Picker("历史保留", selection: $viewModel.retentionHours) {
                            Text("3 小时").tag(3)
                            Text("12 小时").tag(12)
                            Text("1 天").tag(24)
                            Text("3 天").tag(72)
                            Text("1 周").tag(168)
                        }
                        .frame(width: 200)
                        .onChange(of: viewModel.retentionHours) { _ in
                            applyAndNotify()
                        }
                    }

                    SettingsSection("忽略的应用") {
                        Text("Bundle ID，每行一个")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextEditor(text: $viewModel.ignoredAppsText)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                            .onChange(of: viewModel.ignoredAppsText) { _ in
                                applyAndNotify()
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("剪贴板设置")
                .font(.system(size: 20, weight: .semibold))
            Text("剪贴板记录仅保存在本地，不会上传。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applyAndNotify() {
        viewModel.applyChanges()
        onSaved?()
    }
}
