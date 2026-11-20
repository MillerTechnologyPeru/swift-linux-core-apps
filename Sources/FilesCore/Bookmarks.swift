//
//  Bookmarks.swift
//  CoreApps
//

import Foundation

/// A folder the user keeps in the sidebar, perhaps under a name of their own.
public struct Bookmark: Identifiable, Hashable, Sendable {

    public var url: URL

    /// The user's name for it, if they gave it one.
    public var label: String?

    public var id: URL { url }

    /// The name shown: the user's, or the folder's.
    public var name: String {
        label ?? url.lastPathComponent
    }

    public init(url: URL, label: String? = nil) {
        self.url = url
        self.label = label
    }
}

/// The user's bookmarks, kept in the file GTK's file choosers and other
/// file managers read too: a line for each of a `file://` URL, then
/// optionally a space and a name.
public struct Bookmarks: Sendable {

    /// The file the bookmarks are kept in.
    public var file: URL

    public init(file: URL) {
        self.file = file
    }

    /// The user's own: `gtk-3.0/bookmarks` in their configuration folder.
    public static func user(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) -> Bookmarks {
        var config = homeDirectory.appendingPathComponent(".config", isDirectory: true)
        if let path = environment["XDG_CONFIG_HOME"], path.hasPrefix("/") {
            config = URL(fileURLWithPath: path, isDirectory: true)
        }
        return Bookmarks(file: config.appendingPathComponent("gtk-3.0/bookmarks"))
    }

    /// The bookmarks in the text of a bookmarks file. Ones that aren't
    /// local folders, such as servers, are passed over.
    static func parse(_ text: String) -> [Bookmark] {
        var bookmarks: [Bookmark] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard let first = parts.first, first.hasPrefix("file://"), let url = URL(string: String(first)) else { continue }
            let label = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
            bookmarks.append(Bookmark(url: URL(fileURLWithPath: url.path, isDirectory: true), label: label.isEmpty ? nil : label))
        }
        return bookmarks
    }

    /// The text of a bookmarks file.
    static func text(for bookmarks: [Bookmark]) -> String {
        bookmarks.map { bookmark in
            let url = URL(fileURLWithPath: bookmark.url.path).absoluteString
            return bookmark.label.map { "\(url) \($0)" } ?? url
        }.joined(separator: "\n") + (bookmarks.isEmpty ? "" : "\n")
    }

    /// The lines of the file that aren't local folders, kept as they are
    /// when the file is written.
    private func otherLines() -> [String] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("file://") }
    }

    public func load() -> [Bookmark] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return Self.parse(text)
    }

    public func save(_ bookmarks: [Bookmark]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let others = otherLines()
        let text = Self.text(for: bookmarks) + others.map { $0 + "\n" }.joined()
        try Data(text.utf8).write(to: file, options: .atomic)
    }

    public func contains(_ folder: URL) -> Bool {
        load().contains { $0.url.standardizedFileURL.path == folder.standardizedFileURL.path }
    }

    /// Adds a folder, unless it's there already.
    public func add(_ folder: URL) throws {
        guard !contains(folder) else { return }
        try save(load() + [Bookmark(url: folder)])
    }

    public func remove(_ folder: URL) throws {
        try save(load().filter { $0.url.standardizedFileURL.path != folder.standardizedFileURL.path })
    }

    /// Gives a bookmark a name of the user's. The folder keeps its own; an
    /// empty name takes the user's away.
    public func rename(_ folder: URL, to label: String) throws {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        try save(load().map { bookmark in
            guard bookmark.url.standardizedFileURL.path == folder.standardizedFileURL.path else { return bookmark }
            return Bookmark(url: bookmark.url, label: label.isEmpty ? nil : label)
        })
    }
}

/// The items the user starred, kept as a file of paths, one to a line.
public struct Starred: Sendable {

    public var file: URL

    public init(file: URL) {
        self.file = file
    }

    /// The user's own, in their data folder.
    public static func user(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) -> Starred {
        var data = homeDirectory.appendingPathComponent(".local/share", isDirectory: true)
        if let path = environment["XDG_DATA_HOME"], path.hasPrefix("/") {
            data = URL(fileURLWithPath: path, isDirectory: true)
        }
        return Starred(file: data.appendingPathComponent("files/starred"))
    }

    /// The starred paths, in the order they were starred.
    public func paths() -> [String] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }

    /// The starred items that still exist.
    public func items() -> [FileItem] {
        paths().compactMap { path in
            let url = URL(fileURLWithPath: path)
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            let isFolder = values.isDirectory ?? false
            return FileItem(
                url: url,
                name: url.lastPathComponent,
                kind: isFolder ? .folder : FileKind(pathExtension: url.pathExtension),
                size: isFolder ? nil : values.fileSize.map(Int64.init),
                modified: values.contentModificationDate,
                isHidden: url.lastPathComponent.hasPrefix(".")
            )
        }
    }

    public func contains(_ item: URL) -> Bool {
        paths().contains(item.standardizedFileURL.path)
    }

    private func save(_ paths: [String]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((paths.joined(separator: "\n") + (paths.isEmpty ? "" : "\n")).utf8).write(to: file, options: .atomic)
    }

    /// Stars an item, or takes its star away.
    public func set(_ isStarred: Bool, for item: URL) throws {
        let path = item.standardizedFileURL.path
        var paths = paths().filter { $0 != path }
        if isStarred { paths.append(path) }
        try save(paths)
    }

    /// Follows an item that was moved or renamed, so it keeps its star.
    public func moved(from old: URL, to new: URL) throws {
        let oldPath = old.standardizedFileURL.path, newPath = new.standardizedFileURL.path
        let current = paths()
        guard current.contains(oldPath) else { return }
        try save(current.map { $0 == oldPath ? newPath : $0 })
    }
}
