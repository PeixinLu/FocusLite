import Cocoa
import SwiftUI

final class LauncherWindowController: NSObject, NSWindowDelegate {
    private let viewModel: LauncherViewModel
    private var window: NSWindow?
    private let showOnAllSpaces = true
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var suppressRestoreFocusOnResign = false
    
    // 用于关闭设置页的回调
    var onCloseSettings: (() -> Void)?

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    func show(resetSearch: Bool = true) {
        // 先关闭设置页（如果打开了）
        onCloseSettings?()
        
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

    func prepareForSettingsOpen() {
        guard window?.isVisible == true else { return }
        suppressRestoreFocusOnResign = true
    }

    func hide(restoreFocus: Bool = true) {
        stopKeyMonitor()
        window?.orderOut(nil)
        if restoreFocus {
            previousApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
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

        hide(restoreFocus: false)
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

            if event.modifierFlags.contains(.command), event.keyCode == 43 {
                Task { @MainActor in
                    self.viewModel.prepareSettings(tab: .clipboard)
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
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isSwitchingWithinApp = frontmostID == Bundle.main.bundleIdentifier
        let shouldRestore = !suppressRestoreFocusOnResign && !isSwitchingWithinApp
        suppressRestoreFocusOnResign = false
        hide(restoreFocus: shouldRestore)
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
