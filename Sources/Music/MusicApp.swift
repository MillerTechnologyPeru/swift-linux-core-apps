//
//  MusicApp.swift
//  CoreApps
//

// The music player finds its music on the file system and plays it itself,
// which a guest can't yet: it is a program for now, on Cacao or on Apple's
// SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation
import MusicCore

/// Somewhere the library shows.
enum MusicRoute: Hashable {
    case album(Album)
    case artist(Artist)
}

/// The music player.
public struct MusicApp: App {

    public init() { }

    /// The folder named on the command line, else the user's music.
    private static var folder: URL {
        if let argument = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
            let url = URL(fileURLWithPath: argument, isDirectory: true).standardizedFileURL
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return url
            }
        }
        let music = UserFolders().url(for: .music)
        if FileManager.default.fileExists(atPath: music.path) { return music }
        // Where an app on iOS keeps what the user gave it.
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let documents = home.appendingPathComponent("Documents", isDirectory: true)
        return FileManager.default.fileExists(atPath: documents.path) ? documents : home
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Music") {
            LibraryView(folder: Self.folder)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            LibraryView(folder: Self.folder)
        }
        #endif
    }
}

/// How the library is listed.
enum LibrarySection: String, CaseIterable, Hashable {
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
}

/// The library, by song, album or artist, over the track that's playing.
public struct LibraryView: View {

    @StateObject private var model: PlayerModel

    @State private var path: [MusicRoute] = []

    @State private var section = LibrarySection.songs

    @State private var searchText = ""

    @State private var showsPlayer = false

    public init(folder: URL) {
        _model = StateObject(wrappedValue: PlayerModel(folder: folder))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Music")
                .searchable(text: $searchText, prompt: Text("Search your music"))
                .navigationDestination(for: MusicRoute.self) { route in
                    switch route {
                    case let .album(album):
                        AlbumView(album: album)
                    case let .artist(artist):
                        ArtistView(artist: artist)
                    }
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.queue.current != nil {
                MiniPlayer { showsPlayer = true }
            }
        }
        .environmentObject(model)
        .sheet(isPresented: $showsPlayer) {
            NowPlayingView { showsPlayer = false }
                .environmentObject(model)
        }
        .alert("Can't Play", isPresented: failureIsShown) {
            Button("OK") { model.failure = nil }
        } message: {
            Text(model.failure ?? "")
        }
        .task {
            await model.load()
        }
        .task {
            await model.poll()
        }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if let all = model.tracks {
            let tracks = Library.search(all, for: searchText.trimmingCharacters(in: .whitespaces))
            if all.isEmpty {
                EmptyState("No Music", message: "There is no music in “\(model.folder.lastPathComponent)”.")
            } else {
                VStack(spacing: 0) {
                    Picker("Show", selection: $section) {
                        ForEach(LibrarySection.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    if tracks.isEmpty {
                        EmptyState("No Results", message: "Nothing in your music matches.")
                    } else {
                        list(tracks)
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Looking for music…")
                    .foregroundStyle(Color.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func list(_ tracks: [Track]) -> some View {
        switch section {
        case .songs:
            let songs = Library.songs(tracks)
            List {
                ForEach(songs) { track in
                    TrackRow(track: track, detail: "\(track.artist) · \(track.album)") {
                        model.play(songs, startingAt: track)
                    }
                }
            }
        case .albums:
            List {
                ForEach(Library.albums(tracks)) { album in
                    NavigationLink(value: MusicRoute.album(album)) {
                        TitleRow(symbolName: "square", title: album.name, detail: album.artist)
                    }
                }
            }
        case .artists:
            List {
                ForEach(Library.artists(tracks)) { artist in
                    NavigationLink(value: MusicRoute.artist(artist)) {
                        TitleRow(
                            symbolName: "person",
                            title: artist.name,
                            detail: artist.trackCount == 1 ? "1 song" : "\(artist.trackCount) songs"
                        )
                    }
                }
            }
        }
    }
}

/// A row of a symbol, a title and a line under it.
struct TitleRow: View {

    let symbolName: String

    let title: String

    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: Metrics.minimumTarget - 8)
    }
}

/// A track: tapped, it plays. The one playing is marked.
struct TrackRow: View {

    let track: Track

    /// What's under the title, or the track's number before it.
    var detail: String?

    var number: Int?

    let action: () -> Void

    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        let isCurrent = model.queue.current == track
        return Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if isCurrent {
                        Image(systemName: model.isPlaying ? "play.fill" : "pause.fill")
                            .foregroundStyle(Color.accentColor)
                    } else if let number {
                        Text("\(number)")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    } else {
                        Image(systemName: "play")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .lineLimit(1)
                        .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let duration = track.tags.duration {
                    Text(Library.time(duration))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(minHeight: Metrics.minimumTarget - 8)
        }
        .plainButton()
    }
}

/// An album's tracks, in order.
struct AlbumView: View {

    let album: Album

    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name)
                        .font(.headline)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    HStack(spacing: 16) {
                        Button("Play") { model.play(album.tracks) }
                        Button("Shuffle") { model.shuffle(album.tracks) }
                    }
                    .padding(.top, 4)
                }
            }
            Section {
                ForEach(album.tracks) { track in
                    TrackRow(track: track, number: track.tags.trackNumber) {
                        model.play(album.tracks, startingAt: track)
                    }
                }
            }
        }
        .navigationTitle(album.name)
    }

    private var summary: String {
        var parts = [album.artist]
        if let year = album.year { parts.append("\(year)") }
        parts.append(album.tracks.count == 1 ? "1 song" : "\(album.tracks.count) songs")
        if album.duration > 0 { parts.append(Library.time(album.duration)) }
        return parts.joined(separator: " · ")
    }
}

/// An artist's albums, each with its tracks.
struct ArtistView: View {

    let artist: Artist

    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        let all = artist.albums.flatMap(\.tracks)
        return List {
            Section {
                HStack(spacing: 16) {
                    Button("Play") { model.play(all) }
                    Button("Shuffle") { model.shuffle(all) }
                }
            }
            ForEach(artist.albums) { album in
                Section(album.name) {
                    ForEach(album.tracks) { track in
                        TrackRow(track: track, number: track.tags.trackNumber) {
                            model.play(all, startingAt: track)
                        }
                    }
                }
            }
        }
        .navigationTitle(artist.name)
    }
}

#endif
