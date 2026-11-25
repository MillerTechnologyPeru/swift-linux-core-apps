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

    /// The window group of browsing windows, which the desktop opens
    /// folders in.
    static let browserID = "browser"

    /// Whether the program also draws the desktop: `files --desktop`, as
    /// the session starts it. The desktop is the first window then, in the
    /// background layer of the screen, and folders opened from it get
    /// windows of their own in the same program.
    static var drawsDesktop: Bool {
        CommandLine.arguments.dropFirst().contains("--desktop")
    }

    /// Whether the program is the desktop portal's file chooser alone:
    /// `files --file-chooser`, as D-Bus starts it for a request.
    public static var isFileChooser: Bool {
        CommandLine.arguments.dropFirst().contains("--file-chooser")
    }

    public var body: some Scene {
        #if Native
        if Self.isFileChooser {
            fileChooser
        }
        if Self.drawsDesktop {
            WindowGroup("Desktop", id: "desktop") {
                DesktopView()
            }
            // Anchored to every edge, so as big as the screen. An exclusive
            // zone of -1 goes under the space the menu bar and dock keep,
            // too. The keyboard comes only when the desktop is clicked, so
            // starting it doesn't take focus from a window.
            .defaultSize(width: 1280, height: 800)
            .windowLayer(
                .background,
                edges: .all,
                exclusiveZone: -1,
                keyboardInteractivity: .onDemand,
                namespace: "cacao-desktop"
            )
        }
        // On a desktop the window opens at a phone's size.
        WindowGroup("Files", id: Self.browserID, for: URL.self) { $folder in
            BrowserView(opening: folder ?? Self.folderArgument)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        // The desktop shows the file chooser's dialogs too.
        if !Self.isFileChooser {
            fileChooser
        }
        #elseif os(macOS)
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

#if Native

extension FilesApp {

    /// The file chooser's dialogs, a window for each request.
    private var fileChooser: some Scene {
        WindowGroup("Choose Files", id: FileChooserHost.windowID, for: String.self) { $handle in
            FileChooserWindow(handle: $handle)
        }
        .defaultSize(width: 820, height: 540)
    }

    /// Runs the program as the desktop portal's file chooser: it serves
    /// the portal on the session bus, opens its first window for the first
    /// request, and quits a while after the last dialog closes. Requests
    /// still open then are answered as ended.
    public static func runFileChooser() {
        let host = FileChooserHost.shared
        host.reservesFirstRequest = true
        let serving = ServingResult()
        Task.detached {
            serving.owns = await FileChooserHost.serve()
            serving.done.signal()
        }
        serving.done.wait()
        guard serving.owns else { exit(EXIT_FAILURE) }
        // D-Bus started the program for a request, which comes at once.
        guard host.firstRequest.wait(timeout: .now() + 30) == .success else { return }
        main()
        host.cancelAll()
        host.waitForAnswers()
    }
}

/// Whether the file chooser could start serving, from the task that tried.
private final class ServingResult: @unchecked Sendable {

    var owns = false

    let done = DispatchSemaphore(value: 0)
}

#endif

/// The places to browse from, and the folders opened from them, one over
/// the other as on a phone.
public struct BrowserView: View {

    @State private var path: [Place]

    @StateObject private var model = FilesModel()

    /// The bookmark being given a name.
    @State private var renamedBookmark: Bookmark?

    #if Native
    /// Disks from UDisks, to mount and eject.
    @StateObject private var disks = VolumesModel()
    #endif

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
        #if Native
        .task { await disks.follow() }
        #endif
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
            #if Native
            if disks.usesUDisks {
                if !disks.volumes.isEmpty {
                    Section("Volumes") {
                        ForEach(disks.volumes) { volume in
                            VolumeRow(
                                volume: volume,
                                model: disks,
                                open: { path = [.folder($0)] },
                                fail: { model.failure = $0 }
                            )
                        }
                    }
                }
            } else if !volumes.isEmpty {
                mountedVolumes(volumes)
            }
            #else
            if !volumes.isEmpty {
                mountedVolumes(volumes)
            }
            #endif
        }
    }

    /// The volumes mounted, as `/proc/self/mounts` lists them.
    private func mountedVolumes(_ volumes: [Volume]) -> some View {
        Group {
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
