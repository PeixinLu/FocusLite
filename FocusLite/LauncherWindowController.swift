import Cocoa
import SwiftUI

final class LauncherWindowController {
    private let viewModel: LauncherViewModel
    private var window: NSWindow?
    private let showOnAllSpaces = true

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        createWindowIfNeeded()
        centerWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        Task { @MainActor in
            viewModel.requestFocus()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 420)
        let window = LauncherWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        if showOnAllSpaces {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.fullScreenAuxiliary]
        }
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let rootView = LauncherView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView
        window.makeFirstResponder(hostingView)

        self.window = window
    }

    private func centerWindow() {
        guard let window = window else { return }
        if let screenFrame = NSScreen.main?.visibleFrame {
            let x = screenFrame.midX - window.frame.width / 2
            let y = screenFrame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
