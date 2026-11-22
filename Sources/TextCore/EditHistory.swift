//
//  EditHistory.swift
//  CoreApps
//

/// The states a text has been through, for undoing and redoing edits.
///
/// Whole texts are kept, which suits the size of file the editor opens.
/// Edits made close together in time count as one, so that undoing takes
/// back a burst of typing and not a letter.
public struct EditHistory: Sendable {

    /// The texts to go back to, oldest first.
    private var past: [String] = []

    /// The texts undone, the next to redo last.
    private var future: [String] = []

    /// The text as it is.
    public private(set) var current: String

    /// When the last edit was recorded, in seconds on any steady clock.
    private var lastEdit: Double?

    /// The text as it was last saved.
    private var saved: String

    /// How many states are kept.
    public var limit: Int

    /// Edits closer together than this, in seconds, count as one.
    public var burst: Double

    public init(_ text: String, limit: Int = 200, burst: Double = 1.0) {
        current = text
        saved = text
        self.limit = limit
        self.burst = burst
    }

    public var canUndo: Bool { !past.isEmpty }

    public var canRedo: Bool { !future.isEmpty }

    /// Whether the text differs from what was last saved.
    public var isModified: Bool { current != saved }

    /// The text changed.
    ///
    /// - Parameters:
    ///   - time: When, in seconds on a steady clock.
    ///   - isSeparate: Whether the change stands by itself however soon
    ///     after the last: a replace-all, say, rather than typing.
    public mutating func record(_ text: String, at time: Double, isSeparate: Bool = false) {
        guard text != current else { return }
        let continues = !isSeparate && !past.isEmpty && lastEdit.map { time - $0 < burst } == true
        if !continues {
            past.append(current)
            if past.count > limit { past.removeFirst(past.count - limit) }
        }
        current = text
        future.removeAll()
        // A separate change ends the burst before it, too.
        lastEdit = isSeparate ? nil : time
    }

    /// Goes back a state.
    ///
    /// - Returns: The text to show, or `nil` if there's nothing to undo.
    public mutating func undo() -> String? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        current = previous
        lastEdit = nil
        return current
    }

    public mutating func redo() -> String? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        current = next
        lastEdit = nil
        return current
    }

    /// The text as it is was written to its file.
    public mutating func markSaved() {
        saved = current
        lastEdit = nil
    }
}

/// Names for documents.
public enum DocumentName {

    /// A name for a new document that none of a folder's files has.
    public static func untitled(among taken: Set<String>, extension suffix: String = "txt") -> String {
        let base = "Untitled Document"
        var name = "\(base).\(suffix)", number = 2
        while taken.contains(name) {
            name = "\(base) \(number).\(suffix)"
            number += 1
        }
        return name
    }

    /// What's wrong with a name for a file, or `nil` if it will do.
    public static func problem(with name: String) -> String? {
        if name.isEmpty { return "A name can't be empty." }
        if name.contains("/") { return "A name can't contain a slash." }
        if name == "." || name == ".." { return "That name is reserved." }
        if name.utf8.count > 255 { return "That name is too long." }
        return nil
    }
}
