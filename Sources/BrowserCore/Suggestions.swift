//
//  Suggestions.swift
//  CoreApps
//

/// A page offered under the address bar as it's typed in.
public struct Suggestion: Equatable, Identifiable, Sendable {

    public var title: String

    public var url: String

    public var isBookmark: Bool

    public var id: String { url }

    public init(title: String, url: String, isBookmark: Bool) {
        self.title = title
        self.url = url
        self.isBookmark = isBookmark
    }
}

/// The bookmarks and history that match what's typed into the address bar.
public enum Suggestions {

    /// Pages for `typed`, best first:
    ///
    /// 1. those whose host starts with it (`sw` finds swift.org),
    /// 2. those with a word of the title or address starting with it,
    /// 3. those with it anywhere in the title or address.
    ///
    /// Among equals, bookmarks come first, then the pages gone to most,
    /// then the latest.
    public static func make(for typed: String, history: History, bookmarks: Bookmarks, limit: Int = 6) -> [Suggestion] {
        let query = Text.folded(Text.trimmed(typed))
        guard !query.isEmpty, limit > 0 else { return [] }
        var scored: [(suggestion: Suggestion, rank: Int, count: Int, order: Int)] = []
        var seen = Set<String>()
        var order = 0
        func consider(title: String, url: String, isBookmark: Bool, count: Int) {
            defer { order += 1 }
            guard !seen.contains(url) else { return }
            let rank = self.rank(title: title, url: url, query: query)
            guard rank > 0 else { return }
            seen.insert(url)
            scored.append((Suggestion(title: title, url: url, isBookmark: isBookmark), rank, count, order))
        }
        for bookmark in bookmarks.items {
            let count = history.visits.first { $0.url == bookmark.url }?.count ?? 0
            consider(title: bookmark.displayTitle, url: bookmark.url, isBookmark: true, count: count)
        }
        for visit in history.visits {
            consider(title: visit.displayTitle, url: visit.url, isBookmark: false, count: visit.count)
        }
        scored.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
            if lhs.suggestion.isBookmark != rhs.suggestion.isBookmark { return lhs.suggestion.isBookmark }
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.order < rhs.order
        }
        return scored.prefix(limit).map { $0.suggestion }
    }

    /// 3 for a host that starts with the query, 2 for a word that does, 1
    /// for the query anywhere, and 0 for none.
    static func rank(title: String, url: String, query: [UInt8]) -> Int {
        if let address = WebAddress(url), !address.host.isEmpty {
            if Text.hasPrefix(Text.folded(address.displayHost), query) || Text.hasPrefix(Text.folded(address.host), query) {
                return 3
            }
        }
        let title = Text.folded(title), url = Text.folded(url)
        if Text.hasWordPrefix(title, query) || Text.hasWordPrefix(url, query) {
            return 2
        }
        if Text.contains(title, query) || Text.contains(url, query) {
            return 1
        }
        return 0
    }
}
