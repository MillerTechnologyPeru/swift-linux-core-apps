//
//  FileTransfer.swift
//  CoreApps
//

import Foundation

/// What to do when an item is copied or moved to where another has its name.
public enum ConflictPolicy: Hashable, Sendable {
    /// Keep both, giving the newcomer a number: "Notes 2.txt".
    case keepBoth
    /// Put the newcomer in the other's place. The other goes for good.
    case replace
    /// Leave the newcomer where it was.
    case skip
}

/// An item that was copied or moved, and where it is now.
public struct Transfer: Hashable, Sendable {

    public var source: URL

    public var destination: URL

    public init(source: URL, destination: URL) {
        self.source = source
        self.destination = destination
    }
}

extension FileOperations {

    /// Whether a folder is another, or inside it.
    static func isFolder(_ folder: URL, within other: URL) -> Bool {
        let inner = folder.standardizedFileURL.pathComponents
        let outer = other.standardizedFileURL.pathComponents
        return inner.count >= outer.count && Array(inner.prefix(outer.count)) == outer
    }

    /// Where an item lands in a folder under a policy, or `nil` to skip it.
    /// Under `.replace`, whatever is in the way is removed.
    private static func destination(for item: URL, in folder: URL, policy: ConflictPolicy) throws -> URL? {
        let name = item.lastPathComponent
        let target = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: target.path) || isSymbolicLink(target) else {
            return target
        }
        switch policy {
        case .keepBoth:
            return folder.appendingPathComponent(FileName.unique(name, among: names(in: folder)))
        case .replace:
            try FileManager.default.removeItem(at: target)
            return target
        case .skip:
            return nil
        }
    }

    /// Whether a path is a symbolic link, even one that leads nowhere.
    static func isSymbolicLink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    /// Copies items into a folder, folders with all they hold.
    ///
    /// - Returns: What was copied, without the items that were skipped.
    @discardableResult
    public static func copy(_ items: [URL], to folder: URL, policy: ConflictPolicy = .keepBoth) throws -> [Transfer] {
        var done: [Transfer] = []
        for item in items {
            // A folder copied into itself would never finish.
            guard !isFolder(folder, within: item) else {
                throw Failure.intoItself(item.lastPathComponent)
            }
            let sameFolder = item.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL
            // Replacing an item with itself would only delete it.
            guard let target = try destination(for: item, in: folder, policy: sameFolder ? .keepBoth : policy) else {
                continue
            }
            try FileManager.default.copyItem(at: item, to: target)
            done.append(Transfer(source: item, destination: target))
        }
        return done
    }

    /// Moves items into a folder.
    ///
    /// - Returns: What was moved, without the items that were skipped or
    ///   were in the folder already.
    @discardableResult
    public static func move(_ items: [URL], to folder: URL, policy: ConflictPolicy = .keepBoth) throws -> [Transfer] {
        var done: [Transfer] = []
        for item in items {
            guard !isFolder(folder, within: item) else {
                throw Failure.intoItself(item.lastPathComponent)
            }
            guard item.deletingLastPathComponent().standardizedFileURL != folder.standardizedFileURL else {
                continue
            }
            guard let target = try destination(for: item, in: folder, policy: policy) else {
                continue
            }
            try FileManager.default.moveItem(at: item, to: target)
            done.append(Transfer(source: item, destination: target))
        }
        return done
    }

    /// Copies items beside themselves.
    @discardableResult
    public static func duplicate(_ items: [URL]) throws -> [Transfer] {
        try items.flatMap { try copy([$0], to: $0.deletingLastPathComponent()) }
    }

    /// Makes a symbolic link to an item, in a folder: "Link to Notes.txt".
    ///
    /// - Returns: The link.
    @discardableResult
    public static func link(to item: URL, in folder: URL) throws -> URL {
        let name = FileName.unique("Link to " + item.lastPathComponent, among: names(in: folder))
        let url = folder.appendingPathComponent(name)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: item)
        return url
    }

    /// Makes an empty file in a folder, or a copy of a template.
    ///
    /// - Returns: The new file.
    @discardableResult
    public static func createFile(named name: String = "New Document.txt", in folder: URL, from template: URL? = nil) throws -> URL {
        let name = FileName.cleaned(name)
        if let problem = FileName.problem(with: name) { throw problem }
        let url = folder.appendingPathComponent(FileName.unique(name, among: names(in: folder)))
        if let template {
            try FileManager.default.copyItem(at: template, to: url)
        } else {
            try Data().write(to: url, options: .withoutOverwriting)
        }
        return url
    }

    /// Deletes items for good, folders with all they hold.
    public static func deletePermanently(_ items: [URL]) throws {
        for item in items {
            try FileManager.default.removeItem(at: item)
        }
    }

    /// The templates for new documents: the files in the user's Templates
    /// folder, by name.
    public static func templates(in folder: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return urls
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
