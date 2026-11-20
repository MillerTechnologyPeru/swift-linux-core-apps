//
//  UndoStack.swift
//  CoreApps
//

import Foundation

/// A change the file manager made, as what it takes to take it back.
public enum FileChange: Hashable, Sendable {
    /// Items now exist that didn't: copies, links, new folders and files.
    case created([URL])
    /// Items are somewhere else, or have other names.
    case moved([Transfer])
    /// Items went to a trash.
    case trashed([Transfer], Trash)
    /// Items came back from a trash, to where they were.
    case restored([URL], Trash)

    /// What the change did, for a menu: "Undo Rename".
    public var name: String {
        switch self {
        case .created: "Create"
        case let .moved(transfers):
            transfers.count == 1 && transfers[0].source.deletingLastPathComponent() == transfers[0].destination.deletingLastPathComponent()
                ? "Rename" : "Move"
        case .trashed: "Move to Trash"
        case .restored: "Restore"
        }
    }
}

/// The changes made, newest last, and the ones taken back.
public struct UndoStack: Sendable {

    public private(set) var done: [FileChange] = []

    public private(set) var undone: [FileChange] = []

    /// How many changes are remembered.
    public var limit: Int

    public init(limit: Int = 50) {
        self.limit = limit
    }

    public var canUndo: Bool { !done.isEmpty }

    public var canRedo: Bool { !undone.isEmpty }

    /// The name of the change undoing would take back.
    public var undoName: String? { done.last?.name }

    public var redoName: String? { undone.last?.name }

    /// Remembers a change just made. What was taken back can no longer be
    /// made again.
    public mutating func record(_ change: FileChange) {
        switch change {
        case let .created(urls) where urls.isEmpty: return
        case let .moved(transfers) where transfers.isEmpty: return
        case let .trashed(transfers, _) where transfers.isEmpty: return
        case let .restored(urls, _) where urls.isEmpty: return
        default: break
        }
        done.append(change)
        if done.count > limit { done.removeFirst(done.count - limit) }
        undone.removeAll()
    }

    /// Takes back the newest change.
    public mutating func undo() throws {
        guard let change = done.last else { return }
        let inverse = try Self.revert(change)
        done.removeLast()
        undone.append(inverse)
    }

    /// Makes the change last taken back again.
    public mutating func redo() throws {
        guard let change = undone.last else { return }
        let inverse = try Self.revert(change)
        undone.removeLast()
        done.append(inverse)
    }

    /// Takes a change back.
    ///
    /// - Returns: The change that puts things as they were before taking
    ///   it back.
    private static func revert(_ change: FileChange) throws -> FileChange {
        let manager = FileManager.default
        switch change {
        case let .created(urls):
            // What was created goes to the trash rather than for good: it
            // may have been filled since.
            let trash = Trash.home()
            var transfers: [Transfer] = []
            for url in urls where manager.fileExists(atPath: url.path) || FileOperations.isSymbolicLink(url) {
                transfers.append(Transfer(source: url, destination: try trash.trash(url)))
            }
            return .trashed(transfers, trash)
        case let .moved(transfers):
            var back: [Transfer] = []
            for transfer in transfers.reversed() {
                guard !manager.fileExists(atPath: transfer.source.path) else {
                    throw FileOperations.Failure.nameTaken(transfer.source.lastPathComponent)
                }
                try manager.moveItem(at: transfer.destination, to: transfer.source)
                back.append(Transfer(source: transfer.destination, destination: transfer.source))
            }
            return .moved(back)
        case let .trashed(transfers, trash):
            var restored: [URL] = []
            let items = trash.items()
            for transfer in transfers {
                guard let item = items.first(where: { $0.url.standardizedFileURL == transfer.destination.standardizedFileURL }) else {
                    continue
                }
                restored.append(try trash.restore(item))
            }
            return .restored(restored, trash)
        case let .restored(urls, trash):
            var transfers: [Transfer] = []
            for url in urls {
                transfers.append(Transfer(source: url, destination: try trash.trash(url)))
            }
            return .trashed(transfers, trash)
        }
    }
}
