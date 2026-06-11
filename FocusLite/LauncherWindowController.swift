import Cocoa
import SwiftUI
import Combine

@MainActor
final class LauncherWindowController: NSObject, NSWindowDelegate {
    enum FocusOrigin {
        case external(NSRunningApplication)
        case appWindow(Int)
        case unknown
    }

    private let viewModel: LauncherViewModel
    private var window: NSWindow?
    private let showOnAllSpaces = true
    private var keyMonitor: Any?
    private var focusOrigin: FocusOrigin = .unknown
    private var wasInterrupted = false
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
        super.init()
        setupSizeObserver()
    }

    /// 垂直：GeometryReader 逐帧跟随 SwiftUI spring
    /// 水平：所有 x 由 windowCenterX 派生 — 窗口逻辑锚点设在顶部几何中心
    private func setupSizeObserver() {
        viewModel.$currentViewSize
            .removeDuplicates()
            .sink { [weak self] size in
                self?.followWindowSize(size)
            }
            .store(in: &cancellables)
    }

    /// 窗口顶部几何中心的 x 坐标，所有 x 定位始终由它派生
    private var windowCenterX: CGFloat = 0

    private func followWindowSize(_ size: CGSize) {
        guard let window else { return }
        let currentFrame = window.frame
        guard abs(currentFrame.width - size.width) > 0.5 || abs(currentFrame.height - size.height) > 0.5 else { return }

        let newY = currentFrame.maxY - size.height
        let newX = windowCenterX - size.width / 2

        window.setFrame(
            NSRect(x: newX, y: newY, width: size.width, height: size.height),
            display: true,
            animate: false
        )
    }

    func show(resetSearch: Bool = true) {
        createWindowIfNeeded()
        if resetSearch {
            viewModel.resetSearch()
        } else {
            // Hotkey-prefix path: disable animation so window opens at final size
            let hasContent: Bool = {
                if case .prefixed = viewModel.searchState.scope { return true }
                return !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                viewModel.isExpanded = hasContent
            }
        }
        captureFocusOrigin()
        wasInterrupted = false
        // 在首次定位前锁定水平锚点
        if let screenFrame = NSScreen.main?.visibleFrame {
            windowCenterX = screenFrame.midX
        }
        syncWindowSize()
        centerWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startKeyMonitor()
        Task { @MainActor in
            viewModel.requestFocus()
        }
    }

    /// 无动画同步设到目标尺寸（show 前调用，确保 centerWindow 基于正确 frame）
    private func syncWindowSize() {
        guard let window else { return }
        let targetSize = viewModel.currentViewSize
        guard abs(window.frame.width - targetSize.width) > 0.5 || abs(window.frame.height - targetSize.height) > 0.5 else { return }
        let currentFrame = window.frame
        let newY = currentFrame.maxY - targetSize.height
        let newX = windowCenterX - targetSize.width / 2
        window.setFrame(
            NSRect(x: newX, y: newY, width: targetSize.width, height: targetSize.height),
            display: false
        )
    }

    func hide(restoreBehavior: LauncherViewModel.ExitBehavior = .restoreOrigin) {
        stopKeyMonitor()
        window?.orderOut(nil)
        viewModel.resetSearch()
        guard restoreBehavior == .restoreOrigin, !wasInterrupted else { return }
        restoreFocusOrigin()
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func pasteTextAndHide(_ text: String) -> Bool {
        guard AccessibilityPermission.requestIfNeeded() else {
            return false
        }

        hide(restoreBehavior: .restoreOrigin)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.sendPasteCommand()
        }
        return true
    }

    /// 选中搜索框中所有文本，用于自动带入选中文本后方便用户直接替换输入。
    func selectAllInSearchField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let window = self?.window,
                  let editor = window.firstResponder as? NSTextView else { return }
            editor.selectAll(nil)
        }
    }

    private func createWindowIfNeeded() {
        guard window == nil else { return }

        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 56)
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
        if #available(macOS 14, *) {
            hostingView.layer?.wantsExtendedDynamicRangeContent = true
        }
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
                    self.viewModel.prepareSettings(tab: self.viewModel.preferredSettingsTab())
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
                if let editor = self.window?.firstResponder as? NSTextView, editor.hasMarkedText() {
                    return event
                }
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
            let x = windowCenterX - window.frame.width / 2
            // 顶部距离屏幕上边缘 30%
            let windowTop = screenFrame.maxY - screenFrame.height * 0.3
            let y = windowTop - window.frame.height
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }

    private func captureFocusOrigin() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            focusOrigin = .unknown
            return
        }
        if frontmost.bundleIdentifier == Bundle.main.bundleIdentifier {
            // 如果本身已经是前台窗口（如搜索框已在前），不记录以免关闭时重新唤醒自己
            focusOrigin = .unknown
        } else {
            focusOrigin = .external(frontmost)
        }
    }

    private func restoreFocusOrigin() {
        switch focusOrigin {
        case .external(let app):
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        case .appWindow(let windowNumber):
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.window(withWindowNumber: windowNumber) {
                window.makeKeyAndOrderFront(nil)
            }
        case .unknown:
            break
        }
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
        guard window?.isVisible == true else { return }
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if frontmostID != Bundle.main.bundleIdentifier {
            wasInterrupted = true
        }
        hide(restoreBehavior: .none)
    }
}

final class LauncherWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
