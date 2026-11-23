//
//  AppBundle.swift
//  CoreApps
//

import Foundation

/// AppRuntime bundles as `linux-app install` leaves them: under a prefix,
/// `lib/linux-app/<identifier>.app`, with `share/applications/<identifier>.desktop`
/// and `share/icons/hicolor/256x256/apps/<identifier>.png` beside it.
public enum AppBundle {

    /// The bundles' directory under a prefix.
    public static let directory = "lib/linux-app"

    /// Where LinuxAppRuntime looks, in order: `LINUXAPPRUNTIME_PREFIXES`
    /// (separated by colons), or else the user's `~/.local`, then
    /// `/usr/local` and `/usr`.
    public static func prefixes(environment: [String: String], home: String) -> [String] {
        if let list = environment["LINUXAPPRUNTIME_PREFIXES"], !list.isEmpty {
            return list.split(separator: ":").map(String.init)
        }
        return [home + "/.local", "/usr/local", "/usr"]
    }

    /// Whose the bundles under `prefix` are.
    public static func installation(of prefix: String, home: String) -> Installation {
        prefix.hasPrefix(home + "/") ? .user : .system
    }

    /// An installed bundle, from its `Info.plist`; `nil` without an
    /// identifier.
    public static func app(infoPlist data: Data, path: String, installation: Installation) -> InstalledApp? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = plist["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
            return nil
        }
        let name = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? identifier
        return InstalledApp(
            appID: identifier,
            name: name,
            version: (plist["CFBundleShortVersionString"] as? String) ?? "",
            source: .appRuntime,
            installation: installation,
            path: path
        )
    }

    /// What removing the bundle at `path` deletes: the bundle, its desktop
    /// entry and its icon.
    public static func files(ofBundleAt path: String, identifier: String) -> [String] {
        // <prefix>/lib/linux-app/<identifier>.app
        var prefix = path
        for _ in 0..<3 {
            prefix = parent(of: prefix)
        }
        return [
            path,
            prefix + "/share/applications/" + identifier + ".desktop",
            prefix + "/share/icons/hicolor/256x256/apps/" + identifier + ".png",
        ]
    }

    /// The directory a path is in.
    public static func parent(of path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return slash == path.startIndex ? "/" : String(path[..<slash])
    }
}
