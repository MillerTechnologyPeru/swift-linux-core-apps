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
    /// By kind, then by name extension, then by name.
    case type
}

/// How a folder is listed.
public struct ListingOptions: Hashable, Sendable {

    public var sort: FileSort

    /// The order turned around: Z to A, oldest first, smallest first.
    public var isReversed: Bool

    /// Whether folders come before files, whatever the order.
    public var foldersFirst: Bool

    public var showsHidden: Bool

    public init(sort: FileSort = .name, isReversed: Bool = false, foldersFirst: Bool = true, showsHidden: Bool = false) {
        self.sort = sort
        self.isReversed = isReversed
        self.foldersFirst = foldersFirst
        self.showsHidden = showsHidden
    }
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

    /// The items directly inside a folder, listed as the options say.
    public static func load(_ folder: URL, options: ListingOptions) throws -> [FileItem] {
        let items = try load(folder, showsHidden: options.showsHidden, sort: .name)
        return sorted(items, by: options.sort, isReversed: options.isReversed, foldersFirst: options.foldersFirst)
    }

    /// Items in an order.
    ///
    /// - Parameters:
    ///   - isReversed: Turns the order around; folders still come first.
    ///   - foldersFirst: Whether folders come before files.
    public static func sorted(_ items: [FileItem], by sort: FileSort, isReversed: Bool = false, foldersFirst: Bool = true) -> [FileItem] {
        items.sorted { first, second in
            if foldersFirst, first.isFolder != second.isFolder {
                return first.isFolder
            }
            let order = isReversed ? compare(second, first, by: sort) : compare(first, second, by: sort)
            return order == .orderedAscending
        }
    }

    /// Which of two items comes first in an order.
    private static func compare(_ first: FileItem, _ second: FileItem, by sort: FileSort) -> ComparisonResult {
        func order<Value: Comparable>(_ a: Value, _ b: Value) -> ComparisonResult {
            a < b ? .orderedAscending : (a > b ? .orderedDescending : .orderedSame)
        }
        var result = ComparisonResult.orderedSame
        switch sort {
        case .name:
            break
        case .modified:
            result = order(second.modified ?? .distantPast, first.modified ?? .distantPast)
        case .size:
            result = order(second.size ?? 0, first.size ?? 0)
        case .type:
            result = order(first.kind.rawValue, second.kind.rawValue)
            if result == .orderedSame {
                result = order(first.url.pathExtension.lowercased(), second.url.pathExtension.lowercased())
            }
        }
        return result == .orderedSame ? first.name.localizedStandardCompare(second.name) : result
    }
}
