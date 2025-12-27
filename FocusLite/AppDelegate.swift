import Carbon.HIToolbox
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LauncherWindowController?
    private var snippetsWindowController: SnippetsManagerWindowController?
    private var clipboardSettingsWindowController: ClipboardSettingsWindowController?
    private var translateSettingsWindowController: TranslateSettingsWindowController?
    private var launcherViewModel: LauncherViewModel?
    private let clipboardMonitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager.shared
    private var statusItem: NSStatusItem?
    private var clipboardPauseItem: NSMenuItem?
    private let launcherHotKeyID: UInt32 = 1
    private let clipboardHotKeyID: UInt32 = 2

    func applicationDidFinishLaunching(_ notification: Notification) {
        let providers: [any ResultProvider] = [
            CalcProvider(),
            SnippetsProvider(),
            ClipboardProvider(),
            TranslateProvider(),
            AppSearchProvider(),
            MockProvider()
        ]
        let searchEngine = SearchEngine(providers: providers)
        let viewModel = LauncherViewModel(searchEngine: searchEngine)
        launcherViewModel = viewModel
        viewModel.onExit = { [weak self] in
            self?.windowController?.hide()
        }
        viewModel.onOpenSnippetsManager = { [weak self] in
            self?.showSnippetsManager()
        }
        viewModel.onPaste = { [weak self] text in
            self?.windowController?.pasteTextAndHide(text) ?? false
        }

        let snippetsViewModel = SnippetsManagerViewModel(store: .shared)
        let clipboardSettingsViewModel = ClipboardSettingsViewModel()
        let translateSettingsViewModel = TranslateSettingsViewModel()
        windowController = LauncherWindowController(viewModel: viewModel)
        snippetsWindowController = SnippetsManagerWindowController(viewModel: snippetsViewModel)
        clipboardSettingsWindowController = ClipboardSettingsWindowController(viewModel: clipboardSettingsViewModel)
        translateSettingsWindowController = TranslateSettingsWindowController(viewModel: translateSettingsViewModel)
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

    @objc private func showSnippetsManager() {
        snippetsWindowController?.show()
    }

    @objc private func showClipboardSettings() {
        clipboardSettingsWindowController?.show()
    }

    @objc private func showTranslateSettings() {
        translateSettingsWindowController?.show()
    }

    @objc private func toggleClipboardRecording() {
        ClipboardPreferences.isPaused.toggle()
        handleUserDefaultsChange()
    }

    @objc private func handleUserDefaultsChange() {
        clipboardPauseItem?.state = ClipboardPreferences.isPaused ? .on : .off
        registerClipboardHotKey()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: "FocusLite")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle FocusLite", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snippets...", action: #selector(showSnippetsManager), keyEquivalent: ""))

        let clipboardPause = NSMenuItem(title: "Pause Clipboard Recording", action: #selector(toggleClipboardRecording), keyEquivalent: "")
        clipboardPause.state = ClipboardPreferences.isPaused ? .on : .off
        menu.addItem(clipboardPause)
        clipboardPauseItem = clipboardPause

        menu.addItem(NSMenuItem(title: "Clipboard Settings...", action: #selector(showClipboardSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "翻译设置...", action: #selector(showTranslateSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FocusLite", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func registerLauncherHotKey() {
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(cmdKey)
        let registered = hotKeyManager.register(keyCode: keyCode, modifiers: modifiers, identifier: launcherHotKeyID) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }

        if !registered {
            Log.info("Global hotkey registration failed (Cmd+Space). Use the menu bar icon instead.")
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
                self?.windowController?.show()
                self?.launcherViewModel?.activateClipboardSearch()
            }
        }

        if !registered {
            Log.info("Clipboard hotkey registration failed (\(ClipboardPreferences.hotKeyText)).")
        }
    }
}
