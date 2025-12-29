import Cocoa
import SwiftUI

final class LauncherWindowController: NSObject, NSWindowDelegate {
    private let viewModel: LauncherViewModel
    private var window: NSWindow?
    private let showOnAllSpaces = true
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    func show(resetSearch: Bool = true) {
        createWindowIfNeeded()
        if resetSearch {
            Task { @MainActor in
                viewModel.resetSearch()
            }
        }
        capturePreviousApp()
        centerWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startKeyMonitor()
        Task { @MainActor in
            viewModel.requestFocus()
        }
    }

    func hide() {
        stopKeyMonitor()
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func pasteTextAndHide(_ text: String) -> Bool {
        guard AccessibilityPermission.isTrusted(prompt: true) else {
            return false
        }

        hide()
        previousApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.sendPasteCommand()
        }
        return true
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
        window.delegate = self

        let rootView = LauncherView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView
        window.makeFirstResponder(hostingView)

        self.window = window
    }

    private func startKeyMonitor() {
        stopKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window?.isVisible == true, self.window?.isKeyWindow == true else { return event }
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 43 {
                    Task { @MainActor in
                        self.viewModel.openSettings(tab: .clipboard)
                    }
                    return nil
                }
                return event
            }

            switch event.keyCode {
            case 125: // down arrow
                Task { @MainActor in
                    self.viewModel.moveSelection(delta: 1)
                }
                return nil
            case 126: // up arrow
                Task { @MainActor in
                    self.viewModel.moveSelection(delta: -1)
                }
                return nil
            case 51: // delete / backspace
                let handled = self.viewModel.handleBackspaceKey()
                return handled ? nil : event
            case 53: // esc
                Task { @MainActor in
                    self.viewModel.handleEscapeKey()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
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

    private func capturePreviousApp() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        guard frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = frontmost
    }

    private func sendPasteCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(9) // v
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

extension LauncherWindowController {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
