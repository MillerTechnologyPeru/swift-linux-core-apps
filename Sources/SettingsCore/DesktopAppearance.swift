//
//  DesktopAppearance.swift
//  CoreApps
//

/// The desktop's appearance, as the settings portal serves it. A value is
/// `nil` when the portal didn't serve it.
public struct DesktopAppearance: Hashable, Sendable {

    public var colorScheme: ColorSchemePreference?

    public var accentColor: AccentColor?

    public var contrast: ContrastPreference?

    public var fontName: FontDescription?

    public var monospaceFontName: FontDescription?

    public var iconTheme: String?

    public var cursorTheme: String?

    public var cursorSize: Int?

    public var buttonLayout: ButtonLayout?

    public init(
        colorScheme: ColorSchemePreference? = nil,
        accentColor: AccentColor? = nil,
        contrast: ContrastPreference? = nil,
        fontName: FontDescription? = nil,
        monospaceFontName: FontDescription? = nil,
        iconTheme: String? = nil,
        cursorTheme: String? = nil,
        cursorSize: Int? = nil,
        buttonLayout: ButtonLayout? = nil
    ) {
        self.colorScheme = colorScheme
        self.accentColor = accentColor
        self.contrast = contrast
        self.fontName = fontName
        self.monospaceFontName = monospaceFontName
        self.iconTheme = iconTheme
        self.cursorTheme = cursorTheme
        self.cursorSize = cursorSize
        self.buttonLayout = buttonLayout
    }

    /// The appearance a `ReadAll` reply's values describe, keyed by
    /// namespace and then key. What isn't one of the keys is left out.
    public init(values: [String: [String: SettingValue]]) {
        self.init()
        for (namespace, keys) in values {
            for (name, value) in keys {
                if let key = SettingKey(namespace: namespace, name: name) {
                    apply(value, for: key)
                }
            }
        }
    }
}

// MARK: - Values

/// The portal's `color-scheme`.
public enum ColorSchemePreference: UInt32, CaseIterable, Hashable, Sendable {

    /// No preference: apps choose, and most are light.
    case automatic = 0

    case dark = 1

    case light = 2

    /// The preference a value names. The portal says to read values it
    /// doesn't define as no preference.
    public init(portalValue: UInt32) {
        self = ColorSchemePreference(rawValue: portalValue) ?? .automatic
    }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// The order the choices are shown in.
    public static let shown: [ColorSchemePreference] = [.light, .dark, .automatic]
}

/// The portal's `contrast`.
public enum ContrastPreference: UInt32, CaseIterable, Hashable, Sendable {

    case normal = 0

    case high = 1

    /// Values the portal doesn't define are normal contrast.
    public init(portalValue: UInt32) {
        self = ContrastPreference(rawValue: portalValue) ?? .normal
    }
}

// MARK: - Reading and writing

public extension DesktopAppearance {

    /// Sets the value a key names from what the portal sent, in `ReadAll`,
    /// `ReadOne` or `SettingChanged`. Returns whether the appearance
    /// changed; a value of the wrong type changes nothing.
    @discardableResult
    mutating func apply(_ value: SettingValue, for key: SettingKey) -> Bool {
        guard key.accepts(value) else {
            return false
        }
        let old = self
        switch (key, value) {
        case let (.colorScheme, .uint32(raw)):
            colorScheme = ColorSchemePreference(portalValue: raw)
        case let (.contrast, .uint32(raw)):
            contrast = ContrastPreference(portalValue: raw)
        case let (.accentColor, .color(red, green, blue)):
            // Components out of 0 to 1 mean the accent isn't set.
            accentColor = AccentColor(portalRed: red, green: green, blue: blue)
        case let (.fontName, .string(text)):
            fontName = FontDescription(text)
        case let (.monospaceFontName, .string(text)):
            monospaceFontName = FontDescription(text)
        case let (.iconTheme, .string(name)):
            iconTheme = name
        case let (.cursorTheme, .string(name)):
            cursorTheme = name
        case let (.cursorSize, .int32(size)):
            cursorSize = Int(size)
        case let (.buttonLayout, .string(setting)):
            buttonLayout = ButtonLayout(setting: setting)
        default:
            break
        }
        return self != old
    }

    /// Applies a `SettingChanged(s namespace, s key, v value)`. Returns
    /// whether the appearance changed.
    @discardableResult
    mutating func apply(namespace: String, key name: String, value: SettingValue) -> Bool {
        guard let key = SettingKey(namespace: namespace, name: name) else {
            return false
        }
        return apply(value, for: key)
    }

    /// The value a key has, as `Set` takes it, or `nil` if it isn't known.
    func value(for key: SettingKey) -> SettingValue? {
        switch key {
        case .colorScheme:
            colorScheme.map { .uint32($0.rawValue) }
        case .contrast:
            contrast.map { .uint32($0.rawValue) }
        case .accentColor:
            accentColor.map { .color(red: $0.red, green: $0.green, blue: $0.blue) }
        case .fontName:
            fontName.map { .string($0.description) }
        case .monospaceFontName:
            monospaceFontName.map { .string($0.description) }
        case .iconTheme:
            iconTheme.map { .string($0) }
        case .cursorTheme:
            cursorTheme.map { .string($0) }
        case .cursorSize:
            cursorSize.map { .int32(Int32(clamping: $0)) }
        case .buttonLayout:
            buttonLayout.map { .string($0.setting) }
        }
    }

    /// The keys whose values differ from another appearance's, with their
    /// new values: what to send `Set` to make the desktop this.
    func changes(from old: DesktopAppearance) -> [(key: SettingKey, value: SettingValue)] {
        SettingKey.allCases.compactMap { key in
            guard let value = value(for: key), value != old.value(for: key) else {
                return nil
            }
            return (key, value)
        }
    }
}
