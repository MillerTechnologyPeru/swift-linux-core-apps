//
//  Library.swift
//  CoreApps
//

/// A track as the library lists it.
public struct Track: Identifiable, Hashable, Sendable {

    /// What tells the track from others: its file's path.
    public var id: String

    /// The file's name, shown when the file has no title.
    public var fileName: String

    public var tags: TrackTags

    public init(id: String, fileName: String, tags: TrackTags = TrackTags()) {
        self.id = id
        self.fileName = fileName
        self.tags = tags
    }

    /// The title, or the file's name without its extension.
    public var title: String {
        if let title = tags.title { return title }
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return fileName }
        return String(fileName[..<dot])
    }

    public var artist: String {
        tags.artist ?? "Unknown Artist"
    }

    public var album: String {
        tags.album ?? "Unknown Album"
    }
}

/// An album: its tracks in the order of their numbers.
public struct Album: Identifiable, Hashable, Sendable {

    public var name: String

    public var artist: String

    public var tracks: [Track]

    public var id: String { artist + "\u{1F}" + name }

    public var year: Int? {
        tracks.compactMap(\.tags.year).first
    }

    /// How long the album plays, where its tracks say.
    public var duration: Double {
        tracks.compactMap(\.tags.duration).reduce(0, +)
    }
}

/// An artist, and their albums by name.
public struct Artist: Identifiable, Hashable, Sendable {

    public var name: String

    public var albums: [Album]

    public var id: String { name }

    public var trackCount: Int {
        albums.reduce(0) { $0 + $1.tracks.count }
    }
}

/// Tracks, sorted and gathered into albums and artists.
public enum Library {

    /// A text as it's compared for sorting: lowercased, and without a
    /// leading "The ".
    static func sortKey(_ text: String) -> String {
        let lowered = text.lowercased()
        return lowered.hasPrefix("the ") ? String(lowered.dropFirst(4)) : lowered
    }

    static func ordered(_ a: String, _ b: String) -> Bool {
        let first = sortKey(a), second = sortKey(b)
        return first == second ? a < b : first < second
    }

    /// Tracks by title.
    public static func songs(_ tracks: [Track]) -> [Track] {
        tracks.sorted { $0.title == $1.title ? $0.id < $1.id : ordered($0.title, $1.title) }
    }

    /// Tracks gathered into albums, by album name. Tracks of one album
    /// name by different artists are different albums.
    public static func albums(_ tracks: [Track]) -> [Album] {
        var grouped: [String: Album] = [:]
        for track in tracks {
            let album = Album(name: track.album, artist: track.artist, tracks: [])
            grouped[album.id, default: album].tracks.append(track)
        }
        return grouped.values
            .map { album in
                var album = album
                album.tracks.sort { first, second in
                    let a = first.tags.trackNumber ?? Int.max, b = second.tags.trackNumber ?? Int.max
                    return a == b ? ordered(first.title, second.title) : a < b
                }
                return album
            }
            .sorted { $0.name == $1.name ? ordered($0.artist, $1.artist) : ordered($0.name, $1.name) }
    }

    /// Tracks gathered into artists, by name.
    public static func artists(_ tracks: [Track]) -> [Artist] {
        var grouped: [String: [Album]] = [:]
        for album in albums(tracks) {
            grouped[album.artist, default: []].append(album)
        }
        return grouped
            .map { Artist(name: $0.key, albums: $0.value) }
            .sorted { ordered($0.name, $1.name) }
    }

    /// The tracks that have a text in their title, artist or album.
    public static func search(_ tracks: [Track], for text: String) -> [Track] {
        let wanted = text.lowercased()
        guard !wanted.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.lowercased().contains(wanted) || $0.artist.lowercased().contains(wanted) || $0.album.lowercased().contains(wanted)
        }
    }

    /// A length of time as players write it: "3:07", "1:02:45".
    public static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(rest))" : "\(minutes):\(two(rest))"
    }
}
