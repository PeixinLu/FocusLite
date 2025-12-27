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
                Toggle("Enable clipboard recording", isOn: $viewModel.isRecordingEnabled)
                    .onChange(of: viewModel.isRecordingEnabled) { _ in
                        ClipboardPreferences.isPaused = !viewModel.isRecordingEnabled
                    }

                TextField("Clipboard hotkey (e.g. option+v)", text: $viewModel.hotKeyText)
                    .frame(width: 240)

                TextField("Search prefix (e.g. c)", text: $viewModel.searchPrefixText)
                    .frame(width: 160)

                TextField("Max entries (10-1000)", text: $viewModel.maxEntriesText)
                    .frame(width: 200)

                Picker("History retention", selection: $viewModel.retentionHours) {
                    Text("3 hours").tag(3)
                    Text("12 hours").tag(12)
                    Text("1 day").tag(24)
                    Text("3 days").tag(72)
                    Text("1 week").tag(168)
                }
                .frame(width: 200)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Ignored apps (bundle IDs, one per line)")
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
                Button("Save") {
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
            Text("Clipboard Settings")
                .font(.system(size: 20, weight: .semibold))
            Text("FocusLite stores clipboard history locally and never uploads it.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
