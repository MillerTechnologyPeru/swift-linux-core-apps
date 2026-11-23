//
//  Bookmarks.swift
//  CoreApps
//

/// A page kept to go back to.
public struct Bookmark: Equatable, Identifiable, Sendable {

    public var id: Int

    public var title: String

    public var url: String

    public init(id: Int, title: String, url: String) {
        self.id = id
        self.title = title
        self.url = url
    }

    /// The title, or the address for a bookmark without one.
    public var displayTitle: String {
        title.isEmpty ? WebAddress.summary(of: url) : title
    }
}

/// The bookmarks, in the order they're arranged; each address once.
public struct Bookmarks: Equatable, Sendable {

    public private(set) var items: [Bookmark]

    private var nextID: Int

    public init(_ items: [Bookmark] = []) {
        self.items = items
        nextID = (items.map { $0.id }.max() ?? 0) + 1
    }

    public func contains(url: String) -> Bool {
        items.contains { $0.url == url }
    }

    public func bookmark(for url: String) -> Bookmark? {
        items.first { $0.url == url }
    }

    /// Adds a bookmark at the end, or gives the one the address has.
    @discardableResult
    public mutating func add(title: String, url: String) -> Bookmark {
        if let existing = bookmark(for: url) {
            return existing
        }
        let bookmark = Bookmark(id: nextID, title: title, url: url)
        nextID += 1
        items.append(bookmark)
        return bookmark
    }

    public mutating func remove(id: Int) {
        items.removeAll { $0.id == id }
    }

    public mutating func remove(url: String) {
        items.removeAll { $0.url == url }
    }

    /// Adds the page if it isn't a bookmark, and removes it if it is.
    public mutating func toggle(title: String, url: String) {
        if contains(url: url) {
            remove(url: url)
        } else {
            add(title: title, url: url)
        }
    }

    public mutating func rename(id: Int, to title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = Text.trimmed(title)
    }

    /// Moves a bookmark up (negative) or down the list, as far as it goes.
    public mutating func move(id: Int, by offset: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let destination = min(max(index + offset, 0), items.count - 1)
        guard destination != index else { return }
        let bookmark = items.remove(at: index)
        items.insert(bookmark, at: destination)
    }

    /// The bookmarks whose title or address has `query` in it, ignoring
    /// case.
    public func matching(_ query: String) -> [Bookmark] {
        let query = Text.folded(Text.trimmed(query))
        guard !query.isEmpty else { return items }
        return items.filter { Text.contains(Text.folded($0.title), query) || Text.contains(Text.folded($0.url), query) }
    }
}
