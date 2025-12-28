import Carbon.HIToolbox
import Cocoa
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
    @State private var manualBundleID = ""

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
                        SettingsFieldRow(title: "启用记录") {
                            Toggle("", isOn: $viewModel.isRecordingEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .onChange(of: viewModel.isRecordingEnabled) { _ in
                                    applyAndNotify()
                                }
                        }

                        SettingsFieldRow(title: "快捷键") {
                            HotKeyRecorderField(text: $viewModel.hotKeyText) {
                                applyAndNotify()
                            }
                        }

                        SettingsFieldRow(title: "搜索前缀") {
                            TextField("如 c", text: $viewModel.searchPrefixText)
                                .frame(width: 120)
                                .onChange(of: viewModel.searchPrefixText) { _ in
                                    applyAndNotify()
                                }
                        }

                        SettingsFieldRow(title: "最大条目") {
                            TextField("10-1000", text: $viewModel.maxEntriesText)
                                .frame(width: 120)
                                .onChange(of: viewModel.maxEntriesText) { _ in
                                    applyAndNotify()
                                }
                        }

                        SettingsFieldRow(title: "历史保留") {
                            Picker("历史保留", selection: $viewModel.retentionHours) {
                                Text("3 小时").tag(3)
                                Text("12 小时").tag(12)
                                Text("1 天").tag(24)
                                Text("3 天").tag(72)
                                Text("1 周").tag(168)
                            }
                            .frame(width: 140)
                            .onChange(of: viewModel.retentionHours) { _ in
                                applyAndNotify()
                            }
                        }
                    }

                    SettingsSection("忽略的应用") {
                        VStack(alignment: .leading, spacing: 10) {
                            if ignoredBundleIDs.isEmpty {
                                Text("未选择应用")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(ignoredBundleIDs, id: \.self) { id in
                                    HStack(spacing: 8) {
                                        Text(id)
                                            .font(.system(size: 12))
                                        Spacer()
                                        Button {
                                            removeIgnoredBundleID(id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }

                            HStack(spacing: 8) {
                                Button("选择应用…") {
                                    pickIgnoredApp()
                                }
                                .buttonStyle(.bordered)

                                TextField("输入 Bundle ID", text: $manualBundleID)
                                    .frame(width: 200)

                                Button("添加") {
                                    addIgnoredBundleID(manualBundleID)
                                    manualBundleID = ""
                                }
                                .buttonStyle(.bordered)
                                .disabled(manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
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

    private var ignoredBundleIDs: [String] {
        viewModel.ignoredAppsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func addIgnoredBundleID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = ignoredBundleIDs
        guard !current.contains(trimmed) else { return }
        current.append(trimmed)
        updateIgnoredBundleIDs(current)
    }

    private func removeIgnoredBundleID(_ id: String) {
        var current = ignoredBundleIDs
        current.removeAll { $0 == id }
        updateIgnoredBundleIDs(current)
    }

    private func updateIgnoredBundleIDs(_ ids: [String]) {
        viewModel.ignoredAppsText = ids.joined(separator: "\n")
        applyAndNotify()
    }

    private func pickIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["app"]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? ""
            if bundleID.isEmpty {
                return
            }
            addIgnoredBundleID(bundleID)
        }
    }
}

struct HotKeyRecorderField: View {
    @Binding var text: String
    var onRecorded: (() -> Void)?
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            KeyRecorderTextField(text: $text, isRecording: $isRecording, onRecorded: onRecorded)
                .frame(width: 200)
            Button(isRecording ? "按键中…" : "录制") {
                isRecording = true
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct KeyRecorderTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isRecording: Bool
    var onRecorded: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isRecording: $isRecording, onRecorded: onRecorded)
    }

    func makeNSView(context: Context) -> RecordingTextField {
        let field = RecordingTextField()
        field.isEditable = false
        field.isSelectable = false
        field.focusRingType = .default
        field.onKeyDown = { event in
            context.coordinator.handleKey(event)
        }
        field.onMouseDown = {
            context.coordinator.beginRecording()
        }
        return field
    }

    func updateNSView(_ nsView: RecordingTextField, context: Context) {
        nsView.stringValue = isRecording ? "按下快捷键…" : text
        nsView.textColor = isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor
        if isRecording, nsView.window?.firstResponder != nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator {
        @Binding var text: String
        @Binding var isRecording: Bool
        let onRecorded: (() -> Void)?

        init(text: Binding<String>, isRecording: Binding<Bool>, onRecorded: (() -> Void)?) {
            _text = text
            _isRecording = isRecording
            self.onRecorded = onRecorded
        }

        func beginRecording() {
            isRecording = true
        }

        func handleKey(_ event: NSEvent) {
            guard isRecording else { return }

            if event.keyCode == kVK_Escape {
                isRecording = false
                return
            }

            guard let key = keyToken(for: event) else { return }
            let tokens = modifierTokens(from: event) + [key]
            text = tokens.joined(separator: "+")
            isRecording = false
            onRecorded?()
        }

        private func modifierTokens(from event: NSEvent) -> [String] {
            var tokens: [String] = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) { tokens.append("command") }
            if flags.contains(.option) { tokens.append("option") }
            if flags.contains(.shift) { tokens.append("shift") }
            if flags.contains(.control) { tokens.append("control") }
            return tokens
        }

        private func keyToken(for event: NSEvent) -> String? {
            if event.keyCode == kVK_Space {
                return "space"
            }

            if let chars = event.charactersIgnoringModifiers?.lowercased(), chars.count == 1 {
                let char = chars.first!
                if char.isLetter || char.isNumber {
                    return String(char)
                }
            }

            return nil
        }
    }
}

private final class RecordingTextField: NSTextField {
    var onKeyDown: ((NSEvent) -> Void)?
    var onMouseDown: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        onMouseDown?()
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
