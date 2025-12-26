import Foundation

enum Log {
    static func info(_ message: String) {
        print("[FocusLite] \(message)")
    }

    static func debug(_ message: String) {
        #if DEBUG
        print("[FocusLite][Debug] \(message)")
        #endif
    }
}
