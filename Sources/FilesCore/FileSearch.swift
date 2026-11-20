//
//  FileSearch.swift
//  CoreApps
//

import Foundation

/// A pattern for names, as shells have them: `*` stands for any run of
/// characters and `?` for exactly one. Letters match whatever their case.
public struct FilePattern: Hashable, Sendable {

    public var pattern: String

    public init(_ pattern: String) {
        self.pattern = pattern
    }

    /// Whether a whole name fits the pattern.
    public func matches(_ name: String) -> Bool {
        let pattern = Array(pattern.lowercased()), name = Array(name.lowercased())
        // The classic two-pointer match, going back to the last star when a
        // character doesn't fit.
        var p = 0, n = 0, star = -1, mark = 0
        while n < name.count {
            if p < pattern.count, pattern[p] == "?" || pattern[p] == name[n] {
                p += 1
                n += 1
            } else if p < pattern.count, pattern[p] == "*" {
                star = p
                mark = n
                p += 1
            } else if star >= 0 {
                p = star + 1
                mark += 1
                n = mark
            } else {
                return false
            }
        }
        while p < pattern.count, pattern[p] == "*" { p += 1 }
        return p == pattern.count
    }
}

/// What a search looks for.
public struct FileQuery: Hashable, Sendable {

    /// Text a name must contain, whatever its case. A text with `*` or `?`
    /// is a pattern the whole name must fit.
    public var text: String

    /// The kind an item must be, if any.
    public var kind: FileKind?

    /// Only items changed at or after this.
    public var modifiedSince: Date?

    /// Whether the text is also looked for inside text files.
    public var searchesContents: Bool

    public var showsHidden: Bool

    public init(text: String = "", kind: FileKind? = nil, modifiedSince: Date? = nil, searchesContents: Bool = false, showsHidden: Bool = false) {
        self.text = text
        self.kind = kind
        self.modifiedSince = modifiedSince
        self.searchesContents = searchesContents
        self.showsHidden = showsHidden
    }

    /// Whether the query asks for nothing, and so finds nothing.
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty && kind == nil && modifiedSince == nil
    }

    /// Whether an item's name fits the text.
    func matchesName(_ name: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { return true }
        if text.contains("*") || text.contains("?") {
            return FilePattern(text).matches(name)
        }
        return name.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

/// Finding items in a folder and the folders inside it.
public enum FileSearch {

    /// The largest text file whose contents are searched.
    static let contentLimit = 2_000_000

    /// The items under a folder that fit a query, by name.
    ///
    /// - Parameter limit: The most items to find; a search of a whole disk
    ///   stops there.
    public static func find(_ query: FileQuery, in folder: URL, limit: Int = 500) -> [FileItem] {
        guard !query.isEmpty else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let walker = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: query.showsHidden ? [] : [.skipsHiddenFiles]
        ) else { return [] }
        var found: [FileItem] = []
        for case let url as URL in walker {
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: keys)
            let isFolder = values?.isDirectory ?? false
            let kind: FileKind = isFolder ? .folder : FileKind(pathExtension: url.pathExtension)
            if let wanted = query.kind, wanted != kind { continue }
            if let since = query.modifiedSince, (values?.contentModificationDate ?? .distantPast) < since { continue }
            var matches = query.matchesName(name)
            if !matches, query.searchesContents, kind == .text, (values?.fileSize ?? 0) <= contentLimit {
                let text = query.text.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty, let contents = try? String(contentsOf: url, encoding: .utf8) {
                    matches = contents.range(of: text, options: .caseInsensitive) != nil
                }
            }
            guard matches else { continue }
            found.append(FileItem(
                url: url,
                name: name,
                kind: kind,
                size: isFolder ? nil : values?.fileSize.map(Int64.init),
                modified: values?.contentModificationDate,
                isHidden: name.hasPrefix(".")
            ))
            if found.count >= limit { break }
        }
        return DirectoryListing.sorted(found, by: .name)
    }
}
