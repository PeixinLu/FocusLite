import Cocoa
import SwiftUI

final class TranslateSettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: TranslateSettingsViewModel

    init(viewModel: TranslateSettingsViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        createWindowIfNeeded()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }
        let contentRect = NSRect(x: 0, y: 0, width: 620, height: 640)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "翻译设置"
        window.center()
        window.delegate = self

        let rootView = TranslateSettingsView(viewModel: self.viewModel)
        window.contentView = NSHostingView(rootView: rootView)
        self.window = window
    }
}
