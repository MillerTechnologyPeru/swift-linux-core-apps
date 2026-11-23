//
//  BrowserView.swift
//  CoreApps
//

import AppUI
import AppWeb
import BrowserCore
import CoreAppsUI

/// The browser: the page of the tab shown, or a new tab's start page, with
/// the address bar and the buttons under it, where a thumb reaches them.
public struct BrowserView: View {

    @State private var tabs = Tabs()

    @State private var pages = Pages()

    @State private var history = History()

    @State private var bookmarks = Bookmarks()

    @State private var engine = SearchEngine.standard

    /// Whether what's kept from the last run has been read.
    @State private var isLoaded = false

    /// The address bar is being typed in, with the suggestions shown.
    @State private var isEditing = false

    @State private var typed = ""

    @FocusState private var isFieldFocused: Bool

    @State private var isShowingTabs = false

    @State private var isShowingLibrary = false

    public init() { }

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let page = shownPage, page.isLoading, !isEditing {
                ProgressView(value: page.estimatedProgress)
                    .accessibilityIdentifier("progress")
            }
            Divider()
            AddressBar(
                summary: summary,
                isSecure: isSecure,
                isEditing: isEditing,
                isLoading: shownPage?.isLoading ?? false,
                hasPage: shownPage?.url != nil,
                typed: $typed,
                isFieldFocused: $isFieldFocused,
                beginEditing: beginEditing,
                endEditing: endEditing,
                submit: { go(to: typed) },
                reloadOrStop: reloadOrStop
            )
            if !isEditing {
                ToolbarRow(
                    canGoBack: shownPage?.canGoBack ?? false,
                    canGoForward: shownPage?.canGoForward ?? false,
                    isBookmarked: shownURL.map { bookmarks.contains(url: $0) } ?? false,
                    canBookmark: shownURL != nil,
                    tabCount: tabs.count,
                    goBack: { shownPage?.goBack() },
                    goForward: { shownPage?.goForward() },
                    toggleBookmark: toggleBookmark,
                    showLibrary: { isShowingLibrary = true },
                    showTabs: { isShowingTabs = true }
                )
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $isShowingTabs) {
            TabsView(
                tabs: tabs,
                pages: pages,
                select: { id in
                    select(id)
                    isShowingTabs = false
                },
                close: close,
                closeAll: closeAll,
                openNew: {
                    openTab(url: nil)
                    isShowingTabs = false
                },
                done: { isShowingTabs = false }
            )
        }
        .sheet(isPresented: $isShowingLibrary) {
            LibraryView(
                bookmarks: $bookmarks,
                history: $history,
                engine: $engine,
                open: { url in
                    isShowingLibrary = false
                    go(to: url)
                },
                changed: save,
                done: { isShowingLibrary = false }
            )
        }
    }

    // MARK: What's shown

    @ViewBuilder
    private var content: some View {
        if isEditing {
            SuggestionsView(
                suggestions: Suggestions.make(for: typed, history: history, bookmarks: bookmarks),
                typed: typed,
                engine: engine,
                open: { url in go(to: url) },
                submit: { go(to: typed) }
            )
        } else if let tab = tabs.selected, let page = pages[tab.id], page.url != nil || page.isLoading || page.error != nil {
            ZStack {
                WebView(page)
                    .id(tab.id)
                if let error = page.error, error.code != .cancelled {
                    PageErrorView(error: error, url: tab.url, retry: { retry(tab) })
                }
            }
        } else {
            StartView(
                bookmarks: bookmarks.items,
                recent: Array(history.visits.prefix(8)),
                open: { url in go(to: url) }
            )
        }
    }

    private var shownPage: WebPage? {
        tabs.selectedID.flatMap { pages[$0] }
    }

    private var shownURL: String? {
        shownPage?.url ?? tabs.selected?.url
    }

    /// What the bar shows: the search, on a page of results; the host of a
    /// web page; or the address of anything else.
    private var summary: String? {
        guard let url = shownURL else { return nil }
        if let terms = engine.searchTerms(in: url) {
            return terms
        }
        return WebAddress.summary(of: url)
    }

    private var isSecure: Bool {
        guard let url = shownURL, engine.searchTerms(in: url) == nil else { return false }
        return WebAddress(url)?.isSecure ?? false
    }

    // MARK: The address bar

    private func beginEditing() {
        if let url = shownURL {
            typed = engine.searchTerms(in: url) ?? url
        } else {
            typed = ""
        }
        isEditing = true
        isFieldFocused = true
    }

    private func endEditing() {
        isFieldFocused = false
        isEditing = false
    }

    /// Goes to what's typed, or searches for it, in the tab shown.
    private func go(to text: String) {
        guard let url = AddressInput.destination(for: text, engine: engine) else { return }
        endEditing()
        guard let tab = tabs.selected else {
            openTab(url: url)
            return
        }
        page(for: tab).load(url)
        tabs.update(id: tab.id, url: url, title: "")
        save()
    }

    private func reloadOrStop() {
        guard let page = shownPage else { return }
        if page.isLoading {
            page.stopLoading()
        } else {
            page.reload()
        }
    }

    private func retry(_ tab: BrowserTab) {
        guard let page = pages[tab.id] else { return }
        if let url = page.url ?? tab.url {
            page.load(url)
        } else {
            page.reload()
        }
    }

    private func toggleBookmark() {
        guard let url = shownURL else { return }
        bookmarks.toggle(title: shownPage?.title ?? tabs.selected?.title ?? "", url: url)
        save()
    }

    // MARK: Tabs

    /// The tab's page, made the first time it's needed: it records each
    /// page it finishes in the history.
    private func page(for tab: BrowserTab) -> WebPage {
        if let page = pages[tab.id] {
            return page
        }
        let page = WebPage()
        let id = tab.id
        page.onFinish = { finished(id) }
        pages.insert(page, for: id)
        return page
    }

    private func finished(_ id: Int) {
        guard let page = pages[id], let url = page.url else { return }
        history.record(url: url, title: page.title)
        tabs.update(id: id, url: url, title: page.title)
        save()
    }

    private func openTab(url: String?) {
        let tab = tabs.open(url: url)
        if let url {
            page(for: tab).load(url)
        }
        save()
        if url == nil {
            beginEditing()
        }
    }

    /// Shows a tab, loading it if it came from the last run.
    private func select(_ id: Int) {
        tabs.select(id: id)
        if let tab = tabs.selected, pages[id] == nil, let url = tab.url {
            page(for: tab).load(url)
        }
        save()
    }

    private func close(_ id: Int) {
        pages.remove(id)
        tabs.close(id: id)
        if tabs.count == 0 {
            tabs.open()
        } else if let selected = tabs.selectedID {
            select(selected)
        }
        save()
    }

    private func closeAll() {
        pages.removeAll()
        tabs.closeAll()
        tabs.open()
        isShowingTabs = false
        save()
    }

    // MARK: Keeping

    /// Reads the bookmarks, history, search engine and tabs of the last
    /// run, and loads the tab that was shown.
    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        bookmarks = Bookmarks(record: Storage.string(.bookmarks) ?? "")
        history = History(record: Storage.string(.history) ?? "")
        engine = Storage.string(.searchEngine).flatMap(SearchEngine.init(rawValue:)) ?? .standard
        tabs = Tabs(record: Storage.string(.tabs) ?? "")
        if let argument = Self.argument {
            // A program opens the address it's given in a tab of its own.
            openTab(url: AddressInput.destination(for: argument, engine: engine))
        } else if tabs.count == 0 {
            tabs.open()
        } else if let selected = tabs.selectedID {
            select(selected)
        }
    }

    private func save() {
        for tab in tabs.items {
            if let page = pages[tab.id], let url = page.url {
                tabs.update(id: tab.id, url: url, title: page.title)
                // A title can come after its page finished.
                history.setTitle(page.title, for: url)
            }
        }
        Storage.set(tabs.record, .tabs)
        Storage.set(history.record, .history)
        Storage.set(bookmarks.record, .bookmarks)
        Storage.set(engine.rawValue, .searchEngine)
    }

    /// The address a program was started with: `browser swift.org`.
    private static var argument: String? {
        #if Native || Apple
        CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil
        #else
        nil
        #endif
    }
}
