//
//  CatalogApp.swift
//  CoreApps
//

/// An app a software source offers, from its AppStream catalog.
public struct CatalogApp: Equatable, Identifiable, Sendable {

    /// The app's identifier: `org.gnome.Calculator`.
    public var id: String

    public var name: String

    /// One line on what it does.
    public var summary: String

    /// The paragraphs and lists describing it.
    public var description: [DescriptionBlock]

    public var developer: String

    /// An SPDX expression: `GPL-3.0-or-later`, or `LicenseRef-proprietary`.
    public var license: String

    /// freedesktop.org categories: `Utility`, `Calculator`.
    public var categories: [String]

    public var keywords: [String]

    /// The cached icon's file name, under the catalog's `icons/64x64` and
    /// `icons/128x128`.
    public var icon: String?

    public var homepage: String?

    /// Latest first.
    public var releases: [Release]

    /// What the source installs: for Flatpak, `app/<id>/<arch>/<branch>`.
    public var bundle: String?

    /// A program with a window, rather than one for a terminal.
    public var isGraphical: Bool

    public init(
        id: String,
        name: String,
        summary: String = "",
        description: [DescriptionBlock] = [],
        developer: String = "",
        license: String = "",
        categories: [String] = [],
        keywords: [String] = [],
        icon: String? = nil,
        homepage: String? = nil,
        releases: [Release] = [],
        bundle: String? = nil,
        isGraphical: Bool = true
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.description = description
        self.developer = developer
        self.license = license
        self.categories = categories
        self.keywords = keywords
        self.icon = icon
        self.homepage = homepage
        self.releases = releases
        self.bundle = bundle
        self.isGraphical = isGraphical
    }

    /// The newest stable release, or else the newest.
    public var latestRelease: Release? {
        releases.first { $0.isStable } ?? releases.first
    }

    /// The branch the bundle names: `stable`.
    public var branch: String? {
        guard let bundle else { return nil }
        let parts = bundle.split(separator: "/")
        return parts.count == 4 ? String(parts[3]) : nil
    }

    /// The first category that's one of the store's own.
    public var category: AppCategory? {
        AppCategory.primary(for: categories)
    }

    /// Whether the license lets anyone use, change and share the app.
    public var isFreeSoftware: Bool {
        License.isFree(license)
    }
}

/// A paragraph of a description, or a list in it.
public enum DescriptionBlock: Equatable, Sendable {
    case paragraph(String)
    case list([String])
}

/// A version of an app.
public struct Release: Equatable, Sendable {

    public var version: String

    /// Seconds since 1970, or 0 when the catalog doesn't say.
    public var timestamp: Int

    /// `stable` or `development`.
    public var isStable: Bool

    /// What changed, as the catalog lists it.
    public var notes: [DescriptionBlock]

    public init(version: String, timestamp: Int = 0, isStable: Bool = true, notes: [DescriptionBlock] = []) {
        self.version = version
        self.timestamp = timestamp
        self.isStable = isStable
        self.notes = notes
    }
}
