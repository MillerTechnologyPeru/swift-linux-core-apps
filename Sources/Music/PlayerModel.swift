//
//  PlayerModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import FilesCore
import Foundation
import MusicCore

/// The library, what's lined up to play, and the playing itself.
@MainActor
final class PlayerModel: ObservableObject {

    /// The tracks found; `nil` until the folder has been looked through.
    @Published var tracks: [Track]?

    @Published var queue = PlayQueue<Track>()

    @Published var isPlaying = false

    /// How far into the track playing has got, in seconds.
    @Published var elapsed = 0.0

    /// What went wrong, shown until dismissed.
    @Published var failure: String?

    /// The folder the library is of.
    let folder: URL

    private let engine: any AudioEngine

    init(folder: URL) {
        self.folder = folder
        #if Native
        engine = SDLAudioEngine()
        #else
        engine = SystemAudioEngine()
        #endif
    }

    /// How long the track playing is: the engine's word, else its tags'.
    var duration: Double {
        engine.duration ?? queue.current?.tags.duration ?? 0
    }

    // MARK: The library

    /// The most files looked at, for a folder as large as a disk.
    private nonisolated static let fileLimit = 20_000

    /// Reads the tags of the music under a folder.
    nonisolated static func scan(_ folder: URL) -> [Track] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return []
        }
        var tracks: [Track] = []
        var seen = 0
        for case let url as URL in walker {
            seen += 1
            if seen > fileLimit { break }
            guard FileKind(pathExtension: url.pathExtension) == .audio,
                  let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            tracks.append(Track(id: url.path, fileName: url.lastPathComponent, tags: tags(of: url, size: values.fileSize ?? 0)))
        }
        return tracks
    }

    /// A file's tags, from as little of the file as holds them.
    nonisolated static func tags(of url: URL, size: Int) -> TrackTags {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return TrackTags() }
        defer { try? handle.close() }
        var header = handle.readData(ofLength: 1 << 18)
        // MPEG-4 may keep its tags at the end: such a file is read whole,
        // unless it's very large.
        if AudioFormat(header: [UInt8](header.prefix(16))) == .m4a, size > header.count, size <= 64 << 20 {
            header.append(handle.readDataToEndOfFile())
        }
        var tail = Data()
        if size > 128, (try? handle.seek(toOffset: UInt64(size - 128))) != nil {
            tail = handle.readData(ofLength: 128)
        }
        return TrackTags(header: [UInt8](header), tail: [UInt8](tail), fileSize: size)
    }

    func load() async {
        let folder = folder
        let found = await Task.detached { Self.scan(folder) }.value
        tracks = found
    }

    // MARK: Playing

    /// Lines up tracks and plays one of them.
    func play(_ tracks: [Track], startingAt track: Track? = nil) {
        queue.play(tracks, startingAt: track)
        start()
    }

    /// Plays tracks in a mixed order.
    func shuffle(_ tracks: [Track]) {
        guard let first = tracks.randomElement() else { return }
        queue.setShuffled(false)
        queue.play(tracks, startingAt: first)
        queue.setShuffled(true)
        start()
    }

    /// Starts the queue's current track from its beginning.
    private func start() {
        guard let track = queue.current else {
            stop()
            return
        }
        elapsed = 0
        do {
            try engine.load(URL(fileURLWithPath: track.id))
            engine.play()
            isPlaying = true
        } catch let error as AudioFailure {
            isPlaying = false
            failure = "“\(track.title)”: \(error.message)"
        } catch {
            isPlaying = false
            failure = error.localizedDescription
        }
    }

    private func stop() {
        engine.pause()
        isPlaying = false
    }

    func togglePlaying() {
        guard queue.current != nil else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
        } else if engine.duration == nil {
            // Nothing is loaded: the last track failed, or playing stopped.
            start()
        } else {
            engine.play()
            isPlaying = true
        }
    }

    func next() {
        if queue.next() { start() }
    }

    func previous() {
        if queue.previous(elapsed: elapsed) {
            start()
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        engine.seek(to: seconds)
        elapsed = seconds
    }

    func jump(to track: Track) {
        queue.jump(to: track)
        start()
    }

    func setShuffled(_ shuffled: Bool) {
        queue.setShuffled(shuffled)
    }

    /// Keeps looking at how the playing is going, until cancelled: the
    /// engines are asked how far they've got, not told.
    func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 400_000_000)
            tick()
        }
    }

    /// Looks at how the playing is going: called a few times a second.
    func tick() {
        guard isPlaying else { return }
        if engine.isFinished {
            if queue.finished() != nil {
                start()
            } else {
                isPlaying = false
                elapsed = 0
                engine.seek(to: 0)
                engine.pause()
            }
        } else {
            elapsed = engine.elapsed
        }
    }
}

#endif
