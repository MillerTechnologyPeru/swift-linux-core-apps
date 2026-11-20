//
//  AudioEngine.swift
//  CoreApps
//

#if Native || Apple

import Foundation
import MusicCore
#if Native
import CSDL3
#else
import AVFoundation
#endif

/// Why a file doesn't play.
enum AudioFailure: Error {
    /// The file is of a kind that can't be played here yet.
    case unsupported(AudioFormat?)
    /// What the system said went wrong.
    case system(String)

    var message: String {
        switch self {
        case let .unsupported(format?): "\(format.name) files can't be played yet."
        case .unsupported(nil): "This file isn't music that can be played."
        case let .system(reason): reason
        }
    }
}

/// What plays one file at a time.
@MainActor
protocol AudioEngine: AnyObject {

    /// Readies a file to play from its start, stopping what was playing.
    func load(_ url: URL) throws

    func play()

    func pause()

    func seek(to seconds: Double)

    /// How far into the file playing has got, in seconds.
    var elapsed: Double { get }

    /// How long the file plays, where the engine knows.
    var duration: Double? { get }

    /// Whether the file has played to its end.
    var isFinished: Bool { get }
}

#if Native

/// Plays WAV files through SDL: the file's samples are read whole and
/// queued on a stream to the default device. The compressed formats wait
/// for decoders.
@MainActor
final class SDLAudioEngine: AudioEngine {

    private var stream: OpaquePointer?

    private var samples: UnsafeMutablePointer<UInt8>?

    private var length = 0

    /// Bytes of sound for each second.
    private var byteRate = 1

    /// Bytes for one sample of every channel, which seeks land on.
    private var frameSize = 1

    /// The byte of the file that the stream's queue began at.
    private var queuedFrom = 0

    private static var isStarted = false

    private static var lastError: String {
        String(cString: SDL_GetError())
    }

    func load(_ url: URL) throws {
        unload()
        let header = (try? FileHandle(forReadingFrom: url))?.readData(ofLength: 16) ?? Data()
        let format = AudioFormat(header: [UInt8](header))
        guard format == .wav else { throw AudioFailure.unsupported(format) }
        if !Self.isStarted {
            guard SDL_InitSubSystem(SDL_INIT_AUDIO) else { throw AudioFailure.system(Self.lastError) }
            Self.isStarted = true
        }
        var spec = SDL_AudioSpec()
        var buffer: UnsafeMutablePointer<UInt8>?
        var count: UInt32 = 0
        guard SDL_LoadWAV(url.path, &spec, &buffer, &count), let buffer else {
            throw AudioFailure.system(Self.lastError)
        }
        // The default playback device, which a macro names in C.
        guard let opened = SDL_OpenAudioDeviceStream(0xFFFF_FFFF, &spec, nil, nil) else {
            SDL_free(buffer)
            throw AudioFailure.system(Self.lastError)
        }
        stream = opened
        samples = buffer
        length = Int(count)
        // The low byte of a format is its bits for each sample.
        let bytesPerSample = max(1, Int(spec.format.rawValue & 0xFF) / 8)
        frameSize = max(1, bytesPerSample * Int(spec.channels))
        byteRate = max(1, frameSize * Int(spec.freq))
        queue(from: 0)
    }

    private func unload() {
        if let stream { SDL_DestroyAudioStream(stream) }
        if let samples { SDL_free(samples) }
        stream = nil
        samples = nil
        length = 0
        queuedFrom = 0
    }

    /// Empties the stream and fills it with the file from a byte on.
    private func queue(from offset: Int) {
        guard let stream, let samples else { return }
        let start = min(max(0, offset - offset % frameSize), length)
        SDL_ClearAudioStream(stream)
        if start < length {
            SDL_PutAudioStreamData(stream, samples + start, Int32(length - start))
        }
        queuedFrom = start
    }

    /// The bytes of the file not yet handed to the device.
    private var remaining: Int {
        stream.map { Int(max(0, SDL_GetAudioStreamQueued($0))) } ?? 0
    }

    func play() {
        if let stream { SDL_ResumeAudioStreamDevice(stream) }
    }

    func pause() {
        if let stream { SDL_PauseAudioStreamDevice(stream) }
    }

    func seek(to seconds: Double) {
        queue(from: Int(max(0, seconds) * Double(byteRate)))
    }

    var elapsed: Double {
        guard stream != nil else { return 0 }
        return Double(max(0, length - remaining)) / Double(byteRate)
    }

    var duration: Double? {
        stream == nil ? nil : Double(length) / Double(byteRate)
    }

    var isFinished: Bool {
        stream != nil && remaining == 0
    }
}

#else

/// Plays what AVFoundation can, which is every format the library lists.
@MainActor
final class SystemAudioEngine: AudioEngine {

    private var player: AVAudioPlayer?

    /// Whether playing was asked for, to tell a pause from the end.
    private var wantsToPlay = false

    func load(_ url: URL) throws {
        player?.stop()
        wantsToPlay = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do {
            let loaded = try AVAudioPlayer(contentsOf: url)
            loaded.prepareToPlay()
            player = loaded
        } catch {
            player = nil
            throw AudioFailure.system(error.localizedDescription)
        }
    }

    func play() {
        wantsToPlay = true
        player?.play()
    }

    func pause() {
        wantsToPlay = false
        player?.pause()
    }

    func seek(to seconds: Double) {
        player?.currentTime = max(0, seconds)
    }

    var elapsed: Double {
        player?.currentTime ?? 0
    }

    var duration: Double? {
        player?.duration
    }

    var isFinished: Bool {
        // A player that stopped by itself has come to its end.
        guard let player else { return false }
        return wantsToPlay && !player.isPlaying
    }
}

#endif

#endif
