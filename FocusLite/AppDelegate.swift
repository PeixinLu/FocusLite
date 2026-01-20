import Carbon.HIToolbox
import Cocoa
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LauncherWindowController?
    private var launcherViewModel: LauncherViewModel?
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
            }
        )
    }()
    private var onboardingWindow: NSWindow?
    private var onboardingCancellable: AnyCancellable?
    private var onboardingEscMonitor: Any?
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
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovable = true
            panel.isFloatingPanel = true
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
            if event.keyCode == 53 { // esc
                self?.onboardingState.dismiss(markSeen: true)
                return nil
            }
            return event
        }
    }

    private func stopOnboardingEscMonitor() {
        if let monitor = onboardingEscMonitor {
            NSEvent.removeMonitor(monitor)
            onboardingEscMonitor = nil
        }
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
            DispatchQueue.main.async {
                guard let entry = PrefixRegistry.entries().first(where: { $0.providerID == TranslateProvider.providerID }) else { return }
                self?.launcherViewModel?.resetSearch()
                self?.launcherViewModel?.activateCustomPrefix(entry)
                self?.windowController?.show(resetSearch: false)
            }
        }

        if !registered {
            Log.info("Translate hotkey registration failed (\(TranslatePreferences.hotKeyText)).")
        }
    }
}
