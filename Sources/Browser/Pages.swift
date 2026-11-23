//
//  Pages.swift
//  CoreApps
//

import AppWeb

/// The pages of the open tabs, by the tab's identifier. A tab has a page
/// once it has gone somewhere; a tab opened again from the last run gets
/// its page when it's first shown, so only the tab shown loads at launch.
///
/// Not observable: each page is, and the tabs that say which pages there
/// are live in the browser's state.
final class Pages {

    private var pages: [Int: WebPage] = [:]

    subscript(id: Int) -> WebPage? {
        pages[id]
    }

    func insert(_ page: WebPage, for id: Int) {
        pages[id] = page
    }

    /// The tab is closed: its page stops and goes.
    func remove(_ id: Int) {
        pages[id]?.stopLoading()
        pages[id] = nil
    }

    func removeAll() {
        for page in pages.values {
            page.stopLoading()
        }
        pages.removeAll()
    }
}
