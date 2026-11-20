//
//  Trash.swift
//  CoreApps
//

import Foundation

/// A trash folder as freedesktop.org's Trash specification lays one out,
/// which other file managers on Linux read and write too: the trashed items
/// in `files`, and in `info` a file for each saying where it was and when
/// it was trashed.
///
/// Only the home trash is used. The specification also has a trash at the
/// top of each other volume, so that trashing there doesn't copy; an item
/// on another volume is copied to the home trash instead.
public struct Trash: Hashable, Sendable {

    /// The folder holding `files` and `info`.
    public var directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The user's trash: `Trash` in `$XDG_DATA_HOME`, which is
    /// `~/.local/share` unless set.
    public static func home(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) -> Trash {
        let data: URL
        if let path = environment["XDG_DATA_HOME"], path.hasPrefix("/") {
            data = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            data = homeDirectory.appendingPathComponent(".local/share", isDirectory: true)
        }
        return Trash(directory: data.appendingPathComponent("Trash", isDirectory: true))
    }

    /// Where trashed items are.
    public var files: URL {
        directory.appendingPathComponent("files", isDirectory: true)
    }

    /// Where the items' records are.
    public var info: URL {
        directory.appendingPathComponent("info", isDirectory: true)
    }

    /// A trashed item.
    public struct Item: Hashable, Sendable {

        /// Where the item is in the trash.
        public var url: URL

        /// Where it was.
        public var originalURL: URL

        /// When it was trashed, as its record has it: local time, without
        /// a time zone.
        public var deletionDate: String
    }

    /// Moves an item into the trash.
    ///
    /// - Returns: Where the item is now.
    @discardableResult
    public func trash(_ item: URL, at date: Date = Date(), calendar: Calendar = .current) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: files, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.createDirectory(at: info, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let item = item.standardizedFileURL
        let record = Self.record(path: item.path, date: date, calendar: calendar)
        // The record is written first, and only if no other has its name:
        // that is what reserves a name in the trash.
        var name = item.lastPathComponent
        var taken: Set<String> = []
        while true {
            let recordURL = info.appendingPathComponent(name + ".trashinfo")
            do {
                try Data(record.utf8).write(to: recordURL, options: .withoutOverwriting)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                taken.insert(name)
                name = FileName.unique(item.lastPathComponent, among: taken)
                continue
            }
            let destination = files.appendingPathComponent(name)
            do {
                try manager.moveItem(at: item, to: destination)
            } catch {
                try? manager.removeItem(at: recordURL)
                throw error
            }
            return destination
        }
    }

    /// What's in the trash, by name. Items without a readable record are
    /// left out.
    public func items() -> [Item] {
        let records = (try? FileManager.default.contentsOfDirectory(at: info, includingPropertiesForKeys: nil)) ?? []
        var items: [Item] = []
        for recordURL in records where recordURL.pathExtension == "trashinfo" {
            guard let text = try? String(contentsOf: recordURL, encoding: .utf8),
                  let (path, date) = Self.parse(record: text) else { continue }
            let name = recordURL.deletingPathExtension().lastPathComponent
            items.append(Item(
                url: files.appendingPathComponent(name),
                originalURL: URL(fileURLWithPath: path),
                deletionDate: date
            ))
        }
        return items.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    /// Puts a trashed item back where it was, making the folders it was in
    /// if they're gone.
    ///
    /// - Returns: Where the item is now.
    @discardableResult
    public func restore(_ item: Item) throws -> URL {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: item.originalURL.path) else {
            throw FileOperations.Failure.nameTaken(item.originalURL.lastPathComponent)
        }
        try manager.createDirectory(at: item.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.moveItem(at: item.url, to: item.originalURL)
        try? manager.removeItem(at: recordURL(of: item))
        return item.originalURL
    }

    /// Deletes a trashed item, for good.
    public func delete(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.url)
        try? FileManager.default.removeItem(at: recordURL(of: item))
    }

    /// Deletes everything in the trash, for good.
    public func empty() throws {
        let manager = FileManager.default
        for folder in [files, info] {
            let contents = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in contents {
                try manager.removeItem(at: url)
            }
        }
    }

    private func recordURL(of item: Item) -> URL {
        info.appendingPathComponent(item.url.lastPathComponent + ".trashinfo")
    }

    // MARK: Records

    /// The characters a record's path keeps as they are; the rest are
    /// percent-encoded, as in a URL.
    private static let pathCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/")

    /// A record: where an item was and when it was trashed.
    static func record(path: String, date: Date, calendar: Calendar) -> String {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: pathCharacters) ?? path
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func padded(_ value: Int?, _ length: Int) -> String {
            let digits = String(value ?? 0)
            return String(repeating: "0", count: max(0, length - digits.count)) + digits
        }
        let stamp = "\(padded(parts.year, 4))-\(padded(parts.month, 2))-\(padded(parts.day, 2))"
            + "T\(padded(parts.hour, 2)):\(padded(parts.minute, 2)):\(padded(parts.second, 2))"
        return "[Trash Info]\nPath=\(encoded)\nDeletionDate=\(stamp)\n"
    }

    /// The path and date of a record, or `nil` if it isn't one.
    static func parse(record: String) -> (path: String, deletionDate: String)? {
        var lines = record.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        lines.removeAll { $0.isEmpty || $0.hasPrefix("#") }
        guard lines.first == "[Trash Info]" else { return nil }
        var path: String?, date = ""
        for line in lines.dropFirst() {
            // Another group ends the one that counts.
            if line.hasPrefix("[") { break }
            if line.hasPrefix("Path="), path == nil {
                path = String(line.dropFirst("Path=".count)).removingPercentEncoding
            } else if line.hasPrefix("DeletionDate="), date.isEmpty {
                date = String(line.dropFirst("DeletionDate=".count))
            }
        }
        guard let path, path.hasPrefix("/") else { return nil }
        return (path, date)
    }
}
