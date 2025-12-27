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
        let contentRect = NSRect(x: 0, y: 0, width: 720, height: 680)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.center()
        window.delegate = self

        let rootView = SettingsView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)
        self.window = window
    }
}
