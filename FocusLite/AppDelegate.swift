import Carbon.HIToolbox
import Cocoa
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LauncherWindowController?
    private var launcherViewModel: LauncherViewModel?
    private let clipboardMonitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager.shared
    private let appUpdater = AppUpdater.shared
    lazy var settingsViewModel: SettingsViewModel = {
        let generalSettingsViewModel = GeneralSettingsViewModel()
        let snippetsViewModel = SnippetsManagerViewModel(store: .shared)
        let clipboardSettingsViewModel = ClipboardSettingsViewModel()
        let translateSettingsViewModel = TranslateSettingsViewModel()
        return SettingsViewModel(
            generalViewModel: generalSettingsViewModel,
            appUpdater: appUpdater,
            clipboardViewModel: clipboardSettingsViewModel,
            snippetsViewModel: snippetsViewModel,
            translateViewModel: translateSettingsViewModel
        )
    }()
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

        windowController = LauncherWindowController(viewModel: viewModel)
        
        registerLauncherHotKey()
        registerClipboardHotKey()
        registerSnippetsHotKey()
        registerTranslateHotKey()
        windowController?.show()
        clipboardMonitor.start()
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
                self?.toggleWindow()
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
