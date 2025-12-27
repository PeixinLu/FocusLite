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

    var body: some View {
        VStack(spacing: 16) {
            header

            Form {
                Toggle("启用剪贴板记录", isOn: $viewModel.isRecordingEnabled)
                    .onChange(of: viewModel.isRecordingEnabled) { _ in
                        ClipboardPreferences.isPaused = !viewModel.isRecordingEnabled
                    }

                TextField("剪贴板快捷键（如 option+v）", text: $viewModel.hotKeyText)
                    .frame(width: 240)

                TextField("搜索前缀（如 c）", text: $viewModel.searchPrefixText)
                    .frame(width: 160)

                TextField("最大条目数（10-1000）", text: $viewModel.maxEntriesText)
                    .frame(width: 200)

                Picker("历史保留", selection: $viewModel.retentionHours) {
                    Text("3 小时").tag(3)
                    Text("12 小时").tag(12)
                    Text("1 天").tag(24)
                    Text("3 天").tag(72)
                    Text("1 周").tag(168)
                }
                .frame(width: 200)

                VStack(alignment: .leading, spacing: 8) {
                    Text("忽略的应用（Bundle ID，每行一个）")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $viewModel.ignoredAppsText)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                .padding(.vertical, 6)
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
        .frame(width: 520, height: 420)
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
}
