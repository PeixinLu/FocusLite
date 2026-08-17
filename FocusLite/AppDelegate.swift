import ApplicationServices
import Carbon.HIToolbox
import Cocoa
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LauncherWindowController?
    private var launcherViewModel: LauncherViewModel?
    private var translationBubbleController: TranslationBubbleController?
    private let clipboardMonitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager.shared
    private let appUpdater = AppUpdater.shared
    private let onboardingState = OnboardingState()
    lazy var settingsViewModel: SettingsViewModel = {
        let generalSettingsViewModel = GeneralSettingsViewModel()
        let quickDirectoryViewModel = QuickDirectorySettingsViewModel()
        let webSearchViewModel = WebSearchSettingsViewModel()
        let snippetsViewModel = SnippetsManagerViewModel(store: .shared)
        let clipboardSettingsViewModel = ClipboardSettingsViewModel()
        let translateSettingsViewModel = TranslateSettingsViewModel()
        return SettingsViewModel(
            generalViewModel: generalSettingsViewModel,
            quickDirectoryViewModel: quickDirectoryViewModel,
            webSearchViewModel: webSearchViewModel,
            appUpdater: appUpdater,
            clipboardViewModel: clipboardSettingsViewModel,
            snippetsViewModel: snippetsViewModel,
            translateViewModel: translateSettingsViewModel,
            onShowOnboarding: { [weak self] in
                self?.presentOnboarding()
            },
            isOnboardingPresented: { [weak self] in
                self?.onboardingState.isPresented ?? false
            }
        )
    }()
    private var onboardingWindow: NSWindow?
    private var onboardingCancellable: AnyCancellable?
    private var onboardingEscMonitor: Any?
    private var isRecordingHotKey = false
    private let launcherHotKeyID: UInt32 = 1
    private let clipboardHotKeyID: UInt32 = 2
    private let snippetsHotKeyID: UInt32 = 3
    private let translateHotKeyID: UInt32 = 4

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 模式，不显示 Dock 图标，只显示菜单栏图标
        NSApp.setActivationPolicy(.accessory)
        
        let providers: [any ResultProvider] = [
            CalcProvider(),
            SnippetsProvider(),
            ClipboardProvider(),
            TranslateProvider(),
            AppSearchProvider(),
            WebSearchProvider(),
            QuickDirectoryProvider(),
            StyleProvider()
        ]
        let searchEngine = SearchEngine(providers: providers)
        let viewModel = LauncherViewModel(searchEngine: searchEngine)
        launcherViewModel = viewModel
        viewModel.onExit = { [weak self] behavior in
            self?.windowController?.hide(restoreBehavior: behavior)
        }
        viewModel.onOpenSettings = { [weak self] tab in
            self?.showSettings(tab: tab)
        }
        viewModel.onPrepareSettings = { [weak self] tab in
            self?.settingsViewModel.selectedTab = tab
        }
        viewModel.onPaste = { [weak self] text in
            self?.windowController?.pasteTextAndHide(text) ?? false
        }
        viewModel.onPresentOnboarding = { [weak self] in
            self?.presentOnboarding()
        }

        windowController = LauncherWindowController(viewModel: viewModel)
        
        registerLauncherHotKey()
        registerClipboardHotKey()
        registerSnippetsHotKey()
        registerTranslateHotKey()
        windowController?.show()
        clipboardMonitor.start()
        presentOnboardingIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserDefaultsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseHotKeys),
            name: .hotKeyRecordingWillBegin,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeHotKeys),
            name: .hotKeyRecordingDidEnd,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(markRecordingHotKey),
            name: .hotKeyRecordingWillBegin,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(unmarkRecordingHotKey),
            name: .hotKeyRecordingDidEnd,
            object: nil
        )

        onboardingCancellable = onboardingState.$isPresented
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presented in
                guard let self else { return }
                if presented {
                    self.showOnboardingWindow()
                } else {
                    self.onboardingWindow?.orderOut(nil)
                    self.stopOnboardingEscMonitor()
                }
            }

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }

    @objc private func toggleWindow() {
        windowController?.toggle()
    }

    private func handleLauncherHotKey() {
        if onboardingState.isPresented, onboardingState.currentStep == .hotkey {
            onboardingState.hotkeyStepCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak onboardingState] in
                onboardingState?.advance()
            }
            return
        }
        toggleWindow()
    }

    @MainActor @objc private func showSettingsWindow() {
        showSettings(tab: .general)
    }

    @MainActor
    func openSettingsFromMenu() {
        showSettings(tab: .general)
    }

    @MainActor
    func openStylePrefix() {
        guard let viewModel = launcherViewModel else { return }
        windowController?.show(resetSearch: true)
        NSApp.activate(ignoringOtherApps: true)
        viewModel.activateCustomPrefix(StyleProvider.prefixEntry)
        viewModel.requestFocus()
    }

    @MainActor private func showSettings(tab: SettingsTab) {
        settingsViewModel.selectedTab = tab
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let openedBySystem = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            || NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        if !openedBySystem {
            Log.info("Settings scene did not open via system action.")
        }
    }

    @MainActor private func openSettingsViaCommand(tab: SettingsTab) {
        prepareSettingsTab(tab)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let openedBySystem = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        if !openedBySystem {
            showSettings(tab: tab)
        }
    }

    @objc private func toggleClipboardRecording() {
        ClipboardPreferences.isPaused.toggle()
        handleUserDefaultsChange()
    }

    @objc private func checkForUpdates() {
        appUpdater.checkForUpdates()
    }

    @objc private func handleUserDefaultsChange() {
        registerLauncherHotKey()
        registerClipboardHotKey()
        registerSnippetsHotKey()
        registerTranslateHotKey()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func pauseHotKeys() {
        hotKeyManager.unregisterAll()
    }

    @objc private func resumeHotKeys() {
        registerLauncherHotKey()
        registerClipboardHotKey()
        registerSnippetsHotKey()
        registerTranslateHotKey()
    }

    @objc private func markRecordingHotKey() {
        isRecordingHotKey = true
    }

    @objc private func unmarkRecordingHotKey() {
        isRecordingHotKey = false
    }

    @MainActor
    func toggleLauncherFromMenu() {
        windowController?.toggle()
    }

    @MainActor
    func prepareSettingsTab(_ tab: SettingsTab) {
        settingsViewModel.selectedTab = tab
    }

    @MainActor
    func presentOnboarding() {
        onboardingState.present()
        showOnboardingWindow()
    }

    @MainActor
    private func presentOnboardingIfNeeded() {
        guard !onboardingState.hasSeenOnboarding else { return }
        presentOnboarding()
    }

    @MainActor
    private func showOnboardingWindow() {
        if onboardingWindow == nil {
            let view = OnboardingView(state: onboardingState)
            let hosting = NSHostingController(rootView: view)
            let panel = OnboardingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.hudWindow, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovable = true
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.collectionBehavior.insert(.fullScreenAuxiliary)
            panel.contentViewController = hosting
            onboardingWindow = panel
        }

        if let window = onboardingWindow {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startOnboardingEscMonitor()
        }
    }

    private func startOnboardingEscMonitor() {
        guard onboardingEscMonitor == nil else { return }
        onboardingEscMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.onboardingState.isPresented, self.onboardingWindow?.isKeyWindow == true else { return event }
            if self.isRecordingHotKey {
                return event
            }
            switch event.keyCode {
            case 36, 48, 76: // return, tab, keypad enter
                self.advanceOnboarding()
                return nil
            case 124: // right
                self.advanceOnboarding()
                return nil
            case 123: // left
                self.goBackOnboarding()
                return nil
            case 53: // esc
                self.onboardingState.dismiss(markSeen: true)
                return nil
            default:
                return event
            }
        }
    }

    private func stopOnboardingEscMonitor() {
        if let monitor = onboardingEscMonitor {
            NSEvent.removeMonitor(monitor)
            onboardingEscMonitor = nil
        }
    }

    private func advanceOnboarding() {
        if onboardingState.currentStep == .appearance {
            onboardingState.dismiss(markSeen: true)
        } else {
            onboardingState.advance()
        }
    }

    private func goBackOnboarding() {
        guard let prev = OnboardingState.Step(rawValue: onboardingState.currentStep.rawValue - 1) else {
            return
        }
        onboardingState.currentStep = prev
    }

    private func registerLauncherHotKey() {
        guard let descriptor = HotKeyDescriptor.parse(GeneralPreferences.launcherHotKeyText) else {
            hotKeyManager.unregister(identifier: launcherHotKeyID)
            Log.info("Launcher hotkey is invalid. Use format like option+space.")
            return
        }

        let registered = hotKeyManager.register(
            keyCode: descriptor.keyCode,
            modifiers: descriptor.modifiers,
            identifier: launcherHotKeyID
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleLauncherHotKey()
            }
        }

        guard registered else {
            Log.info("Global hotkey registration failed (\(GeneralPreferences.launcherHotKeyText)). Use the menu bar icon instead.")
            return
        }
    }

    private func registerClipboardHotKey() {
        guard let descriptor = HotKeyDescriptor.parse(ClipboardPreferences.hotKeyText) else {
            hotKeyManager.unregister(identifier: clipboardHotKeyID)
            Log.info("Clipboard hotkey is invalid. Use format like option+v.")
            return
        }

        let registered = hotKeyManager.register(
            keyCode: descriptor.keyCode,
            modifiers: descriptor.modifiers,
            identifier: clipboardHotKeyID
        ) { [weak self] in
            DispatchQueue.main.async {
                // 先重置搜索，再激活剪贴板模式，最后显示窗口
                self?.launcherViewModel?.resetSearch()
                self?.launcherViewModel?.activateClipboardSearch()
                self?.windowController?.show(resetSearch: false)
            }
        }

        if !registered {
            Log.info("Clipboard hotkey registration failed (\(ClipboardPreferences.hotKeyText)).")
        }
    }

    private func registerSnippetsHotKey() {
        guard let descriptor = HotKeyDescriptor.parse(SnippetsPreferences.hotKeyText) else {
            hotKeyManager.unregister(identifier: snippetsHotKeyID)
            return
        }

        let registered = hotKeyManager.register(
            keyCode: descriptor.keyCode,
            modifiers: descriptor.modifiers,
            identifier: snippetsHotKeyID
        ) { [weak self] in
            DispatchQueue.main.async {
                guard let entry = PrefixRegistry.entries().first(where: { $0.providerID == SnippetsProvider.providerID }) else { return }
                self?.launcherViewModel?.resetSearch()
                self?.launcherViewModel?.activateCustomPrefix(entry)
                self?.windowController?.show(resetSearch: false)
            }
        }

        if !registered {
            Log.info("Snippets hotkey registration failed (\(SnippetsPreferences.hotKeyText)).")
        }
    }

    private func registerTranslateHotKey() {
        guard let descriptor = HotKeyDescriptor.parse(TranslatePreferences.hotKeyText) else {
            hotKeyManager.unregister(identifier: translateHotKeyID)
            return
        }

        let registered = hotKeyManager.register(
            keyCode: descriptor.keyCode,
            modifiers: descriptor.modifiers,
            identifier: translateHotKeyID
        ) { [weak self] in
            // Carbon Event 线程：立即尝试 AX 捕获（此时前台 App 未切换）
            let axText: String?
            let bubbleAnchor: TranslationBubbleAnchor?
            // Carbon 热键由主事件分发器回调，此处保存触发瞬间的 Cocoa 全局坐标。
            // 不使用 CGEvent.location，后者采用与 NSScreen 不同的纵轴方向。
            let pointerLocation = NSEvent.mouseLocation

            if TranslatePreferences.autoCaptureSelectedText {
                if TranslatePreferences.showTranslationBubble {
                    let selection = Self.captureSelectionWithPosition()
                    axText = selection?.text
                    bubbleAnchor = TranslationBubbleAnchor(
                        selectionRect: selection?.screenRect,
                        pointerLocation: pointerLocation
                    )
                } else {
                    axText = Self.captureSelectedText()
                    bubbleAnchor = nil
                }
            } else {
                axText = nil
                bubbleAnchor = nil
            }

            DispatchQueue.main.async {
                guard let self else { return }

                // AX 失败则降级到剪贴板
                var finalText = axText
                if finalText == nil, TranslatePreferences.autoCaptureSelectedText {
                    finalText = Self.captureSelectedTextViaClipboard()
                }

                // 分支：气泡 vs 主窗口
                if TranslatePreferences.showTranslationBubble, let text = finalText, !text.isEmpty {
                    let anchor = bubbleAnchor ?? TranslationBubbleAnchor(
                        selectionRect: nil,
                        pointerLocation: pointerLocation
                    )
                    self.showTranslationBubble(with: text, near: anchor)
                } else {
                    guard let entry = PrefixRegistry.entries().first(where: { $0.providerID == TranslateProvider.providerID }) else { return }
                    self.launcherViewModel?.resetSearch()
                    self.launcherViewModel?.activateCustomPrefix(entry, carryQuery: finalText)
                    self.windowController?.show(resetSearch: false)
                    if finalText != nil {
                        self.windowController?.selectAllInSearchField()
                    }
                }
            }
        }

        if !registered {
            Log.info("Translate hotkey registration failed (\(TranslatePreferences.hotKeyText)).")
        }
    }

    // MARK: - Translation Bubble

    @MainActor
    private func showTranslationBubble(with text: String, near anchor: TranslationBubbleAnchor) {
        let controller = translationBubbleController ?? makeTranslationBubbleController()
        translationBubbleController = controller
        controller.show(with: text, near: anchor)
    }

    @MainActor
    private func makeTranslationBubbleController() -> TranslationBubbleController {
        let controller = TranslationBubbleController()
        controller.onDismiss = { [weak self, weak controller] in
            guard let self, let controller, self.translationBubbleController === controller else { return }
            self.translationBubbleController = nil
        }
        controller.onOpenInLauncher = { [weak self] sourceText in
            guard let self else { return }
            guard let entry = PrefixRegistry.entries().first(where: { $0.providerID == TranslateProvider.providerID }) else { return }
            self.launcherViewModel?.resetSearch()
            self.launcherViewModel?.activateCustomPrefix(entry, carryQuery: sourceText)
            self.windowController?.show(resetSearch: false)
            self.windowController?.selectAllInSearchField()
        }
        controller.onPrepareSettings = { [weak self] in
            self?.prepareSettingsTab(.translate)
        }
        controller.onOpenSettings = { [weak self] in
            self?.openSettingsViaCommand(tab: .translate)
        }
        return controller
    }

    /// 通过 Accessibility API 获取前台应用的选中文本，失败返回 nil。
    /// 必须在 FocusLite 窗口激活前调用，否则前台应用已变化。
    /// 可在任意线程调用（AX API 线程安全）。
    static func captureSelectedText() -> String? {
        guard AccessibilityPermission.isTrusted(prompt: false) else {
            Log.info("captureSelectedText: accessibility permission not granted")
            return nil
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            Log.info("captureSelectedText: no frontmost app")
            return nil
        }
        Log.info("captureSelectedText: frontmost app = \(app.localizedName ?? "?"), bundleID = \(app.bundleIdentifier ?? "?")")

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // 1) 从 focused element 自身获取
        var focusedElement: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
           let focused = focusedElement {
            let focusedAX = focused as! AXUIElement
            // 先查自身
            if let capture = copySelectedTextCapture(from: focusedAX) {
                return capture.text
            }
            // 再递归搜索 focused element 的子元素树（Web/Electron App 的选中文本在深层子元素上）
            if let text = findSelectedText(in: focusedAX, depth: 0, maxDepth: 5) {
                return text
            }
        }

        // 2) 从 focused window 树搜索
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            if let capture = copySelectedTextCapture(from: window as! AXUIElement) {
                return capture.text
            }
            if let text = findSelectedText(in: window as! AXUIElement, depth: 0, maxDepth: 5) {
                return text
            }
        }

        Log.info("captureSelectedText: AX approach failed")
        return nil
    }

    /// 同时保留真正提供选区的 AX element，避免递归命中后退回父容器定位。
    private static func copySelectedTextCapture(from element: AXUIElement) -> AXSelectedTextCapture? {
        var selectedText: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        guard result == .success, let text = selectedText as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        Log.info("captureSelectedText: AX success, length=\(trimmed.count)")
        return AXSelectedTextCapture(text: String(trimmed.prefix(500)), element: element)
    }

    /// 递归搜索子元素中的选中文本
    private static func findSelectedText(in element: AXUIElement, depth: Int, maxDepth: Int) -> String? {
        findSelectedTextCapture(in: element, depth: depth, maxDepth: maxDepth)?.text
    }

    /// 递归搜索选区，并返回实际命中的文本元素。
    private static func findSelectedTextCapture(
        in element: AXUIElement,
        depth: Int,
        maxDepth: Int
    ) -> AXSelectedTextCapture? {
        guard depth < maxDepth else { return nil }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let childrenArray = children as? [AXUIElement] else { return nil }

        for child in childrenArray {
            if let capture = copySelectedTextCapture(from: child) {
                return capture
            }
            if let capture = findSelectedTextCapture(in: child, depth: depth + 1, maxDepth: maxDepth) {
                return capture
            }
        }
        return nil
    }

    /// 降级方案：模拟 Cmd+C 从剪贴板获取选中文本。必须在主线程调用。
    static func captureSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount
        let oldItems = pasteboard.pasteboardItems?.map { item -> (types: [NSPasteboard.PasteboardType], data: [NSPasteboard.PasteboardType: Data]) in
            let types = item.types
            var dataMap: [NSPasteboard.PasteboardType: Data] = [:]
            for type in types {
                dataMap[type] = item.data(forType: type)
            }
            return (types, dataMap)
        }

        // 暂停剪贴板监控，避免记录本次操作
        let wasPaused = ClipboardPreferences.isPaused
        ClipboardPreferences.isPaused = true

        // 模拟 Cmd+C
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        // 等待剪贴板更新（不阻塞主线程事件循环）
        let deadline = Date(timeIntervalSinceNow: 0.15)
        while Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        var result: String? = nil
        if pasteboard.changeCount != oldChangeCount, let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                Log.info("captureSelectedText: clipboard fallback success, length=\(trimmed.count)")
                result = String(trimmed.prefix(500))
            }
        }

        // 恢复原始剪贴板内容
        pasteboard.clearContents()
        if let oldItems, !oldItems.isEmpty {
            let newItems = oldItems.map { old -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in old.data {
                    item.setData(data, forType: type)
                }
                return item
            }
            pasteboard.writeObjects(newItems)
        }

        // 恢复剪贴板监控状态
        ClipboardPreferences.isPaused = wasPaused

        if result == nil {
            Log.info("captureSelectedText: clipboard fallback also failed")
        }
        return result
    }

    // MARK: - Selection capture with position (for bubble positioning)

    /// 通过 AX API 获取选中文本及其屏幕位置，用于气泡定位。
    static func captureSelectionWithPosition() -> CapturedSelection? {
        guard AccessibilityPermission.isTrusted(prompt: false) else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focused = focusedElement else { return nil }

        let focusedAX = focused as! AXUIElement

        // 优先使用实际提供选区的元素，并尽可能定位到选区末端字符。
        if let capture = selectedTextCapture(in: focusedAX) {
            return capturedSelection(from: capture)
        }

        // 尝试 focused window
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            let windowAX = window as! AXUIElement
            if let capture = selectedTextCapture(in: windowAX) {
                return capturedSelection(from: capture)
            }
        }

        return nil
    }

    private static func selectedTextCapture(in element: AXUIElement) -> AXSelectedTextCapture? {
        copySelectedTextCapture(from: element)
            ?? findSelectedTextCapture(in: element, depth: 0, maxDepth: 5)
    }

    private static func capturedSelection(from capture: AXSelectedTextCapture) -> CapturedSelection {
        let rect = selectedTextScreenRect(of: capture.element)
        if rect == nil {
            Log.debug("captureSelectionWithPosition: precise AX bounds unavailable, using pointer anchor")
        }
        return CapturedSelection(text: capture.text, screenRect: rect)
    }

    /// 获取选区末端字符的边界；多行选区不会再以整个编辑器或大选区中心作为锚点。
    private static func selectedTextScreenRect(of element: AXUIElement) -> NSRect? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
        let rangeValue,
        CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selectedRange),
              selectedRange.location >= 0,
              selectedRange.length > 0 else {
            return nil
        }

        let endpointRange = CFRange(
            location: selectedRange.location + selectedRange.length - 1,
            length: 1
        )
        if let rect = boundsForRange(endpointRange, in: element) {
            return cocoaScreenRect(fromAXRect: rect)
        }

        // 某些应用不接受单字符范围，退回整个选区范围。
        if let rect = boundsForRange(selectedRange, in: element) {
            return cocoaScreenRect(fromAXRect: rect)
        }
        return nil
    }

    private static func boundsForRange(_ range: CFRange, in element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let parameter = AXValueCreate(.cfRange, &mutableRange) else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            parameter,
            &boundsValue
        ) == .success,
        let boundsValue,
        CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.width.isFinite,
              rect.height.isFinite,
              !rect.isEmpty else {
            return nil
        }
        return rect
    }

    /// AX 使用主显示器左上角原点；NSScreen 使用主显示器左下角原点。
    /// `NSScreen.screens.first` 是带菜单栏的主显示器，不会随当前活跃窗口改变。
    private static func cocoaScreenRect(fromAXRect rect: CGRect) -> NSRect? {
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let flippedY = primaryScreen.frame.maxY - rect.maxY
        return NSRect(x: rect.minX, y: flippedY, width: rect.width, height: rect.height)
    }
}

private struct AXSelectedTextCapture {
    let text: String
    let element: AXUIElement
}

/// 捕获到的选中文本及其屏幕矩形。
struct CapturedSelection {
    let text: String
    let screenRect: NSRect?
}

private final class OnboardingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
