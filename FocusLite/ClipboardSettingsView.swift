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
    @Published var autoPasteEnabled: Bool
    @Published var accessibilityTrusted: Bool

    init() {
        isRecordingEnabled = !ClipboardPreferences.isPaused
        maxEntriesText = String(ClipboardPreferences.maxEntries)
        ignoredAppsText = ClipboardPreferences.ignoredBundleIDs.joined(separator: "\n")
        hotKeyText = ClipboardPreferences.hotKeyText
        searchPrefixText = ClipboardPreferences.searchPrefix
        retentionHours = ClipboardPreferences.historyRetentionHours
        autoPasteEnabled = ClipboardPreferences.autoPasteAfterSelect
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
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
        ClipboardPreferences.autoPasteAfterSelect = autoPasteEnabled
    }
}

struct ClipboardSettingsView: View {
    @StateObject var viewModel: ClipboardSettingsViewModel
    let onSaved: (() -> Void)?
    @State private var manualBundleID = ""
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: ClipboardSettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection(
                "记录",
                note: "快捷键需包含 ⌘/⌥/⌃ 中至少一个。示例：⌥+Space 或 ⌥+K。"
            ) {
                SettingsFieldRow(title: "启用记录") {
                    Toggle("", isOn: $viewModel.isRecordingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.isRecordingEnabled) { _ in
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

                SettingsFieldRow(title: "快捷键") {
                    HotKeyRecorderField(
                        text: $viewModel.hotKeyText,
                        conflictHotKeys: [GeneralPreferences.launcherHotKeyText]
                    ) {
                        applyAndNotify()
                    }
                }

                SettingsFieldRow(title: "搜索前缀") {
                    TextField("如 V", text: $viewModel.searchPrefixText)
                        .textFieldStyle(.roundedBorder)
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
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshPermissionStatus()
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

    private func applyAndNotify() {
        viewModel.applyChanges()
        onSaved?()
    }

    private func ensureAccessibilityIfNeeded() {
        if viewModel.autoPasteEnabled && !AccessibilityPermission.isTrusted(prompt: false) {
            let granted = AccessibilityPermission.requestIfNeeded()
            if !granted {
                viewModel.autoPasteEnabled = false
            }
            viewModel.accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        }
        applyAndNotify()
    }

    private func refreshPermissionStatus() {
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        if trusted != viewModel.accessibilityTrusted {
            viewModel.accessibilityTrusted = trusted
        }
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
    @State private var previousText: String
    private let captureSession = HotKeyCaptureSession()
    private let conflictHotKeys: [String]

    init(
        text: Binding<String>,
        conflictHotKeys: [String] = [],
        onRecorded: (() -> Void)? = nil
    ) {
        _text = text
        _previousText = State(initialValue: text.wrappedValue)
        self.onRecorded = onRecorded
        self.conflictHotKeys = conflictHotKeys
    }

    var body: some View {
        HStack(spacing: 8) {
            KeyRecorderTextField(
                text: $text,
                isRecording: $isRecording,
                onCaptured: handleCaptured,
                onCancel: { stopRecording(revert: true) }
            )
            .frame(width: 200)
            Button(isRecording ? "取消" : "录制") {
                if isRecording {
                    stopRecording(revert: true)
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.bordered)
            Button("清除") {
                clearBinding()
            }
            .buttonStyle(.bordered)
        }
    }

    private func handleCaptured(_ combo: String) {
        guard isRecording else { return }
        if combo.isEmpty {
            text = ""
            stopRecording(revert: false)
            onRecorded?()
            return
        }
        guard let descriptor = HotKeyDescriptor.parse(combo) else { return }
        if let conflict = conflictDescriptor(for: descriptor) {
            stopRecording(revert: true, conflictMessage: "与现有快捷键「\(conflict)」冲突，请选择其他组合。")
            return
        }
        text = combo
        stopRecording(revert: false)
        onRecorded?()
    }

    private func startRecording() {
        previousText = text
        guard captureSession.start(onCaptured: handleCaptured) else {
            return
        }
        NotificationCenter.default.post(name: .hotKeyRecordingWillBegin, object: nil)
        isRecording = true
    }

    private func stopRecording(revert: Bool, conflictMessage: String? = nil) {
        if revert {
            text = previousText
        }
        captureSession.stop()
        isRecording = false
        NotificationCenter.default.post(name: .hotKeyRecordingDidEnd, object: nil)
        if let conflictMessage {
            presentConflictAlert(conflictMessage)
        }
    }

    private func clearBinding() {
        previousText = text
        text = ""
        captureSession.stop()
        isRecording = false
        NotificationCenter.default.post(name: .hotKeyRecordingDidEnd, object: nil)
        onRecorded?()
    }

    private func conflictDescriptor(for descriptor: HotKeyDescriptor) -> String? {
        for item in conflictHotKeys where !item.isEmpty {
            guard let other = HotKeyDescriptor.parse(item) else { continue }
            if other == descriptor {
                return item
            }
        }
        return nil
    }

    private func presentConflictAlert(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "快捷键冲突"
        alert.informativeText = message
        alert.runModal()
    }
}

private struct KeyRecorderTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isRecording: Bool
    var onCaptured: (String) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isRecording: $isRecording,
            onCaptured: onCaptured,
            onCancel: onCancel
        )
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
        if isRecording {
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            nsView.attributedStringValue = NSAttributedString(string: "按下快捷键…", attributes: attributes)
        } else {
            nsView.attributedStringValue = hotKeyDisplayString(for: text)
        }
        if isRecording, nsView.window?.firstResponder != nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class Coordinator {
        @Binding var text: String
        @Binding var isRecording: Bool
        let onCaptured: (String) -> Void
        let onCancel: () -> Void

        init(
            text: Binding<String>,
            isRecording: Binding<Bool>,
            onCaptured: @escaping (String) -> Void,
            onCancel: @escaping () -> Void
        ) {
            _text = text
            _isRecording = isRecording
            self.onCaptured = onCaptured
            self.onCancel = onCancel
        }

        func beginRecording() {
            isRecording = true
        }

        func handleKey(_ event: NSEvent) {
            guard isRecording else { return }

            if event.keyCode == kVK_Escape {
                isRecording = false
                onCancel()
                return
            }

            if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
                isRecording = false
                onCaptured("")
                return
            }

            guard let key = keyToken(for: event) else { return }
            let tokens = modifierTokens(from: event) + [key]
            let candidate = tokens.joined(separator: "+")
            onCaptured(candidate)
        }
    }
}

private final class HotKeyCaptureSession {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var onCaptured: ((String) -> Void)?

    @discardableResult
    func start(onCaptured: @escaping (String) -> Void) -> Bool {
        stop()
        self.onCaptured = onCaptured

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData else { return Unmanaged.passUnretained(event) }
            let session = Unmanaged<HotKeyCaptureSession>.fromOpaque(userData).takeUnretainedValue()
            session.handle(event: event, type: type)
            return Unmanaged.passUnretained(event)
        }

        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) {
            eventTap = tap
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        if localMonitor == nil {
            // Local monitor ensures hotkey recording works even without input monitoring permission.
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                self?.handle(event: event)
                return event
            }
        }
        return eventTap != nil || localMonitor != nil
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        onCaptured = nil
    }

    private func handle(event: NSEvent) {
        guard event.type == .keyDown else { return }
        guard let key = keyToken(for: event) else { return }
        let tokens = modifierTokens(from: event) + [key]
        let candidate = tokens.joined(separator: "+")
        DispatchQueue.main.async { [weak self] in
            self?.onCaptured?(candidate)
        }
    }

    private func handle(event: CGEvent, type: CGEventType) {
        guard type == .keyDown else { return }
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        guard let key = keyToken(for: nsEvent) else { return }
        let tokens = modifierTokens(from: nsEvent) + [key]
        let candidate = tokens.joined(separator: "+")
        DispatchQueue.main.async { [weak self] in
            self?.onCaptured?(candidate)
        }
    }

    deinit {
        stop()
    }
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

private func hotKeyDisplayString(for text: String) -> NSAttributedString {
    let (modifiers, key) = parsedHotKeyTokens(from: text)
    let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    let activeFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
    let base = NSMutableAttributedString()
    let modifierOrder = ["command", "option", "shift", "control"]
    let symbolMap: [String: String] = [
        "command": "⌘",
        "option": "⌥",
        "shift": "⇧",
        "control": "⌃"
    ]
    for (index, name) in modifierOrder.enumerated() {
        let symbol = symbolMap[name] ?? name
        let isActive = modifiers.contains(name)
        let color = isActive ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: isActive ? activeFont : defaultFont
        ]
        base.append(NSAttributedString(string: symbol, attributes: attrs))
        if index < modifierOrder.count - 1 || key != nil {
            base.append(NSAttributedString(string: " ", attributes: attrs))
        }
    }
    if let key {
        let keySymbol = keyDisplaySymbol(for: key)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.controlAccentColor,
            .font: activeFont
        ]
        base.append(NSAttributedString(string: keySymbol, attributes: attrs))
    }
    return base
}

private func parsedHotKeyTokens(from text: String) -> (Set<String>, String?) {
    let parts = text
        .split(separator: "+")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
    if parts.isEmpty {
        return ([], nil)
    }
    var modifiers: Set<String> = []
    var keyToken: String?
    for token in parts {
        switch token {
        case "command", "cmd", "⌘":
            modifiers.insert("command")
        case "option", "opt", "alt", "⌥":
            modifiers.insert("option")
        case "shift", "⇧":
            modifiers.insert("shift")
        case "control", "ctrl", "⌃":
            modifiers.insert("control")
        default:
            keyToken = token
        }
    }
    return (modifiers, keyToken)
}

private func keyDisplaySymbol(for token: String) -> String {
    switch token {
    case "space":
        return "␣"
    default:
        if token.count == 1 {
            return token.uppercased()
        }
        return token.uppercased()
    }
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
extension Notification.Name {
    static let hotKeyRecordingWillBegin = Notification.Name("HotKeyRecordingWillBegin")
    static let hotKeyRecordingDidEnd = Notification.Name("HotKeyRecordingDidEnd")
}
