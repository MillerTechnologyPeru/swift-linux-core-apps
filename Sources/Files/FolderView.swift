//
//  FolderView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// How far back a search looks.
enum SearchAge: String, CaseIterable, Hashable {
    case any = "Any Time"
    case day = "Since Yesterday"
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case year = "Last Year"

    var since: Date? {
        let day: TimeInterval = 86_400
        switch self {
        case .any: return nil
        case .day: return Date().addingTimeInterval(-day)
        case .week: return Date().addingTimeInterval(-7 * day)
        case .month: return Date().addingTimeInterval(-30 * day)
        case .year: return Date().addingTimeInterval(-365 * day)
        }
    }
}

/// A folder's items, as a list or a grid. Folders open in place and files
/// in their programs; items are changed from their menus, several at once
/// when selecting, and the folder from the toolbar's menu.
struct FolderView: View {

    let folder: URL

    let locations: [Location]

    /// The places open, for going to a folder above or to a found item's.
    @Binding var path: [Place]

    @EnvironmentObject private var model: FilesModel

    /// What a sheet is showing.
    enum Sheet: Identifiable {
        case rename(FileItem)
        case batchRename([URL])
        case newFolder
        case newDocument
        case selectMatching
        case properties(URL)

        var id: String {
            switch self {
            case let .rename(item): "rename:" + item.url.path
            case .batchRename: "batchRename"
            case .newFolder: "newFolder"
            case .newDocument: "newDocument"
            case .selectMatching: "selectMatching"
            case let .properties(url): "properties:" + url.path
            }
        }
    }

    @State private var sheet: Sheet?

    /// The items picked while selecting; `nil` when not selecting.
    @State private var selection: Set<URL>?

    /// The items waiting for the user to agree to deleting them for good.
    @State private var condemned: [URL] = []

    @State private var searchText = ""

    @State private var searchKind: FileKind?

    @State private var searchAge = SearchAge.any

    @State private var searchesContents = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        // Reading the count is what has a change evaluate the view again.
        let _ = model.changes
        let listing = Result(catching: { try load() })
        let items = (try? listing.get()) ?? []
        return content(listing)
            .safeAreaInset(edge: .top, spacing: 0) {
                if isSearching { filterBar } else { pathBar }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let selection { selectionBar(selection, among: items) }
            }
            .navigationTitle(Location.title(for: folder, among: locations))
            .searchable(text: $searchText, prompt: Text("Search this folder"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selection != nil {
                        Button("Done") { selection = nil }
                    } else {
                        Menu {
                            folderMenu
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                view(for: sheet, items: items)
            }
            .confirmationDialog(
                condemned.count == 1 ? "Delete “\(condemned[0].lastPathComponent)” for good?" : "Delete \(condemned.count) items for good?",
                isPresented: isCondemning,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    model.deletePermanently(condemned)
                    condemned = []
                    selection = nil
                }
                Button("Cancel", role: .cancel) { condemned = [] }
            } message: {
                Text("This can't be undone.")
            }
    }

    private var isCondemning: Binding<Bool> {
        Binding(get: { !condemned.isEmpty }, set: { if !$0 { condemned = [] } })
    }

    /// The folder's items, or what a search of it finds.
    private func load() throws -> [FileItem] {
        guard isSearching else {
            return try DirectoryListing.load(folder, options: model.options)
        }
        let query = FileQuery(
            text: searchText,
            kind: searchKind,
            modifiedSince: searchAge.since,
            searchesContents: searchesContents,
            showsHidden: model.options.showsHidden
        )
        let found = FileSearch.find(query, in: folder, limit: 200)
        return DirectoryListing.sorted(found, by: model.options.sort, isReversed: model.options.isReversed, foldersFirst: model.options.foldersFirst)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ listing: Result<[FileItem], any Error>) -> some View {
        switch listing {
        case let .success(items) where items.isEmpty:
            if isSearching {
                EmptyState("No Results", message: "Nothing in this folder matches.")
            } else {
                EmptyState("Folder Is Empty", message: model.options.showsHidden ? nil : "Hidden files aren't shown.")
            }
        case let .success(items):
            if model.showsGrid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 12) {
                        ForEach(items) { item in
                            cell(for: item) {
                                FileTile(item: item, mark: mark(for: item), isCut: isCut(item))
                            }
                        }
                    }
                    .padding(12)
                }
            } else {
                List {
                    ForEach(items) { item in
                        cell(for: item) {
                            FileRow(
                                item: item,
                                location: isSearching ? item.url.deletingLastPathComponent().path : nil,
                                mark: mark(for: item),
                                isCut: isCut(item)
                            )
                        }
                    }
                }
            }
        case let .failure(error):
            EmptyState("Can't Open Folder", message: error.localizedDescription)
        }
    }

    /// An item as a button: it opens, or is picked while selecting.
    private func cell<Label: View>(for item: FileItem, @ViewBuilder label: () -> Label) -> some View {
        Button {
            activate(item)
        } label: {
            label()
        }
        .plainButton()
        .contextMenu { actions(for: item) }
    }

    /// The mark beside an item: picked or not while selecting, else none.
    private func mark(for item: FileItem) -> Bool? {
        selection.map { $0.contains(item.url) }
    }

    private func isCut(_ item: FileItem) -> Bool {
        guard let clipboard = model.clipboard, clipboard.isCut else { return false }
        return clipboard.items.contains(item.url)
    }

    private func activate(_ item: FileItem) {
        if var picked = selection {
            if picked.remove(item.url) == nil { picked.insert(item.url) }
            selection = picked
        } else if item.isFolder {
            path.append(.folder(item.url))
        } else if FileOpener.canOpen {
            model.open(item.url)
        } else {
            sheet = .properties(item.url)
        }
    }

    // MARK: Bars

    /// The folders from the root down to this one, each a way up.
    private var pathBar: some View {
        let ancestors = Location.ancestors(of: folder)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(ancestors.enumerated()), id: \.offset) { index, url in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                    Button(url.path == "/" ? "Computer" : url.lastPathComponent) {
                        if url.path != folder.standardizedFileURL.path {
                            path = [.folder(url)]
                        }
                    }
                    .plainButton()
                    .font(.footnote)
                    .foregroundStyle(index == ancestors.count - 1 ? Color.primary : Color.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    /// What a search is narrowed by.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Menu(searchKind.map { $0.rawValue.capitalized } ?? "Any Kind") {
                    Picker("Kind", selection: $searchKind) {
                        Text("Any Kind").tag(FileKind?.none)
                        ForEach([FileKind.folder, .document, .text, .image, .audio, .video, .archive], id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(FileKind?.some(kind))
                        }
                    }
                }
                Menu(searchAge.rawValue) {
                    Picker("When", selection: $searchAge) {
                        ForEach(SearchAge.allCases, id: \.self) { age in
                            Text(age.rawValue).tag(age)
                        }
                    }
                }
                Menu(searchesContents ? "Names and Text" : "Names") {
                    Picker("Search", selection: $searchesContents) {
                        Text("File Names").tag(false)
                        Text("Names and Text Inside").tag(true)
                    }
                }
            }
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    /// What can be done with the picked items.
    private func selectionBar(_ picked: Set<URL>, among items: [FileItem]) -> some View {
        // In the order shown, which numbering in a batch rename follows.
        let urls = items.map(\.url).filter(picked.contains)
        return HStack(spacing: 20) {
            Text(urls.isEmpty ? "Select Items" : "\(urls.count) Selected")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 0)
            Button("Cut") {
                model.cut(urls)
                selection = nil
            }
            .disabled(urls.isEmpty)
            Button("Copy") {
                model.copy(urls)
                selection = nil
            }
            .disabled(urls.isEmpty)
            Button("Trash") {
                model.trash(urls)
                selection = nil
            }
            .disabled(urls.isEmpty)
            Menu("More") {
                Button("Select All") { selection = Set(items.map(\.url)) }
                Button("Invert Selection") { selection = Set(items.map(\.url)).subtracting(picked) }
                Button("Select Items Matching…") { sheet = .selectMatching }
                if !urls.isEmpty {
                    Divider()
                    Button("Rename…") {
                        if urls.count == 1, let item = items.first(where: { $0.url == urls[0] }) {
                            sheet = .rename(item)
                        } else {
                            sheet = .batchRename(urls)
                        }
                    }
                    Button("Duplicate") {
                        model.duplicate(urls)
                        selection = nil
                    }
                    Button("Make Links") {
                        model.link(urls, in: folder)
                        selection = nil
                    }
                    if Archive.canCompress {
                        Button("Compress") {
                            model.compress(urls)
                            selection = nil
                        }
                    }
                    Button("Delete Permanently…", role: .destructive) { condemned = urls }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.12))
    }

    // MARK: Menus

    /// What can be done in the folder, and how it's shown.
    @ViewBuilder
    private var folderMenu: some View {
        Button("New Folder") { sheet = .newFolder }
        Button("New Document") { sheet = .newDocument }
        ForEach(FileOperations.templates(in: model.folders.url(for: .templates)), id: \.self) { template in
            Button("New “\(template.lastPathComponent)”") {
                model.createFile(named: template.lastPathComponent, in: folder, from: template)
            }
        }
        if let clipboard = model.clipboard {
            Button(clipboard.items.count == 1 ? "Paste “\(clipboard.items[0].lastPathComponent)”" : "Paste \(clipboard.items.count) Items") {
                model.paste(into: folder)
            }
        }
        Divider()
        Button("Select") { selection = [] }
        Button("Select Items Matching…") { sheet = .selectMatching }
        Divider()
        Picker("View", selection: $model.showsGrid) {
            Text("List").tag(false)
            Text("Grid").tag(true)
        }
        Picker("Sort by", selection: $model.options.sort) {
            Text("Name").tag(FileSort.name)
            Text("Date").tag(FileSort.modified)
            Text("Size").tag(FileSort.size)
            Text("Type").tag(FileSort.type)
        }
        Toggle("Reversed", isOn: $model.options.isReversed)
        Toggle("Folders First", isOn: $model.options.foldersFirst)
        Toggle("Show Hidden Files", isOn: $model.options.showsHidden)
        Divider()
        if let name = model.undoStack.undoName {
            Button("Undo \(name)") { model.undo() }
        }
        if let name = model.undoStack.redoName {
            Button("Redo \(name)") { model.redo() }
        }
        if model.bookmarks.contains(folder) {
            Button("Remove from Bookmarks") { model.setBookmarked(false, for: folder) }
        } else {
            Button("Add to Bookmarks") { model.setBookmarked(true, for: folder) }
        }
        if FileOpener.canOpenTerminal {
            Button("Open in Terminal") { model.openTerminal(in: folder) }
        }
        Button("Properties") { sheet = .properties(folder) }
    }

    /// What can be done with an item, from its menu.
    @ViewBuilder
    private func actions(for item: FileItem) -> some View {
        if item.isFolder {
            Button("Open") { path.append(.folder(item.url)) }
        } else if FileOpener.canOpen {
            Button("Open") { model.open(item.url) }
        }
        if isSearching {
            Button("Open Item Location") { path.append(.folder(item.url.deletingLastPathComponent())) }
        }
        Divider()
        Button("Cut") { model.cut([item.url]) }
        Button("Copy") { model.copy([item.url]) }
        Button("Duplicate") { model.duplicate([item.url]) }
        Button("Rename…") { sheet = .rename(item) }
        Button("Make Link") { model.link([item.url], in: item.url.deletingLastPathComponent()) }
        if model.starred.contains(item.url) {
            Button("Unstar") { model.setStarred(false, for: item.url) }
        } else {
            Button("Star") { model.setStarred(true, for: item.url) }
        }
        if item.isFolder {
            if model.bookmarks.contains(item.url) {
                Button("Remove from Bookmarks") { model.setBookmarked(false, for: item.url) }
            } else {
                Button("Add to Bookmarks") { model.setBookmarked(true, for: item.url) }
            }
        }
        if Archive.canExtract(item.url) {
            Button("Extract Here") { model.extract(item.url) }
        }
        if Archive.canCompress {
            Button("Compress") { model.compress([item.url]) }
        }
        Divider()
        Button("Move to Trash", role: .destructive) { model.trash([item.url]) }
        Button("Delete Permanently…", role: .destructive) { condemned = [item.url] }
        Divider()
        Button("Properties") { sheet = .properties(item.url) }
    }

    // MARK: Sheets

    @ViewBuilder
    private func view(for sheet: Sheet, items: [FileItem]) -> some View {
        switch sheet {
        case let .rename(item):
            NameView(title: "Rename", name: item.name, confirm: "Rename") { name in
                self.sheet = nil
                selection = nil
                if let name { model.rename(item.url, to: name) }
            }
        case let .batchRename(urls):
            BatchRenameView(items: urls) { rule in
                self.sheet = nil
                if let rule {
                    model.rename(urls, with: rule)
                    selection = nil
                }
            }
        case .newFolder:
            NameView(title: "New Folder", name: "New Folder", confirm: "Create") { name in
                self.sheet = nil
                if let name { model.createFolder(named: name, in: folder) }
            }
        case .newDocument:
            NameView(title: "New Document", name: "New Document.txt", confirm: "Create") { name in
                self.sheet = nil
                if let name { model.createFile(named: name, in: folder) }
            }
        case .selectMatching:
            NameView(title: "Select Items Matching", name: "*", confirm: "Select", allowsAnyText: true, footer: "* stands for any characters, ? for exactly one: *.jpg, Report-??.txt") { pattern in
                self.sheet = nil
                if let pattern {
                    let matcher = FilePattern(pattern)
                    selection = Set(items.filter { matcher.matches($0.name) }.map(\.url))
                }
            }
        case let .properties(url):
            PropertiesView(url: url) { self.sheet = nil }
        }
    }
}

#endif
