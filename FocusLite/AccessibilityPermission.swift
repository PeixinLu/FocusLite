import ApplicationServices
import Cocoa
import Foundation

struct AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 请求并返回最新的授权状态，优先弹出系统对话框
    static func requestIfNeeded() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }
        return isTrusted(prompt: true)
    }
}

extension Notification.Name {
    static let permissionsShouldRefresh = Notification.Name("permissionsShouldRefresh")
}
