//
//  DesktopBus.swift
//  CoreApps
//

#if canImport(DBus)

import DBus

/// Where the desktop's settings are on the session bus.
///
/// The settings service's names are swift-linux-shell's, as its
/// `CacaoShellKit.ShellDBus` has them. They're written out here rather
/// than taken from that package, which would bring the shell's compositor
/// and its wlroots into the apps' build for a handful of strings.
public enum DesktopBus {

    // MARK: The settings portal

    /// xdg-desktop-portal, which apps read settings from.
    public static let portalName = DBusBusName(rawValue: "org.freedesktop.portal.Desktop")!

    /// The path the portal, and every portal backend, serves.
    public static let portalPath = DBusObjectPath(rawValue: "/org/freedesktop/portal/desktop")!

    public static let portalInterface = DBusInterface(rawValue: "org.freedesktop.portal.Settings")!

    /// The settings service, as the portal's backend for settings.
    public static let backendName = DBusBusName(rawValue: "org.freedesktop.impl.portal.desktop.cacao")!

    public static let backendInterface = DBusInterface(rawValue: "org.freedesktop.impl.portal.Settings")!

    public static let readAll = DBusMember(rawValue: "ReadAll")!

    public static let settingChanged = DBusMember(rawValue: "SettingChanged")!

    // MARK: The settings service

    /// The settings service, which keeps the settings and takes changes.
    public static let settingsName = DBusBusName(rawValue: "org.pureswift.Cacao.Settings")!

    public static let settingsPath = DBusObjectPath(rawValue: "/org/pureswift/Cacao/Settings")!

    public static let settingsInterface = DBusInterface(rawValue: "org.pureswift.Cacao.Settings1")!

    /// `Set(s namespace, s key, v value)`.
    public static let set = DBusMember(rawValue: "Set")!
}

#endif
