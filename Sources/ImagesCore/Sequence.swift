//
//  Sequence.swift
//  CoreApps
//

/// The images being looked through, and which one is showing.
public struct ImageSequence<Element: Hashable & Sendable>: Equatable, Sendable {

    public private(set) var items: [Element]

    /// The position of the one showing; 0 when there are none.
    public private(set) var index: Int

    /// - Parameter current: The item to show first; the first if it isn't
    ///   among them.
    public init(_ items: [Element], current: Element? = nil) {
        self.items = items
        self.index = current.flatMap { items.firstIndex(of: $0) } ?? 0
    }

    public var current: Element? {
        items.indices.contains(index) ? items[index] : nil
    }

    public var isEmpty: Bool { items.isEmpty }

    public var hasPrevious: Bool { index > 0 }

    public var hasNext: Bool { index + 1 < items.count }

    /// Where the one showing is among them: "3 of 12".
    public var position: String {
        items.isEmpty ? "" : "\(index + 1) of \(items.count)"
    }

    public mutating func next() {
        if hasNext { index += 1 }
    }

    public mutating func previous() {
        if hasPrevious { index -= 1 }
    }

    public mutating func show(_ item: Element) {
        if let found = items.firstIndex(of: item) { index = found }
    }

    /// Takes away the one showing: the next shows in its place, or the
    /// one before if it was last.
    public mutating func removeCurrent() {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        index = min(index, max(0, items.count - 1))
    }
}
