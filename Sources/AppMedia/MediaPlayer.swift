//
//  MediaPlayer.swift
//  CoreApps
//

#if Native || Apple

import Foundation
import Observation
#if Native
import Cacao
#else
import AVFoundation
#endif

/// Plays a video or a song, as `DynamicMedia`'s `MediaPlayer` does for a
/// guest: the part of it the apps use, over the platform's engine. Show
/// its picture with `VideoSurface(player)`.
///
/// It's observable: a view that reads `isPlaying` or `currentTime` is
/// updated when they change, a few times a second while playing.
@MainActor
@Observable
public final class MediaPlayer {

    // MARK: State

    public private(set) var status: MediaStatus = .empty

    /// Sound or picture is advancing.
    public private(set) var isPlaying = false

    /// It would be playing, and is waiting for data.
    public private(set) var isBuffering = false

    /// Seconds into the source. Set it to seek.
    public var currentTime: Double {
        get { position }
        set { seek(to: newValue) }
    }

    /// Seconds; `nil` until it's known, and for a live stream.
    public private(set) var duration: Double?

    /// The picture's own size; zero for sound alone.
    public private(set) var videoSize: MediaSize = .zero

    public private(set) var hasVideo = false

    public private(set) var hasAudio = false

    /// 0 to 1.
    public var volume: Float {
        get { volumeLevel }
        set {
            volumeLevel = min(max(newValue.isFinite ? newValue : 0, 0), 1)
            engine?.setVolume(volumeLevel)
        }
    }

    public var isMuted: Bool {
        get { muted }
        set {
            muted = newValue
            engine?.setMuted(newValue)
        }
    }

    /// Why the source didn't play, when `status` is `.failed`.
    public private(set) var error: MediaError?

    /// Called when playing reaches the end.
    @ObservationIgnored public var onEnd: (() -> Void)?

    /// Called when the source can't be played.
    @ObservationIgnored public var onFailure: ((MediaError) -> Void)?

    // MARK: Engine

    private var position: Double = 0

    private var volumeLevel: Float = 1

    private var muted = false

    @ObservationIgnored private var engine: PlaybackEngine?

    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// Asked to play before the source was ready.
    @ObservationIgnored private var wantsToPlay = false

    #if Native
    /// Where the picture is published, from GStreamer's thread.
    @ObservationIgnored public let surface = ExternalSurface()
    #endif

    #if Apple
    /// AVFoundation's player, for the layer that shows its picture; `nil`
    /// until something is loaded.
    var avPlayer: AVPlayer? {
        _ = status
        return (engine as? AVFoundationEngine)?.player
    }
    #endif

    // The engine stops its pipeline when it goes, and the ticker holds the
    // player weakly, so nothing more is needed to let a player go.
    public init() { }

    /// The engine, made the first time it's needed.
    private func makeEngine() -> PlaybackEngine {
        if let engine { return engine }
        #if Native
        let engine = GStreamerEngine(surface: surface)
        #else
        let engine = AVFoundationEngine()
        #endif
        engine.setVolume(volume)
        engine.setMuted(isMuted)
        self.engine = engine
        return engine
    }

    // MARK: Playing

    /// Starts loading a source, paused at its start. It replaces the one
    /// before.
    public func load(_ source: MediaSource) {
        reset()
        status = .loading
        let engine = makeEngine()
        do {
            try engine.load(source)
        } catch {
            fail(error)
            return
        }
        startTicking()
    }

    /// Lets go of the source.
    public func unload() {
        engine?.unload()
        reset()
    }

    /// Before the source is ready, it's remembered: playback starts when
    /// it can.
    public func play() {
        guard status != .empty, status != .failed, let engine else { return }
        wantsToPlay = true
        guard status == .ready else { return }
        // At the end, playing starts again from the start.
        if let duration, position >= duration - 0.05 {
            engine.seek(to: 0, accurate: true)
            position = 0
        }
        engine.play()
        isPlaying = true
    }

    public func pause() {
        wantsToPlay = false
        engine?.pause()
        isPlaying = false
        isBuffering = false
    }

    /// Moves playback to `time` seconds. While a scrubber is dragged the
    /// engine may land on the nearest key frame; it's exact once it stops.
    public func seek(to time: Double) {
        guard let engine, status == .ready else { return }
        var time = max(time, 0)
        if let duration { time = min(time, duration) }
        position = time
        engine.seek(to: time, accurate: true)
    }

    // MARK: Following the engine

    private func reset() {
        ticker?.cancel()
        ticker = nil
        status = .empty
        isPlaying = false
        isBuffering = false
        position = 0
        duration = nil
        videoSize = .zero
        hasVideo = false
        hasAudio = false
        error = nil
        wantsToPlay = false
    }

    private func fail(_ failure: Error) {
        let error = failure as? MediaError ?? MediaError(.unknown, message: "\(failure)")
        ticker?.cancel()
        ticker = nil
        status = .failed
        isPlaying = false
        isBuffering = false
        self.error = error
        onFailure?(error)
    }

    /// Reads where the engine is, ten times a second, while there's a
    /// source.
    private func startTicking() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func tick() {
        guard let engine else { return }
        for event in engine.poll() {
            switch event {
            case .ready(let info):
                duration = info.duration
                videoSize = info.videoSize
                hasVideo = info.hasVideo
                hasAudio = info.hasAudio
                status = .ready
                if wantsToPlay {
                    engine.play()
                    isPlaying = true
                }
            case .videoSize(let size):
                if size != videoSize { videoSize = size }
            case .duration(let seconds):
                if seconds != duration { duration = seconds }
            case .buffering(let waiting):
                if waiting != isBuffering { isBuffering = waiting }
            case .ended:
                isPlaying = false
                wantsToPlay = false
                if let duration { position = duration }
                onEnd?()
            case .failed(let error):
                fail(error)
                return
            }
        }
        if status == .ready, isPlaying, let now = engine.position(), abs(now - position) >= 0.05 {
            position = now
        }
    }
}

/// What a player's engine says has happened, when asked.
enum PlaybackEvent {

    struct Info {
        var duration: Double?
        var videoSize: MediaSize
        var hasVideo: Bool
        var hasAudio: Bool
    }

    /// The source can be played.
    case ready(Info)

    case videoSize(MediaSize)

    case duration(Double?)

    /// Whether it's waiting for data.
    case buffering(Bool)

    case ended

    case failed(MediaError)
}

/// What plays a source: GStreamer, or AVFoundation. It's called on the
/// main thread, and says what happened when the player polls it.
@MainActor
protocol PlaybackEngine: AnyObject {

    func load(_ source: MediaSource) throws

    func unload()

    func play()

    func pause()

    func seek(to seconds: Double, accurate: Bool)

    func setVolume(_ volume: Float)

    func setMuted(_ muted: Bool)

    /// Seconds into the source, where the engine knows.
    func position() -> Double?

    /// What happened since the last call.
    func poll() -> [PlaybackEvent]
}

#endif
