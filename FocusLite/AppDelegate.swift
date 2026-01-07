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
    private lazy var settingsWindowController = SettingsWindowController(viewModel: settingsViewModel)
    private var statusItem: NSStatusItem?
    private var clipboardPauseItem: NSMenuItem?
    private let launcherHotKeyID: UInt32 = 1
    private let clipboardHotKeyID: UInt32 = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置为 accessory 模式，不显示 Dock 图标，只显示菜单栏图标
        NSApp.setActivationPolicy(.accessory)
        
        let providers: [any ResultProvider] = [
            CalcProvider(),
            SnippetsProvider(),
            ClipboardProvider(),
            TranslateProvider(),
            AppSearchProvider()
        ]
        let searchEngine = SearchEngine(providers: providers)
        let viewModel = LauncherViewModel(searchEngine: searchEngine)
        launcherViewModel = viewModel
        viewModel.onExit = { [weak self] in
            self?.windowController?.hide()
        }
        viewModel.onOpenSettings = { [weak self] tab in
            self?.showSettings(tab: tab)
        }
        viewModel.onPrepareSettings = { [weak self] tab in
            self?.settingsViewModel.selectedTab = tab
            self?.windowController?.prepareForSettingsOpen()
        }
        viewModel.onPaste = { [weak self] text in
            self?.windowController?.pasteTextAndHide(text) ?? false
        }

        windowController = LauncherWindowController(viewModel: viewModel)
        
        // 设置回调：唤起搜索框时关闭设置页
        windowController?.onCloseSettings = { [weak self] in
            self?.settingsWindowController.close()
        }
        
        setupStatusItem()
        registerLauncherHotKey()
        registerClipboardHotKey()
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

    @MainActor private func showSettings(tab: SettingsTab) {
        settingsViewModel.selectedTab = tab
        windowController?.prepareForSettingsOpen()
        let openedBySystem = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            || NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        if !openedBySystem {
            settingsWindowController.show(tab: tab)
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
        clipboardPauseItem?.state = ClipboardPreferences.isPaused ? .on : .off
        registerLauncherHotKey()
        registerClipboardHotKey()
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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: "FocusLite")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏 FocusLite", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(showSettingsWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))

        let clipboardPause = NSMenuItem(title: "暂停剪贴板记录", action: #selector(toggleClipboardRecording), keyEquivalent: "")
        clipboardPause.state = ClipboardPreferences.isPaused ? .on : .off
        menu.addItem(clipboardPause)
        clipboardPauseItem = clipboardPause

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 FocusLite", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func registerLauncherHotKey() {
        guard let descriptor = HotKeyDescriptor.parse(GeneralPreferences.launcherHotKeyText) else {
            hotKeyManager.unregister(identifier: launcherHotKeyID)
            Log.info("Launcher hotkey is invalid. Use format like command+space.")
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
}
