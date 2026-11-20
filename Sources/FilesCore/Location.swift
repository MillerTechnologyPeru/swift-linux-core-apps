//
//  Location.swift
//  CoreApps
//

import Foundation

/// A place to start browsing from.
public struct Location: Identifiable, Hashable, Sendable {

    public var name: String

    public var symbolName: String

    public var url: URL

    public var id: URL { url }

    public init(name: String, symbolName: String, url: URL) {
        self.name = name
        self.symbolName = symbolName
        self.url = url
    }

    /// The user's folders that exist, then the whole file system.
    public static func standard(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Location] {
        var locations = [Location(name: "Home", symbolName: "house", url: home)]
        let folders: [(String, String)] = [
            ("Documents", "doc"),
            ("Downloads", "arrow.down"),
            ("Pictures", "photo"),
            ("Music", "play"),
            ("Videos", "play"),
            // What macOS calls Videos.
            ("Movies", "play"),
        ]
        for (name, symbol) in folders {
            let url = home.appendingPathComponent(name, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                locations.append(Location(name: name, symbolName: symbol, url: url))
            }
        }
        locations.append(Location(name: "Computer", symbolName: "tray", url: URL(fileURLWithPath: "/", isDirectory: true)))
        return locations
    }

    /// A folder's title: a location's name when it is one, else its own.
    public static func title(for folder: URL, among locations: [Location]) -> String {
        let path = folder.standardizedFileURL.path
        if let location = locations.first(where: { $0.url.standardizedFileURL.path == path }) {
            return location.name
        }
        return folder.lastPathComponent
    }
}
