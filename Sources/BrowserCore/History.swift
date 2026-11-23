//
//  History.swift
//  CoreApps
//

/// A page in the history: where, what it was called, and how often it was
/// gone to.
public struct Visit: Equatable, Identifiable, Sendable {

    public var url: String

    public var title: String

    public var count: Int

    public var id: String { url }

    public init(url: String, title: String, count: Int = 1) {
        self.url = url
        self.title = title
        self.count = count
    }

    /// The title, or the address for a page without one.
    public var displayTitle: String {
        title.isEmpty ? WebAddress.summary(of: url) : title
    }
}

/// The pages gone to, the latest first, each once.
///
/// No dates: a guest has no time zones to say "yesterday" in, so the
/// history is in the order the pages were last seen.
public struct History: Equatable, Sendable {

    /// Latest first.
    public private(set) var visits: [Visit]

    /// How many pages are kept; the oldest go first.
    public var limit: Int

    public init(visits: [Visit] = [], limit: Int = 1000) {
        self.visits = visits
        self.limit = limit
    }

    /// A page was gone to. A blank page, or one made from data, isn't
    /// kept.
    public mutating func record(url: String, title: String) {
        guard Self.isRemembered(url) else { return }
        if let index = visits.firstIndex(where: { $0.url == url }) {
            var visit = visits.remove(at: index)
            visit.count += 1
            if !title.isEmpty {
                visit.title = title
            }
            visits.insert(visit, at: 0)
        } else {
            visits.insert(Visit(url: url, title: title), at: 0)
            if visits.count > limit {
                visits.removeLast(visits.count - limit)
            }
        }
    }

    /// The page's title came after it was recorded.
    public mutating func setTitle(_ title: String, for url: String) {
        guard !title.isEmpty, let index = visits.firstIndex(where: { $0.url == url }) else { return }
        visits[index].title = title
    }

    public mutating func remove(url: String) {
        visits.removeAll { $0.url == url }
    }

    public mutating func removeAll() {
        visits.removeAll()
    }

    /// The pages whose title or address has `query` in it, ignoring case.
    public func matching(_ query: String) -> [Visit] {
        let query = Text.folded(Text.trimmed(query))
        guard !query.isEmpty else { return visits }
        return visits.filter { Text.contains(Text.folded($0.title), query) || Text.contains(Text.folded($0.url), query) }
    }

    static func isRemembered(_ url: String) -> Bool {
        guard let scheme = WebAddress.scheme(of: url) else { return false }
        return scheme == "http" || scheme == "https" || scheme == "file"
    }
}
