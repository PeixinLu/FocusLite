import Carbon.HIToolbox
import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LauncherWindowController?
    private let hotKeyManager = HotKeyManager.shared
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let providers: [any ResultProvider] = [MockProvider()]
        let searchEngine = SearchEngine(providers: providers)
        let viewModel = LauncherViewModel(searchEngine: searchEngine)
        viewModel.onExit = { [weak self] in
            self?.windowController?.hide()
        }

        windowController = LauncherWindowController(viewModel: viewModel)
        setupStatusItem()
        registerHotKey()
        windowController?.show()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func toggleWindow() {
        windowController?.toggle()
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
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FocusLite", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    private func registerHotKey() {
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(cmdKey)
        let registered = hotKeyManager.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }

        if !registered {
            Log.info("Global hotkey registration failed (Cmd+Space). Use the menu bar icon instead.")
        }
    }
}
