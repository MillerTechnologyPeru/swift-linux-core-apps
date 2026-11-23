//
//  AVFoundationEngine.swift
//  CoreApps
//

#if Apple

import AVFoundation
import Foundation

/// Plays a source through `AVPlayer`, whose picture `VideoSurface` shows
/// in an `AVPlayerLayer`.
@MainActor
final class AVFoundationEngine: PlaybackEngine {

    /// The player, for the view that shows its picture.
    let player = AVPlayer()

    private var isLoading = false

    private var hasEnded = false

    private var wasBuffering = false

    private var lastSize = MediaSize.zero

    private var lastDuration: Double?

    private var endObserver: NSObjectProtocol?

    init() {
        #if os(iOS)
        // Sound plays with the ring switch off, as a video's does.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        #endif
    }

    func load(_ source: MediaSource) throws {
        unload()
        let url: URL
        switch source {
        case .url(let address):
            guard let made = URL(string: address) else {
                throw MediaError(.notFound, message: "\(address) isn't an address")
            }
            url = made
        case .file(let path):
            guard FileManager.default.fileExists(atPath: path) else {
                throw MediaError(.notFound, message: "There's no file at \(path)")
            }
            url = URL(fileURLWithPath: path)
        }
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hasEnded = true }
        }
        player.replaceCurrentItem(with: item)
        isLoading = true
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func unload() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
        isLoading = false
        hasEnded = false
        wasBuffering = false
        lastSize = .zero
        lastDuration = nil
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double, accurate: Bool) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        let tolerance = accurate ? CMTime.zero : CMTime.positiveInfinity
        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    func setVolume(_ volume: Float) {
        player.volume = volume
    }

    func setMuted(_ muted: Bool) {
        player.isMuted = muted
    }

    func position() -> Double? {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : nil
    }

    private var duration: Double? {
        guard let seconds = player.currentItem?.duration.seconds, seconds.isFinite, seconds > 0 else { return nil }
        return seconds
    }

    private var size: MediaSize {
        guard let size = player.currentItem?.presentationSize else { return .zero }
        return MediaSize(width: Int(size.width), height: Int(size.height))
    }

    func poll() -> [PlaybackEvent] {
        guard let item = player.currentItem else { return [] }
        var events: [PlaybackEvent] = []
        switch item.status {
        case .failed:
            let message = item.error?.localizedDescription ?? "This can't be played"
            unload()
            return [.failed(MediaError(.unsupportedFormat, message: message))]
        case .readyToPlay where isLoading:
            isLoading = false
            lastSize = size
            lastDuration = duration
            let tracks = item.tracks.compactMap { $0.assetTrack?.mediaType }
            events.append(.ready(.init(
                duration: lastDuration,
                videoSize: lastSize,
                hasVideo: tracks.contains(.video) || lastSize != .zero,
                hasAudio: tracks.contains(.audio)
            )))
        default:
            break
        }
        guard !isLoading else { return events }
        if size != lastSize {
            lastSize = size
            events.append(.videoSize(size))
        }
        if duration != lastDuration {
            lastDuration = duration
            events.append(.duration(duration))
        }
        let buffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        if buffering != wasBuffering {
            wasBuffering = buffering
            events.append(.buffering(buffering))
        }
        if hasEnded {
            hasEnded = false
            events.append(.ended)
        }
        return events
    }
}

#endif
