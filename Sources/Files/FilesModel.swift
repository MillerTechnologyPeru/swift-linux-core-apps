//
//  FilesModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import FilesCore
import Foundation

/// Somewhere the file manager shows: a folder, or a list that isn't one.
enum Place: Hashable {
    case folder(URL)
    case trash
    case starred
}

/// The items cut or copied, waiting to be pasted.
struct Clipboard: Equatable {

    var items: [URL]

    /// Whether pasting moves the items rather than copying them.
    var isCut: Bool
}

/// What every folder the file manager shows has in common: how folders are
/// listed, what's on the clipboard, and the changes that can be undone.
@MainActor
final class FilesModel: ObservableObject {

    @Published var options = ListingOptions()

    /// Whether folders show as a grid of icons rather than a list.
    @Published var showsGrid = false

    @Published var clipboard: Clipboard?

    @Published var undoStack = UndoStack()

    /// What went wrong with the last change, shown until dismissed.
    @Published var failure: String?

    /// Counts the changes made, so listings are read again.
    @Published var changes = 0

    let bookmarks = Bookmarks.user()

    let starred = Starred.user()

    let folders = UserFolders()

    /// Whether the trash can be looked into: the system's on macOS can't.
    var showsTrash: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }

    /// Makes a change, remembering it for undoing and showing why if it
    /// can't be made.
    func perform(_ body: () throws -> FileChange?) {
        do {
            if let change = try body() {
                undoStack.record(change)
                follow(change)
            }
        } catch {
            failure = error.localizedDescription
        }
        changes += 1
    }

    /// Makes a change that can't be undone.
    func attempt(_ body: () throws -> Void) {
        perform {
            try body()
            return nil
        }
    }

    /// Keeps stars on items that moved.
    private func follow(_ change: FileChange) {
        if case let .moved(transfers) = change {
            for transfer in transfers {
                try? starred.moved(from: transfer.source, to: transfer.destination)
            }
        }
    }

    func undo() {
        do { try undoStack.undo() } catch { failure = error.localizedDescription }
        changes += 1
    }

    func redo() {
        do { try undoStack.redo() } catch { failure = error.localizedDescription }
        changes += 1
    }

    // MARK: Changes

    func createFolder(named name: String, in folder: URL) {
        perform { .created([try FileOperations.createFolder(named: name, in: folder)]) }
    }

    func createFile(named name: String, in folder: URL, from template: URL? = nil) {
        perform { .created([try FileOperations.createFile(named: name, in: folder, from: template)]) }
    }

    func rename(_ item: URL, to name: String) {
        perform {
            let renamed = try FileOperations.rename(item, to: name)
            return .moved(renamed == item ? [] : [Transfer(source: item, destination: renamed)])
        }
    }

    func rename(_ items: [URL], with rule: BatchRename) {
        perform { .moved(try rule.apply(to: items)) }
    }

    func trash(_ items: [URL]) {
        perform { try FileOperations.moveToTrash(items) }
    }

    func deletePermanently(_ items: [URL]) {
        attempt { try FileOperations.deletePermanently(items) }
    }

    func duplicate(_ items: [URL]) {
        perform { .created(try FileOperations.duplicate(items).map(\.destination)) }
    }

    func link(_ items: [URL], in folder: URL) {
        perform { .created(try items.map { try FileOperations.link(to: $0, in: folder) }) }
    }

    func compress(_ items: [URL]) {
        perform { .created([try Archive.compress(items)]) }
    }

    func extract(_ archive: URL) {
        perform { .created([try Archive.extract(archive)]) }
    }

    func copy(_ items: [URL]) {
        clipboard = Clipboard(items: items, isCut: false)
    }

    func cut(_ items: [URL]) {
        clipboard = Clipboard(items: items, isCut: true)
    }

    /// Puts what's on the clipboard into a folder. Items that were cut are
    /// moved, and leave the clipboard.
    func paste(into folder: URL) {
        guard let clipboard else { return }
        perform {
            if clipboard.isCut {
                let moved = try FileOperations.move(clipboard.items, to: folder)
                self.clipboard = nil
                return .moved(moved)
            }
            return .created(try FileOperations.copy(clipboard.items, to: folder).map(\.destination))
        }
    }

    func open(_ file: URL) {
        attempt { try FileOpener.open(file) }
    }

    func openTerminal(in folder: URL) {
        attempt { try FileOpener.openTerminal(in: folder) }
    }

    func setStarred(_ isStarred: Bool, for item: URL) {
        attempt { try starred.set(isStarred, for: item) }
    }

    func setBookmarked(_ isBookmarked: Bool, for folder: URL) {
        attempt {
            if isBookmarked { try bookmarks.add(folder) } else { try bookmarks.remove(folder) }
        }
    }

    func renameBookmark(_ folder: URL, to name: String) {
        attempt { try bookmarks.rename(folder, to: name) }
    }

    func setPermissions(_ permissions: Permissions, of item: URL, recursively: Bool = false) {
        attempt { try FileProperties.setPermissions(permissions, of: item, recursively: recursively) }
    }
}

#endif
