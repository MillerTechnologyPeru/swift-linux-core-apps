//
//  SettingValue.swift
//  CoreApps
//

/// A setting's value as the portal sends it, and as the settings service's
/// `Set` takes it in its variant.
public enum SettingValue: Hashable, Sendable {

    case uint32(UInt32)

    case int32(Int32)

    case string(String)

    case bool(Bool)

    /// `(ddd)`: sRGB components.
    case color(red: Double, green: Double, blue: Double)
}

public extension SettingKey {

    /// Whether a value has the type this key's values have, so a value
    /// of another type, from a portal that disagrees, is ignored.
    func accepts(_ value: SettingValue) -> Bool {
        switch (self, value) {
        case (.colorScheme, .uint32), (.contrast, .uint32):
            true
        case (.accentColor, .color):
            true
        case (.fontName, .string), (.monospaceFontName, .string), (.iconTheme, .string),
             (.cursorTheme, .string), (.buttonLayout, .string):
            true
        case (.cursorSize, .int32):
            true
        default:
            false
        }
    }
}
