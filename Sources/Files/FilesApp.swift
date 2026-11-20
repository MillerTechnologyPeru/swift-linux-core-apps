//
//  FilesApp.swift
//  CoreApps
//

// The file manager sees the whole file system, which a guest can't: it is
// a program only, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// The file manager.
public struct FilesApp: App {

    public init() { }

    /// A folder named on the command line, which the app opens at: how
    /// another program shows a folder in the file manager.
    private static var folderArgument: URL? {
        guard let argument = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            return nil
        }
        let url = URL(fileURLWithPath: argument, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Files") {
            BrowserView(opening: Self.folderArgument)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            BrowserView(opening: Self.folderArgument)
        }
        #endif
    }
}

/// The places to browse from, and the folders opened from them, one over
/// the other as on a phone.
public struct BrowserView: View {

    @State private var path: [Place]

    @StateObject private var model = FilesModel()

    /// The bookmark being given a name.
    @State private var renamedBookmark: Bookmark?

    private let locations: [Location]

    /// - Parameter folder: A folder to show at first, over the locations.
    public init(opening folder: URL? = nil, locations: [Location] = Location.standard()) {
        self.locations = locations
        self._path = State(initialValue: folder.map { [.folder($0)] } ?? [])
    }

    public var body: some View {
        NavigationStack(path: $path) {
            places
                .navigationTitle("Files")
                .navigationDestination(for: Place.self) { place in
                    switch place {
                    case let .folder(folder):
                        FolderView(folder: folder, locations: locations, path: $path)
                    case .trash:
                        TrashView()
                    case .starred:
                        StarredView(path: $path)
                    }
                }
        }
        .environmentObject(model)
        .sheet(item: $renamedBookmark) { bookmark in
            NameView(title: "Rename Bookmark", name: bookmark.name, confirm: "Rename", allowsAnyText: true) { name in
                renamedBookmark = nil
                if let name { model.renameBookmark(bookmark.url, to: name) }
            }
        }
        .alert("Couldn't Do That", isPresented: failureIsShown) {
            Button("OK") { model.failure = nil }
        } message: {
            Text(model.failure ?? "")
        }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })
    }

    private var places: some View {
        // Reading the count has a change to the bookmarks show.
        let _ = model.changes
        let bookmarks = model.bookmarks.load()
        let volumes = Volume.mounted()
        return List {
            Section("Places") {
                ForEach(locations) { location in
                    PlaceRow(name: location.name, symbolName: location.symbolName, detail: nil, place: .folder(location.url))
                }
                PlaceRow(name: "Starred", symbolName: "star", detail: nil, place: .starred)
                if model.showsTrash {
                    PlaceRow(name: "Trash", symbolName: "trash", detail: nil, place: .trash)
                }
            }
            if !bookmarks.isEmpty {
                Section("Bookmarks") {
                    ForEach(bookmarks) { bookmark in
                        PlaceRow(name: bookmark.name, symbolName: "bookmark", detail: nil, place: .folder(bookmark.url))
                            .contextMenu {
                                Button("Rename") { renamedBookmark = bookmark }
                                Button("Remove from Bookmarks", role: .destructive) {
                                    model.setBookmarked(false, for: bookmark.url)
                                }
                            }
                    }
                }
            }
            if !volumes.isEmpty {
                Section("Volumes") {
                    ForEach(volumes) { volume in
                        PlaceRow(
                            name: volume.name,
                            symbolName: "tray",
                            detail: volume.space.map { "\(ByteCount.format($0.free)) free of \(ByteCount.format($0.total))" },
                            place: .folder(volume.url)
                        )
                    }
                }
            }
        }
    }
}

/// A row for somewhere to browse.
struct PlaceRow: View {

    let name: String

    let symbolName: String

    let detail: String?

    let place: Place

    var body: some View {
        NavigationLink(value: place) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minHeight: Metrics.minimumTarget - 16)
        }
    }
}

#endif
