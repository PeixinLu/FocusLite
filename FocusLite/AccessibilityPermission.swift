import ApplicationServices
import Cocoa
import Foundation

struct AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

extension Notification.Name {
    static let permissionsShouldRefresh = Notification.Name("permissionsShouldRefresh")
}
