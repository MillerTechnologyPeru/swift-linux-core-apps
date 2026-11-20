//
//  FileOperations.swift
//  CoreApps
//

import Foundation

/// Changes to what a folder holds.
public enum FileOperations {

    /// Why a change wasn't made.
    public enum Failure: Error, Hashable, Sendable {
        /// The folder already has an item with the name.
        case nameTaken(String)
    }

    /// The names of a folder's items, hidden ones too.
    static func names(in folder: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    }

    /// Makes a folder inside another.
    ///
    /// - Parameter name: What to call it. A number is added if the name is
    ///   taken, so "New Folder" can be asked for again and again.
    /// - Returns: The new folder.
    @discardableResult
    public static func createFolder(named name: String = "New Folder", in parent: URL) throws -> URL {
        let name = FileName.cleaned(name)
        if let problem = FileName.problem(with: name) { throw problem }
        let unique = FileName.unique(name, among: names(in: parent))
        let url = parent.appendingPathComponent(unique, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    /// Gives an item another name, in the folder it's in.
    ///
    /// - Returns: Where the item is now.
    @discardableResult
    public static func rename(_ item: URL, to name: String) throws -> URL {
        let name = FileName.cleaned(name)
        if let problem = FileName.problem(with: name) { throw problem }
        guard name != item.lastPathComponent else { return item }
        let destination = item.deletingLastPathComponent().appendingPathComponent(name)
        // Moving onto a name that's taken would replace a file on some
        // systems and fail on others.
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw Failure.nameTaken(name)
        }
        try FileManager.default.moveItem(at: item, to: destination)
        return destination
    }

    /// Moves an item to the trash, from which it can be put back: the
    /// system's on macOS, and elsewhere the user's home trash (which on iOS,
    /// having no trash of its own, is in the app's container).
    public static func moveToTrash(_ item: URL) throws {
        #if os(macOS)
        try FileManager.default.trashItem(at: item, resultingItemURL: nil)
        #else
        try Trash.home().trash(item)
        #endif
    }
}

extension FileOperations.Failure: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .nameTaken(name): "There is already an item named “\(name)”."
        }
    }
}
