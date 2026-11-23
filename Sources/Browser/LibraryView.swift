//
//  LibraryView.swift
//  CoreApps
//

import AppUI
import BrowserCore
import CoreAppsUI

/// The bookmarks and the history, searchable, and the browser's settings.
struct LibraryView: View {

    @Binding var bookmarks: Bookmarks

    @Binding var history: History

    @Binding var engine: SearchEngine

    let open: (String) -> Void

    /// Something here changed, to be kept.
    let changed: () -> Void

    let done: () -> Void

    @State private var shown = Shelf.bookmarks

    @State private var query = ""

    @State private var isConfirmingClear = false

    enum Shelf: Hashable {
        case bookmarks
        case history
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $shown) {
                        Text("Bookmarks").tag(Shelf.bookmarks)
                        Text("History").tag(Shelf.history)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("shelf")
                }
                switch shown {
                case .bookmarks:
                    bookmarkRows
                case .history:
                    historyRows
                }
            }
            .searchable(text: $query)
            .navigationTitle(shown == .bookmarks ? "Bookmarks" : "History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    NavigationLink(destination: SettingsView(engine: $engine, history: $history, changed: changed)) {
                        Image(systemName: "gear")
                    }
                    .accessibilityIdentifier("settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }

    @ViewBuilder
    private var bookmarkRows: some View {
        let shownBookmarks = bookmarks.matching(query)
        if shownBookmarks.isEmpty {
            Text(query.isEmpty ? "Pages you bookmark with the star show here." : "No bookmarks match.")
                .foregroundStyle(Color.secondary)
        } else {
            Section {
                ForEach(shownBookmarks) { bookmark in
                    HStack(spacing: 0) {
                        Button {
                            open(bookmark.url)
                        } label: {
                            PageRow(title: bookmark.displayTitle, url: bookmark.url, symbol: "star")
                        }
                        .plainButton()
                        NavigationLink(destination: BookmarkEditor(bookmarks: $bookmarks, id: bookmark.id, changed: changed)) {
                            Image(systemName: "info.circle")
                                .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                        }
                        .accessibilityLabel("Edit \(bookmark.displayTitle)")
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            bookmarks.remove(id: bookmark.id)
                            changed()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyRows: some View {
        let visits = history.matching(query)
        if visits.isEmpty {
            Text(query.isEmpty ? "Pages you go to show here." : "No pages match.")
                .foregroundStyle(Color.secondary)
        } else {
            Section {
                ForEach(visits) { visit in
                    Button {
                        open(visit.url)
                    } label: {
                        PageRow(title: visit.displayTitle, url: visit.url, symbol: "clock")
                    }
                    .plainButton()
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            history.remove(url: visit.url)
                            changed()
                        }
                    }
                }
            }
            Section {
                Button("Clear History", role: .destructive) {
                    isConfirmingClear = true
                }
                .confirmationDialog("Clear all of the history?", isPresented: $isConfirmingClear) {
                    Button("Clear History", role: .destructive) {
                        history.removeAll()
                        changed()
                    }
                }
            }
        }
    }
}

/// A bookmark's title and place in the list.
struct BookmarkEditor: View {

    @Binding var bookmarks: Bookmarks

    let id: Int

    let changed: () -> Void

    @State private var title = ""

    @State private var isLoaded = false

    var body: some View {
        Form {
            if let bookmark = bookmarks.items.first(where: { $0.id == id }) {
                Section("Title") {
                    TextField("Title", text: $title)
                        .onSubmit(rename)
                        .accessibilityIdentifier("bookmark-title")
                    Button("Save Title", action: rename)
                        .disabled(title == bookmark.title)
                }
                Section("Address") {
                    Text(bookmark.url)
                        .lineLimit(3)
                }
                Section {
                    Button("Move Up") {
                        bookmarks.move(id: id, by: -1)
                        changed()
                    }
                    .disabled(bookmarks.items.first?.id == id)
                    Button("Move Down") {
                        bookmarks.move(id: id, by: 1)
                        changed()
                    }
                    .disabled(bookmarks.items.last?.id == id)
                    Button("Delete Bookmark", role: .destructive) {
                        bookmarks.remove(id: id)
                        changed()
                    }
                }
            } else {
                Text("This bookmark was deleted.")
                    .foregroundStyle(Color.secondary)
            }
        }
        .navigationTitle("Bookmark")
        .onAppear {
            guard !isLoaded else { return }
            isLoaded = true
            title = bookmarks.items.first { $0.id == id }?.title ?? ""
        }
    }

    private func rename() {
        bookmarks.rename(id: id, to: title)
        changed()
    }
}

/// Where searches go, and clearing the history.
struct SettingsView: View {

    @Binding var engine: SearchEngine

    @Binding var history: History

    let changed: () -> Void

    @State private var isConfirmingClear = false

    var body: some View {
        Form {
            Section("Search With") {
                ForEach(SearchEngine.allCases) { candidate in
                    Button {
                        engine = candidate
                        changed()
                    } label: {
                        HStack {
                            Text(candidate.name)
                            Spacer()
                            if candidate == engine {
                                Image(systemName: "checkmark")
                            }
                        }
                        .frame(minHeight: Metrics.minimumTarget)
                    }
                }
            }
            Section {
                Button("Clear History", role: .destructive) {
                    isConfirmingClear = true
                }
                .disabled(history.visits.isEmpty)
                .confirmationDialog("Clear all of the history?", isPresented: $isConfirmingClear) {
                    Button("Clear History", role: .destructive) {
                        history.removeAll()
                        changed()
                    }
                }
                Text("The history is kept on this device only. Clearing it leaves the bookmarks and the open tabs.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
