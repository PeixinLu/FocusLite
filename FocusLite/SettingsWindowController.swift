import Cocoa
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    func show(tab: SettingsTab = .clipboard) {
        viewModel.selectedTab = tab
        createWindowIfNeeded()
        guard let window else {
            Log.info("Settings window was not created.")
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 520)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusLite 设置"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        let rootView = SettingsView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
