//
//  SettingsCoreTests.swift
//  CoreApps
//

import Foundation
import Testing
@testable import SettingsCore

// MARK: - Keys

@Test func keysAreInTheirNamespaces() {
    #expect(SettingKey(namespace: "org.freedesktop.appearance", name: "color-scheme") == .colorScheme)
    #expect(SettingKey(namespace: "org.freedesktop.appearance", name: "accent-color") == .accentColor)
    #expect(SettingKey(namespace: "org.gnome.desktop.interface", name: "cursor-size") == .cursorSize)
    #expect(SettingKey(namespace: "org.gnome.desktop.wm.preferences", name: "button-layout") == .buttonLayout)
    // GNOME's own color-scheme is a string in another namespace, which the
    // portal's standard one stands for.
    #expect(SettingKey(namespace: "org.gnome.desktop.interface", name: "color-scheme") == nil)
    #expect(SettingKey(namespace: "org.freedesktop.appearance", name: "reduced-motion") == nil)
    #expect(Set(SettingKey.allCases.map(\.namespace)) == Set(SettingKey.namespaces))
}

@Test func keysTakeOnlyTheirType() {
    #expect(SettingKey.colorScheme.accepts(.uint32(1)))
    #expect(!SettingKey.colorScheme.accepts(.string("prefer-dark")))
    #expect(SettingKey.cursorSize.accepts(.int32(24)))
    #expect(!SettingKey.cursorSize.accepts(.uint32(24)))
    #expect(SettingKey.accentColor.accepts(.color(red: 0, green: 0, blue: 1)))
    #expect(!SettingKey.buttonLayout.accepts(.bool(true)))
}

// MARK: - Appearance

/// What swift-linux-shell's settings service serves by default.
let served: [String: [String: SettingValue]] = [
    "org.freedesktop.appearance": [
        "color-scheme": .uint32(1),
        "accent-color": .color(red: 0.21, green: 0.52, blue: 0.89),
        "contrast": .uint32(0),
    ],
    "org.gnome.desktop.interface": [
        "color-scheme": .string("prefer-dark"),
        "font-name": .string("Inter 10"),
        "monospace-font-name": .string("JetBrains Mono 10"),
        "icon-theme": .string("elementary"),
        "cursor-theme": .string("Adwaita"),
        "cursor-size": .int32(24),
    ],
    "org.gnome.desktop.wm.preferences": [
        "button-layout": .string("close,minimize,maximize:"),
    ],
]

@Test func readsWhatThePortalServes() {
    let appearance = DesktopAppearance(values: served)
    #expect(appearance.colorScheme == .dark)
    #expect(appearance.accentColor?.name == "Blue")
    #expect(appearance.contrast == .normal)
    #expect(appearance.fontName == FontDescription(family: "Inter", size: 10))
    #expect(appearance.monospaceFontName == FontDescription(family: "JetBrains Mono", size: 10))
    #expect(appearance.iconTheme == "elementary")
    #expect(appearance.cursorTheme == "Adwaita")
    #expect(appearance.cursorSize == 24)
    #expect(appearance.buttonLayout?.preset == .left)
}

@Test func nothingServedIsNothingSet() {
    let appearance = DesktopAppearance(values: [:])
    #expect(appearance == DesktopAppearance())
    #expect(appearance.colorScheme == nil)
    #expect(SettingKey.allCases.allSatisfy { appearance.value(for: $0) == nil })
}

@Test func readsValuesAsThePortalSaysTo() {
    var appearance = DesktopAppearance()
    // A color scheme the portal doesn't define is no preference.
    let changed1 = appearance.apply(.uint32(7), for: .colorScheme)
    #expect(changed1)
    #expect(appearance.colorScheme == .automatic)
    // And a contrast it doesn't define is normal.
    appearance.apply(.uint32(9), for: .contrast)
    #expect(appearance.contrast == .normal)
    // Components out of 0 to 1 are no accent.
    appearance.apply(.color(red: 0.5, green: 0.5, blue: 0.5), for: .accentColor)
    #expect(appearance.accentColor != nil)
    appearance.apply(.color(red: -1, green: -1, blue: -1), for: .accentColor)
    #expect(appearance.accentColor == nil)
}

@Test func ignoresValuesOfTheWrongType() {
    var appearance = DesktopAppearance(values: served)
    let before = appearance
    let changed2 = appearance.apply(.string("prefer-light"), for: .colorScheme)
    #expect(!changed2)
    let changed3 = appearance.apply(.uint32(32), for: .cursorSize)
    #expect(!changed3)
    #expect(appearance == before)
}

@Test func appliesChangeSignals() {
    var appearance = DesktopAppearance(values: served)
    let changed4 = appearance.apply(namespace: "org.freedesktop.appearance", key: "color-scheme", value: .uint32(2))
    #expect(changed4)
    #expect(appearance.colorScheme == .light)
    // The same value again changes nothing.
    let changed5 = appearance.apply(namespace: "org.freedesktop.appearance", key: "color-scheme", value: .uint32(2))
    #expect(!changed5)
    // Keys this doesn't show change nothing.
    let changed6 = appearance.apply(namespace: "org.gnome.desktop.interface", key: "color-scheme", value: .string("default"))
    #expect(!changed6)
    let changed7 = appearance.apply(namespace: "org.example", key: "color-scheme", value: .uint32(1))
    #expect(!changed7)
    let changed8 = appearance.apply(namespace: "org.gnome.desktop.wm.preferences", key: "button-layout", value: .string("appmenu:close"))
    #expect(changed8)
    #expect(appearance.buttonLayout?.preset == .gnome)
}

@Test func writesValuesAsSetTakesThem() {
    let appearance = DesktopAppearance(values: served)
    #expect(appearance.value(for: .colorScheme) == .uint32(1))
    #expect(appearance.value(for: .accentColor) == .color(red: 0.21, green: 0.52, blue: 0.89))
    #expect(appearance.value(for: .fontName) == .string("Inter 10"))
    #expect(appearance.value(for: .cursorSize) == .int32(24))
    #expect(appearance.value(for: .buttonLayout) == .string("close,minimize,maximize:"))
    // Every value read writes back as it was served.
    for key in SettingKey.allCases {
        #expect(appearance.value(for: key) == served[key.namespace]?[key.name], "\(key)")
    }
}

@Test func listsChanges() {
    let old = DesktopAppearance(values: served)
    var new = old
    new.colorScheme = .light
    new.cursorSize = 48
    let changes = new.changes(from: old)
    #expect(changes.map(\.key) == [.colorScheme, .cursorSize])
    #expect(changes.map(\.value) == [.uint32(2), .int32(48)])
    #expect(old.changes(from: old).isEmpty)
}

@Test func colorSchemesAreShownLightFirst() {
    #expect(ColorSchemePreference.shown == [.light, .dark, .automatic])
    #expect(Set(ColorSchemePreference.shown) == Set(ColorSchemePreference.allCases))
    #expect(ColorSchemePreference.automatic.rawValue == 0)
    #expect(ColorSchemePreference.dark.rawValue == 1)
    #expect(ColorSchemePreference.light.rawValue == 2)
}

// MARK: - Accents

@Test func namesPaletteAccents() {
    #expect(AccentColor(hex: 0x3584E4).name == "Blue")
    #expect(AccentColor(hex: 0x9141AC).name == "Purple")
    // Rounded to two places, as the settings service's default is.
    #expect(AccentColor(red: 0.21, green: 0.52, blue: 0.89).name == "Blue")
    // A color of its own has no name.
    #expect(AccentColor(red: 0.6, green: 0.2, blue: 0.8).name == nil)
    #expect(Set(AccentColor.palette.map(\.name)).count == AccentColor.palette.count)
}

@Test func readsHexComponents() {
    let color = AccentColor(hex: 0xFF8000)
    #expect(color.red == 1)
    #expect(abs(color.green - 128.0 / 255) < 1e-9)
    #expect(color.blue == 0)
    #expect(AccentColor(portalRed: 1.2, green: 0, blue: 0) == nil)
    #expect(AccentColor(portalRed: 1, green: 0, blue: 0) == AccentColor(red: 1, green: 0, blue: 0))
}

// MARK: - Window buttons

@Test func readsButtonLayouts() {
    #expect(ButtonLayout(setting: "close,minimize,maximize:").preset == .left)
    #expect(ButtonLayout(setting: ":minimize,maximize,close").preset == .right)
    #expect(ButtonLayout(setting: "appmenu:close").preset == .gnome)
    // Spaces don't matter.
    #expect(ButtonLayout(setting: " close , minimize, maximize : ").preset == .left)
    // Without a colon it's all leading.
    #expect(ButtonLayout(setting: "close,minimize,maximize") == ButtonLayout(leading: ["close", "minimize", "maximize"]))
    // Names other than buttons are kept.
    let custom = ButtonLayout(setting: "icon:minimize,spacer,close")
    #expect(custom.preset == nil)
    #expect(custom.leading == ["icon"])
    #expect(custom.trailing == ["minimize", "spacer", "close"])
    #expect(ButtonLayout(setting: "").leading.isEmpty)
}

@Test func writesButtonLayouts() {
    #expect(ButtonLayout.Preset.left.layout.setting == "close,minimize,maximize:")
    #expect(ButtonLayout.Preset.right.layout.setting == ":minimize,maximize,close")
    #expect(ButtonLayout.Preset.gnome.layout.setting == "appmenu:close")
    for preset in ButtonLayout.Preset.allCases {
        #expect(ButtonLayout(setting: preset.layout.setting).preset == preset)
    }
}

// MARK: - Fonts

@Test func readsFontDescriptions() {
    #expect(FontDescription("Inter 10") == FontDescription(family: "Inter", size: 10))
    #expect(FontDescription("JetBrains Mono Bold 11.5") == FontDescription(family: "JetBrains Mono Bold", size: 11.5))
    #expect(FontDescription("Cantarell") == FontDescription(family: "Cantarell", size: nil))
    // Runs of spaces are one.
    #expect(FontDescription("Inter  12") == FontDescription(family: "Inter", size: 12))
    // A size of nothing isn't one.
    #expect(FontDescription("Source Code Pro 0").size == nil)
    #expect(FontDescription("12") == FontDescription(family: "12", size: nil))
}

@Test func writesFontDescriptions() {
    #expect(FontDescription(family: "Inter", size: 10).description == "Inter 10")
    #expect(FontDescription(family: "Inter", size: 10.5).description == "Inter 10.5")
    #expect(FontDescription(family: "Cantarell").description == "Cantarell")
    #expect(FontDescription.format(11.04) == "11")
}

// MARK: - Themes

@Test func findsInstalledThemes() throws {
    let files = FileManager.default
    let root = files.temporaryDirectory.appendingPathComponent("settings-themes-\(UUID().uuidString)")
    defer { try? files.removeItem(at: root) }
    let user = root.appendingPathComponent("home/.icons")
    let system = root.appendingPathComponent("usr/share/icons")
    func theme(_ directory: URL, _ name: String, index: String?, cursors: Bool) throws {
        let theme = directory.appendingPathComponent(name)
        try files.createDirectory(at: theme, withIntermediateDirectories: true)
        if let index {
            try index.write(to: theme.appendingPathComponent("index.theme"), atomically: true, encoding: .utf8)
        }
        if cursors {
            try files.createDirectory(at: theme.appendingPathComponent("cursors"), withIntermediateDirectories: true)
        }
    }
    try theme(system, "Adwaita", index: "[Icon Theme]\nName=Adwaita\nDirectories=16x16/apps,scalable/apps\n", cursors: true)
    try theme(system, "hicolor", index: "[Icon Theme]\nName=Hicolor\nDirectories=48x48/apps\n", cursors: false)
    try theme(system, "default", index: "[Icon Theme]\nInherits=Adwaita\n", cursors: false)
    try theme(system, "DMZ-White", index: "[Icon Theme]\nName=DMZ (White)\nInherits=DMZ-Black\n", cursors: true)
    try theme(system, "elementary", index: "[Icon Theme]\nDirectories = actions/16\n", cursors: false)
    try theme(user, "Bibata", index: nil, cursors: true)
    try theme(user, "elementary", index: "[Icon Theme]\nDirectories=apps/24\n", cursors: false)

    let themes = Themes(searching: [user, root.appendingPathComponent("missing"), system])
    #expect(themes.iconThemes == ["Adwaita", "elementary"])
    #expect(themes.cursorThemes == ["Adwaita", "Bibata", "DMZ-White"])
}

@Test func looksForThemesWhereTheSpecificationSays() {
    let directories = Themes.searchDirectories(environment: [
        "HOME": "/home/me",
        "XDG_DATA_DIRS": "/usr/local/share:/usr/share",
    ]).map(\.path)
    #expect(directories == ["/home/me/.icons", "/home/me/.local/share/icons", "/usr/local/share/icons", "/usr/share/icons"])
    let custom = Themes.searchDirectories(environment: ["HOME": "/home/me", "XDG_DATA_HOME": "/data", "XDG_DATA_DIRS": "/opt/share"]).map(\.path)
    #expect(custom == ["/home/me/.icons", "/data/icons", "/opt/share/icons"])
}

@Test func offersTheCurrentThemeAndSize() {
    #expect(Themes.choices(["Adwaita"], current: "elementary") == ["elementary", "Adwaita"])
    #expect(Themes.choices(["Adwaita"], current: "Adwaita") == ["Adwaita"])
    #expect(Themes.choices(["Adwaita"], current: nil) == ["Adwaita"])
    #expect(CursorSize.choices(current: 24) == CursorSize.sizes)
    #expect(CursorSize.choices(current: 40) == [24, 32, 40, 48, 64, 96])
    #expect(CursorSize.choices(current: nil) == CursorSize.sizes)
}

// MARK: - Panes

@Test func listsEveryPaneOnce() {
    let listed = SettingsPane.groups.flatMap(\.panes)
    #expect(listed.count == SettingsPane.allCases.count)
    #expect(Set(listed) == Set(SettingsPane.allCases))
    #expect(SettingsPane.allCases.filter(\.isAvailable) == [.appearance])
    #expect(SettingsPane.allCases.allSatisfy { $0.isAvailable == ($0.plannedService == nil) })
}
