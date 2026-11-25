//
//  SettingKey.swift
//  CoreApps
//

/// A setting the desktop serves through the settings portal, by its
/// namespace and key: the ones the Appearance pane shows and changes.
///
/// The names are those swift-linux-shell's settings service serves and
/// takes in `Set`, which are the portal's own and the GNOME ones GTK reads
/// through it.
public enum SettingKey: String, CaseIterable, Hashable, Sendable {

    // org.freedesktop.appearance

    /// `u`: no preference, dark or light.
    case colorScheme = "color-scheme"

    /// `(ddd)`: sRGB components from 0 to 1.
    case accentColor = "accent-color"

    /// `u`: normal or high.
    case contrast = "contrast"

    // org.gnome.desktop.interface

    /// `s`: a Pango font description, such as `Inter 10`.
    case fontName = "font-name"

    /// `s`: a Pango font description.
    case monospaceFontName = "monospace-font-name"

    /// `s`: an icon theme's directory name.
    case iconTheme = "icon-theme"

    /// `s`: a cursor theme's directory name.
    case cursorTheme = "cursor-theme"

    /// `i`: the cursor's size in pixels.
    case cursorSize = "cursor-size"

    // org.gnome.desktop.wm.preferences

    /// `s`: window buttons, in GNOME's syntax.
    case buttonLayout = "button-layout"

    /// The key's name in its namespace.
    public var name: String {
        rawValue
    }

    public var namespace: String {
        switch self {
        case .colorScheme, .accentColor, .contrast:
            SettingKey.appearanceNamespace
        case .fontName, .monospaceFontName, .iconTheme, .cursorTheme, .cursorSize:
            SettingKey.interfaceNamespace
        case .buttonLayout:
            SettingKey.windowManagerNamespace
        }
    }

    /// The key a namespace and name are, if it's one of these.
    public init?(namespace: String, name: String) {
        guard let key = SettingKey(rawValue: name), key.namespace == namespace else {
            return nil
        }
        self = key
    }

    /// The portal's standard namespace.
    public static let appearanceNamespace = "org.freedesktop.appearance"

    /// GNOME's interface settings.
    public static let interfaceNamespace = "org.gnome.desktop.interface"

    /// GNOME's window manager settings.
    public static let windowManagerNamespace = "org.gnome.desktop.wm.preferences"

    /// Every namespace a key is in, as `ReadAll` is asked for them.
    public static let namespaces = [appearanceNamespace, interfaceNamespace, windowManagerNamespace]
}
