//
//  Tabs.swift
//  CoreApps
//

/// An open tab: what it shows, as last reported.
public struct BrowserTab: Equatable, Identifiable, Sendable {

    public var id: Int

    /// Where it is; `nil` for a new tab that hasn't gone anywhere.
    public var url: String?

    public var title: String

    public init(id: Int, url: String? = nil, title: String = "") {
        self.id = id
        self.url = url
        self.title = title
    }

    /// The title, the address, or "New Tab".
    public var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        if let url {
            return WebAddress.summary(of: url)
        }
        return "New Tab"
    }
}

/// The open tabs, in order, and the one shown.
public struct Tabs: Equatable, Sendable {

    public private(set) var items: [BrowserTab]

    /// The tab shown; `nil` only when there are none.
    public private(set) var selectedID: Int?

    private var nextID: Int

    public init(_ items: [BrowserTab] = [], selectedID: Int? = nil) {
        self.items = items
        let ids = items.map { $0.id }
        self.selectedID = selectedID.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
        nextID = (ids.max() ?? 0) + 1
    }

    public var selected: BrowserTab? {
        items.first { $0.id == selectedID }
    }

    public var count: Int { items.count }

    /// Opens a tab after the one shown, and shows it.
    @discardableResult
    public mutating func open(url: String? = nil) -> BrowserTab {
        let tab = BrowserTab(id: nextID, url: url)
        nextID += 1
        let index = items.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? items.count
        items.insert(tab, at: index)
        selectedID = tab.id
        return tab
    }

    /// Closes a tab. If it was shown, the one after it is shown, or else
    /// the one before.
    public mutating func close(id: Int) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        guard selectedID == id else { return }
        if items.isEmpty {
            selectedID = nil
        } else {
            selectedID = items[min(index, items.count - 1)].id
        }
    }

    public mutating func closeAll() {
        items.removeAll()
        selectedID = nil
    }

    public mutating func select(id: Int) {
        guard items.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    /// What a tab's page reported.
    public mutating func update(id: Int, url: String?, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let url {
            items[index].url = url
        }
        items[index].title = title
    }
}
