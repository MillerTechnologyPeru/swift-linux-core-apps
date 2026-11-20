//
//  DirectoryListing.swift
//  CoreApps
//

import Foundation

/// How a folder's items are ordered. Folders always come first.
public enum FileSort: String, Hashable, Sendable, CaseIterable {
    /// By name, as a person would order them: "File 2" before "File 10".
    case name
    /// Newest first.
    case modified
    /// Largest first.
    case size
}

/// What a folder holds.
public enum DirectoryListing {

    /// The items directly inside a folder.
    ///
    /// - Throws: What the file system reports, such as the folder not
    ///   existing or not being readable.
    public static func load(_ folder: URL, showsHidden: Bool = false, sort: FileSort = .name) throws -> [FileItem] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: []
        )
        var items: [FileItem] = []
        for url in urls {
            let name = url.lastPathComponent
            let isHidden = name.hasPrefix(".")
            guard showsHidden || !isHidden else { continue }
            // An item that vanished or can't be read is listed by its name.
            let values = try? url.resourceValues(forKeys: keys)
            let isFolder = values?.isDirectory ?? false
            items.append(FileItem(
                url: url,
                name: name,
                kind: isFolder ? .folder : FileKind(pathExtension: url.pathExtension),
                size: isFolder ? nil : values?.fileSize.map(Int64.init),
                modified: values?.contentModificationDate,
                isHidden: isHidden
            ))
        }
        return sorted(items, by: sort)
    }

    /// Items in an order, folders first.
    public static func sorted(_ items: [FileItem], by sort: FileSort) -> [FileItem] {
        items.sorted { first, second in
            if first.isFolder != second.isFolder {
                return first.isFolder
            }
            switch sort {
            case .name:
                break
            case .modified:
                let a = first.modified ?? .distantPast, b = second.modified ?? .distantPast
                if a != b { return a > b }
            case .size:
                let a = first.size ?? 0, b = second.size ?? 0
                if a != b { return a > b }
            }
            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }
}
