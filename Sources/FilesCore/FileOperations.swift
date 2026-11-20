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
        /// A folder can't be copied or moved into itself.
        case intoItself(String)
        /// The system has nothing that does this.
        case unsupported(String)
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

    /// Moves items to the trash, from which they can be put back: the
    /// system's on macOS, and elsewhere the user's home trash (which on iOS,
    /// having no trash of its own, is in the app's container).
    ///
    /// - Returns: The change, for undoing.
    @discardableResult
    public static func moveToTrash(_ items: [URL]) throws -> FileChange {
        #if os(macOS)
        var transfers: [Transfer] = []
        for item in items {
            var trashed: NSURL?
            try FileManager.default.trashItem(at: item, resultingItemURL: &trashed)
            if let trashed = trashed as URL? {
                transfers.append(Transfer(source: item, destination: trashed))
            }
        }
        // Undone as a move back: the system's trash has no records to read.
        return .moved(transfers)
        #else
        let trash = Trash.home()
        var transfers: [Transfer] = []
        for item in items {
            transfers.append(Transfer(source: item, destination: try trash.trash(item)))
        }
        return .trashed(transfers, trash)
        #endif
    }

    /// Moves an item to the trash.
    public static func moveToTrash(_ item: URL) throws {
        try moveToTrash([item])
    }
}

extension FileOperations.Failure: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .nameTaken(name): "There is already an item named “\(name)”."
        case let .intoItself(name): "“\(name)” can't be put inside itself."
        case let .unsupported(what): what
        }
    }
}
