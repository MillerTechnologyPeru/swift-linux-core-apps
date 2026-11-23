//
//  BrowserCoreTests.swift
//  CoreApps
//

import Testing
@testable import BrowserCore

@Suite struct AddressInputTests {

    @Test func addressesWithSchemesAreGoneToAsTheyAre() {
        #expect(AddressInput.destination(for: "https://swift.org/blog") == "https://swift.org/blog")
        #expect(AddressInput.destination(for: "  http://example.com  ") == "http://example.com")
        #expect(AddressInput.destination(for: "about:blank") == "about:blank")
        #expect(AddressInput.destination(for: "file:///home/me/page.html") == "file:///home/me/page.html")
        #expect(AddressInput.destination(for: "HTTPS://Example.com") == "HTTPS://Example.com")
    }

    @Test func hostsAreGoneToOverHTTPS() {
        #expect(AddressInput.destination(for: "swift.org") == "https://swift.org")
        #expect(AddressInput.destination(for: "swift.org/blog?x=1#top") == "https://swift.org/blog?x=1#top")
        #expect(AddressInput.destination(for: "www.example.co.uk") == "https://www.example.co.uk")
        #expect(AddressInput.destination(for: "example.com:8443/admin") == "https://example.com:8443/admin")
        #expect(AddressInput.destination(for: "bücher.de") == "https://bücher.de")
    }

    @Test func localHostsAreGoneToOverHTTP() {
        #expect(AddressInput.destination(for: "localhost") == "http://localhost")
        #expect(AddressInput.destination(for: "localhost:8080/app") == "http://localhost:8080/app")
        #expect(AddressInput.destination(for: "192.168.1.1") == "http://192.168.1.1")
        #expect(AddressInput.destination(for: "[::1]:3000") == "http://[::1]:3000")
        #expect(AddressInput.destination(for: "printer.local") == "http://printer.local")
        #expect(AddressInput.destination(for: "api.localhost") == "http://api.localhost")
    }

    @Test func everythingElseIsSearchedFor() {
        let engine = SearchEngine.duckDuckGo
        #expect(AddressInput.destination(for: "swift", engine: engine) == "https://duckduckgo.com/?q=swift")
        #expect(AddressInput.destination(for: "what is swift.org", engine: engine) == "https://duckduckgo.com/?q=what+is+swift.org")
        #expect(AddressInput.destination(for: "me@example.com", engine: engine) == "https://duckduckgo.com/?q=me%40example.com")
        #expect(AddressInput.destination(for: "1.2.3", engine: engine) == "https://duckduckgo.com/?q=1.2.3")
        #expect(AddressInput.destination(for: "999.1.1.1", engine: engine) == "https://duckduckgo.com/?q=999.1.1.1")
        #expect(AddressInput.destination(for: "-bad-.com", engine: engine) == "https://duckduckgo.com/?q=-bad-.com")
        #expect(AddressInput.destination(for: "localhost:http", engine: engine) == "https://duckduckgo.com/?q=localhost%3Ahttp")
        #expect(AddressInput.destination(for: "c++", engine: .google) == "https://www.google.com/search?q=c%2B%2B")
    }

    @Test func nothingIsNowhere() {
        #expect(AddressInput.destination(for: "") == nil)
        #expect(AddressInput.destination(for: " \t ") == nil)
    }
}

@Suite struct SearchEngineTests {

    @Test func searchTermsComeBackOutOfAResultsPage() {
        for engine in SearchEngine.allCases {
            let url = engine.searchURL(for: "swift café & tea")
            #expect(engine.searchTerms(in: url) == "swift café & tea")
        }
        #expect(SearchEngine.google.searchTerms(in: "https://www.google.com/search?client=x&q=a+b#frag") == "a b")
    }

    @Test func otherPagesHaveNoSearchTerms() {
        #expect(SearchEngine.duckDuckGo.searchTerms(in: "https://duckduckgo.com/about") == nil)
        #expect(SearchEngine.google.searchTerms(in: "https://swift.org/?q=x") == nil)
        #expect(SearchEngine.google.searchTerms(in: "https://www.google.com/search?q=") == nil)
    }

    @Test func percentEncodingRoundTrips() {
        #expect(PercentEncoding.encodeQuery("a b/ü") == "a+b%2F%C3%BC")
        #expect(PercentEncoding.decodeQuery("a+b%2F%C3%BC") == "a b/ü")
        #expect(PercentEncoding.decodeQuery("100%") == "100%")
        #expect(PercentEncoding.decodeQuery("%zz%4") == "%zz%4")
    }
}

@Suite struct WebAddressTests {

    @Test func partsOfAWebAddress() throws {
        let address = try #require(WebAddress("https://user:pw@WWW.Example.com:8443/a/b?c=d#e"))
        #expect(address.scheme == "https")
        #expect(address.host == "www.example.com")
        #expect(address.port == 8443)
        #expect(address.rest == "/a/b?c=d#e")
        #expect(address.displayHost == "example.com")
        #expect(address.isSecure)
        #expect(address.isWeb)
    }

    @Test func ipv6Hosts() throws {
        let address = try #require(WebAddress("http://[::1]:3000/"))
        #expect(address.host == "::1")
        #expect(address.port == 3000)
        #expect(!address.isSecure)
    }

    @Test func addressesWithoutAnAuthority() throws {
        let address = try #require(WebAddress("about:blank"))
        #expect(address.scheme == "about")
        #expect(address.host == "")
        #expect(address.rest == "blank")
        #expect(WebAddress("no scheme here") == nil)
        #expect(WebAddress(":nothing") == nil)
    }

    @Test func summariesShowTheHostOfWebPages() {
        #expect(WebAddress.summary(of: "https://www.swift.org/blog/") == "swift.org")
        #expect(WebAddress.summary(of: "file:///tmp/a.html") == "file:///tmp/a.html")
        #expect(WebAddress.summary(of: "about:blank") == "about:blank")
    }
}

@Suite struct HistoryTests {

    @Test func visitsAreLatestFirstAndCounted() {
        var history = History()
        history.record(url: "https://a.com/", title: "A")
        history.record(url: "https://b.com/", title: "B")
        history.record(url: "https://a.com/", title: "")
        #expect(history.visits.map { $0.url } == ["https://a.com/", "https://b.com/"])
        #expect(history.visits[0].count == 2)
        #expect(history.visits[0].title == "A")
    }

    @Test func blankPagesAndDataArentKept() {
        var history = History()
        history.record(url: "about:blank", title: "")
        history.record(url: "data:text/html,hi", title: "")
        history.record(url: "file:///tmp/a.html", title: "A")
        #expect(history.visits.map { $0.url } == ["file:///tmp/a.html"])
    }

    @Test func theOldestGoPastTheLimit() {
        var history = History(limit: 2)
        for name in ["a", "b", "c"] {
            history.record(url: "https://\(name).com/", title: name)
        }
        #expect(history.visits.map { $0.title } == ["c", "b"])
    }

    @Test func titlesComeLaterAndSearchIgnoresCase() {
        var history = History()
        history.record(url: "https://swift.org/", title: "")
        history.setTitle("Swift.org - Welcome", for: "https://swift.org/")
        history.record(url: "https://example.com/", title: "Example")
        #expect(history.matching("WELCOME").map { $0.url } == ["https://swift.org/"])
        #expect(history.matching("example.com").count == 1)
        #expect(history.matching("  ").count == 2)
        history.remove(url: "https://swift.org/")
        #expect(history.visits.count == 1)
        history.removeAll()
        #expect(history.visits.isEmpty)
    }
}

@Suite struct BookmarksTests {

    @Test func eachAddressOnce() {
        var bookmarks = Bookmarks()
        let first = bookmarks.add(title: "Swift", url: "https://swift.org/")
        let again = bookmarks.add(title: "Other", url: "https://swift.org/")
        #expect(first == again)
        #expect(bookmarks.items.count == 1)
        bookmarks.toggle(title: "Swift", url: "https://swift.org/")
        #expect(bookmarks.items.isEmpty)
        bookmarks.toggle(title: "Swift", url: "https://swift.org/")
        #expect(bookmarks.contains(url: "https://swift.org/"))
    }

    @Test func renamingAndMoving() {
        var bookmarks = Bookmarks()
        let a = bookmarks.add(title: "A", url: "https://a.com/")
        bookmarks.add(title: "B", url: "https://b.com/")
        let c = bookmarks.add(title: "C", url: "https://c.com/")
        bookmarks.move(id: c.id, by: -5)
        #expect(bookmarks.items.map { $0.title } == ["C", "A", "B"])
        bookmarks.move(id: a.id, by: 1)
        #expect(bookmarks.items.map { $0.title } == ["C", "B", "A"])
        bookmarks.rename(id: a.id, to: "  Ay ")
        #expect(bookmarks.items[2].title == "Ay")
        bookmarks.remove(id: c.id)
        #expect(bookmarks.matching("b.com").map { $0.title } == ["B"])
    }

    @Test func idsKeepGoingAfterLoading() {
        var bookmarks = Bookmarks(record: Bookmarks([Bookmark(id: 7, title: "A", url: "https://a.com/")]).record)
        let added = bookmarks.add(title: "B", url: "https://b.com/")
        #expect(added.id != bookmarks.items[0].id)
    }
}

@Suite struct TabsTests {

    @Test func tabsOpenAfterTheOneShown() {
        var tabs = Tabs()
        let a = tabs.open(url: "https://a.com/")
        let b = tabs.open()
        tabs.select(id: a.id)
        let c = tabs.open()
        #expect(tabs.items.map { $0.id } == [a.id, c.id, b.id])
        #expect(tabs.selectedID == c.id)
    }

    @Test func closingShowsTheNextOrElseThePrevious() {
        var tabs = Tabs()
        let a = tabs.open(), b = tabs.open(), c = tabs.open()
        tabs.select(id: b.id)
        tabs.close(id: b.id)
        #expect(tabs.selectedID == c.id)
        tabs.close(id: c.id)
        #expect(tabs.selectedID == a.id)
        tabs.close(id: a.id)
        #expect(tabs.selectedID == nil)
        #expect(tabs.items.isEmpty)
    }

    @Test func closingAnotherTabKeepsTheOneShown() {
        var tabs = Tabs()
        let a = tabs.open(), b = tabs.open()
        tabs.close(id: a.id)
        #expect(tabs.selectedID == b.id)
    }

    @Test func titlesFallBack() {
        var tabs = Tabs()
        let tab = tabs.open()
        #expect(tabs.selected?.displayTitle == "New Tab")
        tabs.update(id: tab.id, url: "https://www.swift.org/", title: "")
        #expect(tabs.selected?.displayTitle == "swift.org")
        tabs.update(id: tab.id, url: nil, title: "Swift")
        #expect(tabs.selected?.displayTitle == "Swift")
        #expect(tabs.selected?.url == "https://www.swift.org/")
    }
}

@Suite struct SuggestionsTests {

    @Test func hostsFirstThenWordsThenAnywhere() {
        var history = History()
        history.record(url: "https://example.com/aswiftly", title: "Anywhere")
        history.record(url: "https://news.com/", title: "Swift news")
        history.record(url: "https://www.swift.org/", title: "Home")
        let suggestions = Suggestions.make(for: "swi", history: history, bookmarks: Bookmarks())
        #expect(suggestions.map { $0.url } == ["https://www.swift.org/", "https://news.com/", "https://example.com/aswiftly"])
    }

    @Test func bookmarksThenTheMostVisited() {
        var history = History()
        history.record(url: "https://sa.com/", title: "")
        history.record(url: "https://sb.com/", title: "")
        history.record(url: "https://sb.com/", title: "")
        var bookmarks = Bookmarks()
        bookmarks.add(title: "S", url: "https://sc.com/")
        bookmarks.add(title: "Also visited", url: "https://sa.com/")
        let suggestions = Suggestions.make(for: "S", history: history, bookmarks: bookmarks, limit: 3)
        #expect(suggestions.map { $0.url } == ["https://sa.com/", "https://sc.com/", "https://sb.com/"])
        #expect(suggestions[0].isBookmark)
        #expect(!suggestions[2].isBookmark)
    }

    @Test func nothingTypedSuggestsNothing() {
        var history = History()
        history.record(url: "https://a.com/", title: "A")
        #expect(Suggestions.make(for: " ", history: history, bookmarks: Bookmarks()).isEmpty)
        #expect(Suggestions.make(for: "zzz", history: history, bookmarks: Bookmarks()).isEmpty)
    }
}

@Suite struct RecordsTests {

    @Test func fieldsWithTabsNewlinesAndBackslashesRoundTrip() {
        let rows = [["a\tb", "c\nd", "e\\f"], [""], ["g", ""], ["ünï"]]
        #expect(Records.decode(Records.encode(rows)) == rows)
        #expect(Records.decode("") == [])
        #expect(Records.decode("a\tb") == [["a", "b"]])
    }

    @Test func bookmarksHistoryAndTabsRoundTrip() {
        var bookmarks = Bookmarks()
        bookmarks.add(title: "Swift\t.org", url: "https://swift.org/")
        bookmarks.add(title: "", url: "https://a.com/")
        #expect(Bookmarks(record: bookmarks.record).items.map { $0.title } == ["Swift\t.org", ""])

        var history = History()
        history.record(url: "https://a.com/", title: "A")
        history.record(url: "https://a.com/", title: "A")
        history.record(url: "https://b.com/", title: "B")
        #expect(History(record: history.record) == history)

        var tabs = Tabs()
        tabs.open(url: "https://a.com/")
        let shown = tabs.open()
        tabs.update(id: shown.id, url: "https://b.com/", title: "B")
        tabs.open()
        tabs.select(id: shown.id)
        let restored = Tabs(record: tabs.record)
        #expect(restored.items.map { $0.url } == ["https://a.com/", "https://b.com/", nil])
        #expect(restored.selected?.title == "B")
    }

    @Test func badRowsAreSkipped() {
        #expect(Bookmarks(record: "only a title\n\tno title is fine\nT\t\n").items.map { $0.url } == ["no title is fine"])
        #expect(History(record: "https://a.com/\tA\tnot a number\n\n").visits.first?.count == 1)
        #expect(Tabs(record: "garbage\n").items.isEmpty)
    }
}
