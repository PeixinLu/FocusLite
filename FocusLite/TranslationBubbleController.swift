import Cocoa
import SwiftUI

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}

/// Manages the floating translation bubble window — non-activating, auto-dismissing,
/// positioned near the selected text.
enum TranslationBubblePersistence {
    case transient
    case pinned

    init(isPinned: Bool) {
        self = isPinned ? .pinned : .transient
    }

    var allowsAutomaticDismissal: Bool {
        self == .transient
    }
}

private struct TranslationDirectionOverride: Equatable {
    let sourceLanguage: String
    let targetLanguage: String
}

/// 气泡定位所需的稳定锚点。精确选区不可用时，使用快捷键触发瞬间的鼠标位置。
struct TranslationBubbleAnchor {
    let selectionRect: NSRect?
    let pointerLocation: NSPoint
}

enum TranslationBubblePlacement {
    /// 依次尝试下、上、右、左；若都无法完整显示，则选择可见面积最大的候选并裁剪。
    static func bestFrame(size: NSSize, anchorRect: NSRect, visibleFrame: NSRect) -> NSRect {
        let gap: CGFloat = 8
        let margin: CGFloat = 8
        let usableFrame = visibleFrame.insetBy(dx: margin, dy: margin)
        let candidates = [
            NSRect(
                x: anchorRect.midX - size.width / 2,
                y: anchorRect.minY - size.height - gap,
                width: size.width,
                height: size.height
            ),
            NSRect(
                x: anchorRect.midX - size.width / 2,
                y: anchorRect.maxY + gap,
                width: size.width,
                height: size.height
            ),
            NSRect(
                x: anchorRect.maxX + gap,
                y: anchorRect.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            NSRect(
                x: anchorRect.minX - size.width - gap,
                y: anchorRect.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        ]

        if let fittingCandidate = candidates.first(where: { usableFrame.contains($0) }) {
            return fittingCandidate
        }

        let bestCandidate = candidates.max {
            $0.intersection(usableFrame).area < $1.intersection(usableFrame).area
        } ?? candidates[0]
        let maxX = max(usableFrame.minX, usableFrame.maxX - size.width)
        let maxY = max(usableFrame.minY, usableFrame.maxY - size.height)
        return NSRect(
            x: min(max(bestCandidate.minX, usableFrame.minX), maxX),
            y: min(max(bestCandidate.minY, usableFrame.minY), maxY),
            width: size.width,
            height: size.height
        )
    }
}

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
    private var persistence = TranslationBubblePersistence(isPinned: TranslatePreferences.translationBubblePinned)
    private var directionOverride: TranslationDirectionOverride?
    private var selectedTargetLanguage: String?
    private var currentAnchor: TranslationBubbleAnchor?

    var onDismiss: (() -> Void)?
    var onOpenInLauncher: ((String) -> Void)?
    var onPrepareSettings: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    // MARK: - Show / Dismiss

    func show(with text: String, near anchor: TranslationBubbleAnchor) {
        let shouldKeepPinnedPosition = window?.isVisible == true && persistence == .pinned
        if !shouldKeepPinnedPosition {
            closeWindow(notify: false)
            persistence = TranslationBubblePersistence(isPinned: TranslatePreferences.translationBubblePinned)
        }
        isDismissing = false

        sourceText = text
        result = nil
        isLoading = true
        focusOrigin = NSWorkspace.shared.frontmostApplication
        directionOverride = nil
        selectedTargetLanguage = nil
        currentAnchor = anchor

        if shouldKeepPinnedPosition {
            updateContentView()
        } else {
            createWindow()
            positionWindow(near: anchor)
        }
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
        currentAnchor = nil
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
        window.collectionBehavior = collectionBehavior
        window.isMovableByWindowBackground = true
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
            isPinned: persistence == .pinned,
            currentTargetLanguage: currentTargetLanguage,
            languageOptions: TranslatePreferences.languageOptions,
            onCopy: { text in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            },
            onTogglePinned: { [weak self] in
                self?.togglePinned()
            },
            onSwapDirection: { [weak self] in
                self?.swapDirection()
            },
            onTargetLanguageChange: { [weak self] language in
                self?.changeTargetLanguage(to: language)
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

        let hostingView = MovableHostingView(rootView: rootView)
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
        if persistence == .transient, let currentAnchor {
            positionWindow(near: currentAnchor)
        }
    }

    private var collectionBehavior: NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if persistence == .transient {
            behavior.insert(.transient)
        }
        return behavior
    }

    private func togglePinned() {
        persistence = persistence == .pinned ? .transient : .pinned
        TranslatePreferences.translationBubblePinned = persistence == .pinned
        window?.collectionBehavior = collectionBehavior
        updateContentView()
    }

    // MARK: - Positioning

    private func positionWindow(near anchor: TranslationBubbleAnchor) {
        guard let window = window else { return }

        let bubbleSize = window.frame.size
        let screen = targetScreen(for: anchor)
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let anchorRect = anchor.selectionRect ?? NSRect(origin: anchor.pointerLocation, size: .zero)
        let frame = TranslationBubblePlacement.bestFrame(
            size: bubbleSize,
            anchorRect: anchorRect,
            visibleFrame: visibleFrame
        )
        window.setFrame(frame, display: false)
    }

    private func targetScreen(for anchor: TranslationBubbleAnchor) -> NSScreen? {
        if let rect = anchor.selectionRect {
            let bestScreen = NSScreen.screens.max { lhs, rhs in
                lhs.frame.intersection(rect).area < rhs.frame.intersection(rect).area
            }
            if let bestScreen, bestScreen.frame.intersection(rect).area > 0 {
                return bestScreen
            }
        }
        return NSScreen.screens.first { NSMouseInRect(anchor.pointerLocation, $0.frame, false) }
            ?? NSScreen.screens.first
    }

    // MARK: - Translation

    private func startTranslation(text: String) {
        translationTask?.cancel()
        if let observer = translationObserver {
            NotificationCenter.default.removeObserver(observer)
            translationObserver = nil
        }
        let directionOverride = directionOverride
        let selectedTargetLanguage = selectedTargetLanguage
        translationTask = Task {
            let results: [TranslationResult]
            if let directionOverride {
                results = await TranslationCoordinator.shared.translate(
                    text: text,
                    sourceLanguage: directionOverride.sourceLanguage,
                    targetLanguage: directionOverride.targetLanguage
                )
            } else if let selectedTargetLanguage {
                results = await TranslationCoordinator.shared.translate(
                    text: text,
                    targetLanguage: selectedTargetLanguage
                )
            } else {
                results = await TranslationCoordinator.shared.translate(text: text)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard !Task.isCancelled, self.window?.isVisible == true, self.sourceText == text else { return }
                guard self.matchesCurrentDirection(results.first) else { return }
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
            guard self.matchesCurrentDirection(results.first) else { return }

            self.isLoading = false
            self.result = results.first
            self.updateContentView()
        }
    }

    private func matchesCurrentDirection(_ result: TranslationResult?) -> Bool {
        guard let result else { return true }
        if let directionOverride {
            return result.sourceLanguage == directionOverride.sourceLanguage &&
                result.targetLanguage == directionOverride.targetLanguage
        }
        if let selectedTargetLanguage {
            return TranslatePreferences.normalizedLanguageCode(result.targetLanguage) ==
                TranslatePreferences.normalizedLanguageCode(selectedTargetLanguage)
        }
        return true
    }

    private func swapDirection() {
        guard let result else { return }
        directionOverride = TranslationDirectionOverride(
            sourceLanguage: result.targetLanguage,
            targetLanguage: result.sourceLanguage
        )
        selectedTargetLanguage = result.sourceLanguage
        self.result = nil
        isLoading = true
        updateContentView()
        startTranslation(text: sourceText)
    }

    private var currentTargetLanguage: String {
        if let selectedTargetLanguage {
            return selectedTargetLanguage
        }
        if let result {
            return result.targetLanguage
        }
        if let detected = LanguageDetector.detect(sourceText) {
            return TranslatePreferences.automaticTargetLanguage(for: detected.code)
        }
        return TranslatePreferences.secondaryLanguage
    }

    private func changeTargetLanguage(to language: String) {
        guard TranslatePreferences.normalizedLanguageCode(language) !=
                TranslatePreferences.normalizedLanguageCode(currentTargetLanguage) else { return }
        selectedTargetLanguage = language
        directionOverride = nil
        result = nil
        isLoading = true
        updateContentView()
        startTranslation(text: sourceText)
    }

    // MARK: - Event Monitors

    private func startMonitors() {
        stopMonitors()

        // 全局鼠标监听：点击气泡外部 → 关闭
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let window = self.window, window.isVisible else { return }
            guard self.persistence.allowsAutomaticDismissal else { return }
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

private final class MovableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

// MARK: - Window Delegate

extension TranslationBubbleController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // 气泡失去焦点时自动关闭
        if persistence.allowsAutomaticDismissal {
            dismiss()
        }
    }
}
