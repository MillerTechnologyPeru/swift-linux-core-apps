//
//  InstalledApp.swift
//  CoreApps
//

/// Where software comes from.
public enum SoftwareSource: String, Hashable, Sendable {

    /// Flatpak, from its remotes, such as Flathub.
    case flatpak

    /// AppRuntime bundles, installed with `linux-app install`.
    case appRuntime

    public var name: String {
        switch self {
        case .flatpak: "Flatpak"
        case .appRuntime: "AppRuntime"
        }
    }
}

/// Whose an installed app is.
public enum Installation: String, Hashable, Sendable {

    /// The user's own: in `~/.local`, and changed without asking.
    case user

    /// Everyone's: changing it asks for an administrator's password.
    case system

    public var name: String {
        switch self {
        case .user: "Just for You"
        case .system: "For Everyone"
        }
    }
}

/// An app that's installed.
public struct InstalledApp: Equatable, Identifiable, Sendable {

    public var appID: String

    public var name: String

    public var version: String

    public var source: SoftwareSource

    public var installation: Installation

    /// For Flatpak: the branch, such as `stable`.
    public var branch: String

    /// For Flatpak: the remote it came from, such as `flathub`.
    public var origin: String

    /// The space it takes, as the source says it: `202.9 MB`.
    public var size: String

    /// For an AppRuntime bundle: where it is.
    public var path: String?

    /// The same app can be installed for the user and for everyone.
    public var id: String {
        source.rawValue + ":" + installation.rawValue + ":" + appID
    }

    public init(
        appID: String,
        name: String,
        version: String = "",
        source: SoftwareSource,
        installation: Installation,
        branch: String = "",
        origin: String = "",
        size: String = "",
        path: String? = nil
    ) {
        self.appID = appID
        self.name = name
        self.version = version
        self.source = source
        self.installation = installation
        self.branch = branch
        self.origin = origin
        self.size = size
        self.path = path
    }
}

/// A newer version of an installed app.
public struct AvailableUpdate: Equatable, Identifiable, Sendable {

    public var appID: String

    public var installation: Installation

    /// The version it updates to, when the remote says.
    public var version: String

    public var branch: String

    public var origin: String

    public var id: String {
        installation.rawValue + ":" + appID
    }

    public init(appID: String, installation: Installation, version: String = "", branch: String = "", origin: String = "") {
        self.appID = appID
        self.installation = installation
        self.version = version
        self.branch = branch
        self.origin = origin
    }
}
