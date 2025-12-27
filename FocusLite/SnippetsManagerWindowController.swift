import Cocoa
import SwiftUI

final class SnippetsManagerWindowController: NSObject, NSWindowDelegate {
    private let viewModel: SnippetsManagerViewModel
    private var window: NSWindow?

    init(viewModel: SnippetsManagerViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        createWindowIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 520)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Snippets"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let rootView = SnippetsManagerView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)

        self.window = window
    }
}
