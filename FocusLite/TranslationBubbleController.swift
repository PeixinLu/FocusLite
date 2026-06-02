import Cocoa
import SwiftUI

/// Manages the floating translation bubble window — non-activating, auto-dismissing,
/// positioned near the selected text.
@MainActor
final class TranslationBubbleController: NSObject {
    private var window: NSWindow?
    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var translationObserver: NSObjectProtocol?
    private var translationTask: Task<Void, Never>?
    private var isDismissing = false

    private var sourceText: String = ""
    private var result: TranslationResult?
    private var isLoading = false
    private var focusOrigin: NSRunningApplication?

    var onDismiss: (() -> Void)?
    var onOpenInLauncher: ((String) -> Void)?
    var onPrepareSettings: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    // MARK: - Show / Dismiss

    func show(with text: String, near screenRect: NSRect?) {
        closeWindow(notify: false)
        isDismissing = false

        sourceText = text
        result = nil
        isLoading = true
        focusOrigin = NSWorkspace.shared.frontmostApplication

        createWindow()
        positionWindow(near: screenRect)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        startMonitors()
        startTranslation(text: text)
    }

    func dismiss() {
        closeWindow(notify: true)
    }

    private func closeWindow(notify: Bool) {
        guard !isDismissing else { return }
        isDismissing = true
        stopMonitors()
        window?.orderOut(nil)
        window = nil
        result = nil
        isLoading = false
        translationTask?.cancel()
        translationTask = nil
        if notify {
            onDismiss?()
        }
        isDismissing = false
    }

    // MARK: - Window

    private func createWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 300, height: 100)
        let window = BubbleWindow(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.isMovableByWindowBackground = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.delegate = self

        self.window = window
        rebuildContentView()
    }

    private func rebuildContentView() {
        let rootView = TranslationBubbleView(
            sourceText: sourceText,
            translationResult: result,
            isLoading: isLoading,
            onCopy: { text in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            },
            onOpenInLauncher: { [weak self] in
                guard let self else { return }
                let capturedText = self.sourceText
                self.dismiss()
                self.onOpenInLauncher?(capturedText)
            },
            onPrepareSettings: { [weak self] in
                self?.onPrepareSettings?()
            },
            onOpenSettings: { [weak self] in
                guard let self else { return }
                let openSettings = self.onOpenSettings
                self.dismiss()
                openSettings?()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true

        // 自适应大小
        let fittingSize = hostingView.fittingSize
        let width: CGFloat = 300
        let height = max(80, min(fittingSize.height, 360))

        window?.setContentSize(NSSize(width: width, height: height))
        window?.contentView = hostingView
    }

    private func updateContentView() {
        rebuildContentView()
    }

    // MARK: - Positioning

    private func positionWindow(near screenRect: NSRect?) {
        guard let window = window else { return }

        let bubbleSize = window.frame.size
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let anchorPoint: NSPoint

        if let rect = screenRect {
            // 定位在选中元素下方，水平居中
            let centerX = rect.midX - bubbleSize.width / 2
            let belowY = rect.minY - bubbleSize.height - 8

            if belowY - bubbleSize.height > visibleFrame.minY {
                anchorPoint = NSPoint(x: centerX, y: belowY)
            } else {
                // 下方空间不够，放到上方
                let aboveY = rect.maxY + 8
                anchorPoint = NSPoint(x: centerX, y: aboveY)
            }
        } else {
            // 降级：定位在鼠标附近
            let mouseLoc = NSEvent.mouseLocation
            anchorPoint = NSPoint(
                x: mouseLoc.x - bubbleSize.width / 2,
                y: mouseLoc.y - bubbleSize.height - 20
            )
        }

        // 钳制到可见区域
        let clampedX = max(visibleFrame.minX + 8,
                           min(anchorPoint.x, visibleFrame.maxX - bubbleSize.width - 8))
        let clampedY = max(visibleFrame.minY + 8,
                           min(anchorPoint.y, visibleFrame.maxY - bubbleSize.height - 8))

        window.setFrame(NSRect(origin: NSPoint(x: clampedX, y: clampedY), size: bubbleSize), display: false)
    }

    // MARK: - Translation

    private func startTranslation(text: String) {
        translationTask?.cancel()
        translationTask = Task {
            let results = await TranslationCoordinator.shared.translate(text: text)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard !Task.isCancelled, self.window?.isVisible == true, self.sourceText == text else { return }
                self.isLoading = false
                // 只取第一条翻译结果
                self.result = results.first
                self.updateContentView()
            }
        }

        // 同时监听流式更新通知（增量更新）
        translationObserver = NotificationCenter.default.addObserver(
            forName: .translationResultsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let query = info[TranslationCoordinator.queryKey] as? String,
                  let results = info[TranslationCoordinator.resultsKey] as? [TranslationResult],
                  query == self.sourceText else { return }

            self.isLoading = false
            self.result = results.first
            self.updateContentView()
        }
    }

    // MARK: - Event Monitors

    private func startMonitors() {
        stopMonitors()

        // 全局鼠标监听：点击气泡外部 → 关闭
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let window = self.window, window.isVisible else { return }
            let clickLocation = NSEvent.mouseLocation
            if !window.frame.contains(clickLocation) {
                DispatchQueue.main.async {
                    self.dismiss()
                }
            }
        }

        // 本地键盘监听：Esc → 关闭（窗口必须是 key 才能收到）
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isVisible == true else { return event }
            switch event.keyCode {
            case 36, 76: // Return, keypad enter
                if self.acceptTranslation() {
                    return nil
                }
                return event
            case 53: // Escape
                self.dismiss()
                return nil
            default:
                return event
            }
        }
    }

    private func acceptTranslation() -> Bool {
        guard let translatedText = result?.translatedText, !translatedText.isEmpty else {
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedText, forType: .string)

        guard TranslatePreferences.autoPasteAfterSelect else {
            dismiss()
            return true
        }

        guard AccessibilityPermission.requestIfNeeded() else {
            dismiss()
            return true
        }

        let origin = focusOrigin
        dismiss()
        origin?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.sendPasteCommand()
        }
        return true
    }

    private static func sendPasteCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(9) // v
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func stopMonitors() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let observer = translationObserver {
            NotificationCenter.default.removeObserver(observer)
            translationObserver = nil
        }
    }

    deinit {
        translationTask?.cancel()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = translationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Bubble Window

/// Borderless floating window that can become key to receive keyboard/mouse events,
/// without activating the app.
private final class BubbleWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Window Delegate

extension TranslationBubbleController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // 气泡失去焦点时自动关闭
        dismiss()
    }
}
