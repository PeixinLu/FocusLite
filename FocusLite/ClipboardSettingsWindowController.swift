import Cocoa
import SwiftUI

final class ClipboardSettingsWindowController: NSObject, NSWindowDelegate {
    private let viewModel: ClipboardSettingsViewModel
    private var window: NSWindow?

    init(viewModel: ClipboardSettingsViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        createWindowIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: 540, height: 460)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Clipboard Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let rootView = ClipboardSettingsView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)

        self.window = window
    }
}
