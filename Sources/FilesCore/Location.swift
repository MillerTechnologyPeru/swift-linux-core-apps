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
    public static func standard(home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) -> [Location] {
        var locations = [Location(name: "Home", symbolName: "house", url: home)]
        let folders = UserFolders(home: home)
        for folder in [UserFolder.documents, .downloads, .music, .pictures, .videos] {
            let url = folders.url(for: folder)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                locations.append(Location(name: url.lastPathComponent, symbolName: folder.symbolName, url: url))
            }
        }
        locations.append(Location(name: "Computer", symbolName: "tray", url: URL(fileURLWithPath: "/", isDirectory: true)))
        return locations
    }

    /// The folders from the root down to a folder, for a path bar.
    public static func ancestors(of folder: URL) -> [URL] {
        var urls: [URL] = []
        var url = folder.standardizedFileURL
        while true {
            urls.append(url)
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path || url.path == "/" { break }
            url = parent
        }
        return urls.reversed()
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
