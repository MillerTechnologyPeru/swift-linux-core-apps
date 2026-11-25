//
//  Themes.swift
//  CoreApps
//

import Foundation

/// The icon and cursor themes installed, found where the freedesktop icon
/// theme specification says to look: `~/.icons`, then `icons` in each of
/// the XDG data directories.
public struct Themes: Hashable, Sendable {

    /// Icon themes, by directory name, sorted.
    public var iconThemes: [String]

    /// Cursor themes, by directory name, sorted.
    public var cursorThemes: [String]

    public init(iconThemes: [String] = [], cursorThemes: [String] = []) {
        self.iconThemes = iconThemes
        self.cursorThemes = cursorThemes
    }

    /// The themes in the directories given, the earlier ones' first where
    /// two have a theme of the same name.
    ///
    /// A directory with an `index.theme` that lists `Directories` is an
    /// icon theme, and one with a `cursors` directory is a cursor theme. A
    /// theme can be both, as Adwaita is. `hicolor`, which every icon theme
    /// falls back on, isn't one to choose, and nor is `default`, which
    /// only points at another.
    public init(searching directories: [URL]) {
        let files = FileManager.default
        var icons = Set<String>()
        var cursors = Set<String>()
        for directory in directories {
            guard let names = try? files.contentsOfDirectory(atPath: directory.path) else {
                continue
            }
            for name in names where !name.hasPrefix(".") && name != "hicolor" && name != "default" {
                let theme = directory.appendingPathComponent(name)
                if let index = try? String(contentsOf: theme.appendingPathComponent("index.theme"), encoding: .utf8),
                   Themes.listsDirectories(index) {
                    icons.insert(name)
                }
                var isDirectory: ObjCBool = false
                if files.fileExists(atPath: theme.appendingPathComponent("cursors").path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    cursors.insert(name)
                }
            }
        }
        self.init(iconThemes: icons.sorted(by: Themes.order), cursorThemes: cursors.sorted(by: Themes.order))
    }

    /// The themes installed for this user and system.
    public static func installed(environment: [String: String] = ProcessInfo.processInfo.environment) -> Themes {
        Themes(searching: searchDirectories(environment: environment))
    }

    /// Where themes are looked for.
    public static func searchDirectories(environment: [String: String]) -> [URL] {
        let home = environment["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        var directories: [URL] = []
        if let home {
            directories.append(home.appendingPathComponent(".icons", isDirectory: true))
        }
        if let data = environment["XDG_DATA_HOME"], !data.isEmpty {
            directories.append(URL(fileURLWithPath: data, isDirectory: true).appendingPathComponent("icons"))
        } else if let home {
            directories.append(home.appendingPathComponent(".local/share/icons", isDirectory: true))
        }
        let shared = environment["XDG_DATA_DIRS"].flatMap { $0.isEmpty ? nil : $0 } ?? "/usr/local/share:/usr/share"
        for path in shared.split(separator: ":") where !path.isEmpty {
            directories.append(URL(fileURLWithPath: String(path), isDirectory: true).appendingPathComponent("icons"))
        }
        return directories
    }

    /// Whether an `index.theme` lists the directories of an icon theme's
    /// icons. A cursor theme's has none.
    static func listsDirectories(_ index: String) -> Bool {
        index.split(whereSeparator: \.isNewline).contains { line in
            let parts = line.split(separator: "=", maxSplits: 1)
            return parts.count == 2
                && parts[0].trimmingCharacters(in: .whitespaces) == "Directories"
                && !parts[1].trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private static func order(_ first: String, _ second: String) -> Bool {
        first.localizedCaseInsensitiveCompare(second) == .orderedAscending
    }

    /// The themes to offer: those installed, with the one set now too
    /// should it not be installed here, so the choice still shows it.
    public static func choices(_ installed: [String], current: String?) -> [String] {
        guard let current, !current.isEmpty, !installed.contains(current) else {
            return installed
        }
        return [current] + installed
    }
}

/// The cursor sizes to choose from, in pixels: those cursor themes are
/// drawn at.
public enum CursorSize {

    public static let sizes = [24, 32, 48, 64, 96]

    /// The sizes, with the one set now too should it not be one of them.
    public static func choices(current: Int?) -> [Int] {
        guard let current, current > 0, !sizes.contains(current) else {
            return sizes
        }
        return (sizes + [current]).sorted()
    }
}
