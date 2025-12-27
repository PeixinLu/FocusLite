import ApplicationServices
import Foundation

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool) -> Bool {
        let options: [String: Any] = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
