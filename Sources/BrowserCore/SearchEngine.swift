//
//  SearchEngine.swift
//  CoreApps
//

/// Where the address bar sends what isn't an address.
public enum SearchEngine: String, CaseIterable, Identifiable, Sendable {

    case duckDuckGo
    case startpage
    case google
    case bing

    /// The default: it needs no account and keeps no history.
    public static let standard = SearchEngine.duckDuckGo

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .duckDuckGo: "DuckDuckGo"
        case .startpage: "Startpage"
        case .google: "Google"
        case .bing: "Bing"
        }
    }

    /// The results page's address up to the query, and the query's name.
    private var page: (prefix: String, parameter: String) {
        switch self {
        case .duckDuckGo: ("https://duckduckgo.com/", "q")
        case .startpage: ("https://www.startpage.com/sp/search", "query")
        case .google: ("https://www.google.com/search", "q")
        case .bing: ("https://www.bing.com/search", "q")
        }
    }

    /// The address of the results for `query`.
    public func searchURL(for query: String) -> String {
        let page = self.page
        return page.prefix + "?" + page.parameter + "=" + PercentEncoding.encodeQuery(query)
    }

    /// What was searched for, if `url` is a page of this engine's results:
    /// for the address bar to show the search rather than its address.
    public func searchTerms(in url: String) -> String? {
        let page = self.page
        let bytes = Array(url.utf8)
        let prefix = Array(page.prefix.utf8)
        guard Text.hasPrefix(bytes, prefix), bytes.count > prefix.count, bytes[prefix.count] == UInt8(ascii: "?") else {
            return nil
        }
        var query = Array(bytes[(prefix.count + 1)...])
        if let hash = query.firstIndex(of: UInt8(ascii: "#")) {
            query = Array(query[..<hash])
        }
        let name = Array((page.parameter + "=").utf8)
        for field in query.split(separator: UInt8(ascii: "&")) where Text.hasPrefix(Array(field), name) {
            let value = String(decoding: field.dropFirst(name.count), as: UTF8.self)
            let terms = PercentEncoding.decodeQuery(value)
            return terms.isEmpty ? nil : terms
        }
        return nil
    }
}
