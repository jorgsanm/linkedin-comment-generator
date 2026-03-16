import Carbon
import Foundation

public struct HotKeyOption: Identifiable, Hashable, Sendable {
    public var keyCode: UInt32
    public var label: String

    public var id: UInt32 { keyCode }

    public init(keyCode: UInt32, label: String) {
        self.keyCode = keyCode
        self.label = label
    }
}

public enum HotKeyCatalog {
    public static let commonKeys: [HotKeyOption] = [
        HotKeyOption(keyCode: UInt32(kVK_ANSI_A), label: "A"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_B), label: "B"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_C), label: "C"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_D), label: "D"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_E), label: "E"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_F), label: "F"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_G), label: "G"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_H), label: "H"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_I), label: "I"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_J), label: "J"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_K), label: "K"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_L), label: "L"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_M), label: "M"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_N), label: "N"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_O), label: "O"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_P), label: "P"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Q), label: "Q"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_R), label: "R"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_S), label: "S"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_T), label: "T"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_U), label: "U"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_V), label: "V"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_W), label: "W"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_X), label: "X"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Y), label: "Y"),
        HotKeyOption(keyCode: UInt32(kVK_ANSI_Z), label: "Z")
    ]

    public static func label(for configuration: HotKeyConfiguration) -> String {
        let modifierLabels: [String] = [
            configuration.modifiers & UInt32(controlKey) != 0 ? "Control" : nil,
            configuration.modifiers & UInt32(optionKey) != 0 ? "Option" : nil,
            configuration.modifiers & UInt32(cmdKey) != 0 ? "Command" : nil,
            configuration.modifiers & UInt32(shiftKey) != 0 ? "Shift" : nil
        ].compactMap { $0 }

        let keyLabel = commonKeys.first(where: { $0.keyCode == configuration.keyCode })?.label ?? "?"
        return (modifierLabels + [keyLabel]).joined(separator: " + ")
    }
}
