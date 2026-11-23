//
//  AppCategory.swift
//  CoreApps
//

/// The kinds of app the store is browsed by: freedesktop.org's main
/// categories, named for people.
public enum AppCategory: String, CaseIterable, Identifiable, Sendable {

    case audioVideo = "AudioVideo"
    case development = "Development"
    case education = "Education"
    case game = "Game"
    case graphics = "Graphics"
    case network = "Network"
    case office = "Office"
    case science = "Science"
    case system = "System"
    case utility = "Utility"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .audioVideo: "Audio & Video"
        case .development: "Developer Tools"
        case .education: "Education"
        case .game: "Games"
        case .graphics: "Graphics & Photos"
        case .network: "Internet"
        case .office: "Productivity"
        case .science: "Science"
        case .system: "System"
        case .utility: "Utilities"
        }
    }

    /// An SF Symbol for it, of those Cacao draws.
    public var symbol: String {
        switch self {
        case .audioVideo: "music.note"
        case .development: "hammer"
        case .education: "graduationcap"
        case .game: "gamecontroller"
        case .graphics: "paintpalette"
        case .network: "globe"
        case .office: "doc.text"
        case .science: "atom"
        case .system: "gear"
        case .utility: "wrench"
        }
    }

    /// The first of `categories` that's a main one. `Audio` and `Video`
    /// alone, which some apps give without `AudioVideo`, count as it.
    public static func primary(for categories: [String]) -> AppCategory? {
        for category in categories {
            if let main = AppCategory(rawValue: category) {
                return main
            }
            if category == "Audio" || category == "Video" {
                return .audioVideo
            }
        }
        return nil
    }

    /// Whether an app with `categories` belongs here.
    public func contains(_ categories: [String]) -> Bool {
        categories.contains(rawValue) || (self == .audioVideo && (categories.contains("Audio") || categories.contains("Video")))
    }
}

/// What an SPDX license expression says about the freedom to use, change
/// and share an app.
public enum License {

    /// `false` for a proprietary license, or none: an expression with a
    /// `LicenseRef-` (Flathub's `LicenseRef-proprietary`) or nothing at all.
    public static func isFree(_ expression: String) -> Bool {
        let trimmed = expression.trimmingWhitespace
        return !trimmed.isEmpty && !trimmed.contains("LicenseRef-")
    }
}

extension String {

    /// The text without spaces, tabs and newlines at either end.
    var trimmingWhitespace: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
