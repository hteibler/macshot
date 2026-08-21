import AppKit
import Carbon.HIToolbox

enum HotKeyFormatter {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        return result
    }

    static func displayString(for hotKey: HotKeyCombo) -> String {
        var symbols = ""
        if hotKey.modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if hotKey.modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if hotKey.modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if hotKey.modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + hotKey.displayKey
    }
}
