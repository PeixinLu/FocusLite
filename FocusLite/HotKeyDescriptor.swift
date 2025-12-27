import Carbon.HIToolbox
import Foundation

struct HotKeyDescriptor: Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    static func parse(_ text: String) -> HotKeyDescriptor? {
        let tokens = text
            .lowercased()
            .replacingOccurrences(of: "+", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }

        guard !tokens.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        var keyToken: String?

        for token in tokens {
            if let modifier = modifierFlag(for: token) {
                modifiers |= modifier
                continue
            }
            if keyToken == nil {
                keyToken = token
            } else {
                return nil
            }
        }

        guard let keyToken else { return nil }
        if keyToken == "space" {
            return HotKeyDescriptor(keyCode: UInt32(kVK_Space), modifiers: modifiers)
        }

        guard keyToken.count == 1, let char = keyToken.first else { return nil }
        guard let keyCode = keyCodeMap[char] else { return nil }
        return HotKeyDescriptor(keyCode: keyCode, modifiers: modifiers)
    }

    private static func modifierFlag(for token: String) -> UInt32? {
        switch token {
        case "cmd", "command":
            return UInt32(cmdKey)
        case "opt", "option", "alt":
            return UInt32(optionKey)
        case "shift":
            return UInt32(shiftKey)
        case "ctrl", "control":
            return UInt32(controlKey)
        default:
            return nil
        }
    }

    private static let keyCodeMap: [Character: UInt32] = [
        "a": UInt32(kVK_ANSI_A),
        "b": UInt32(kVK_ANSI_B),
        "c": UInt32(kVK_ANSI_C),
        "d": UInt32(kVK_ANSI_D),
        "e": UInt32(kVK_ANSI_E),
        "f": UInt32(kVK_ANSI_F),
        "g": UInt32(kVK_ANSI_G),
        "h": UInt32(kVK_ANSI_H),
        "i": UInt32(kVK_ANSI_I),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "l": UInt32(kVK_ANSI_L),
        "m": UInt32(kVK_ANSI_M),
        "n": UInt32(kVK_ANSI_N),
        "o": UInt32(kVK_ANSI_O),
        "p": UInt32(kVK_ANSI_P),
        "q": UInt32(kVK_ANSI_Q),
        "r": UInt32(kVK_ANSI_R),
        "s": UInt32(kVK_ANSI_S),
        "t": UInt32(kVK_ANSI_T),
        "u": UInt32(kVK_ANSI_U),
        "v": UInt32(kVK_ANSI_V),
        "w": UInt32(kVK_ANSI_W),
        "x": UInt32(kVK_ANSI_X),
        "y": UInt32(kVK_ANSI_Y),
        "z": UInt32(kVK_ANSI_Z),
        "0": UInt32(kVK_ANSI_0),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "5": UInt32(kVK_ANSI_5),
        "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "9": UInt32(kVK_ANSI_9)
    ]
}
