//
//  ChimePlayer.swift
//  CoreApps
//

#if Native || Apple

import ClocksCore
import Foundation
#if Native
import CSDL3
#else
import AVFoundation
#endif

/// Plays the chime over and over until stopped.
@MainActor
final class ChimePlayer {

    #if Native

    private var stream: OpaquePointer?

    /// One round of the chime, ready to queue.
    private let round = Chime.samples()

    private static var isStarted = false

    func start() {
        guard stream == nil else { return }
        if !Self.isStarted {
            guard SDL_InitSubSystem(SDL_INIT_AUDIO) else { return }
            Self.isStarted = true
        }
        var spec = SDL_AudioSpec(format: SDL_AUDIO_S16LE, channels: 1, freq: Int32(Chime.sampleRate))
        // The default playback device, which a macro names in C.
        guard let opened = SDL_OpenAudioDeviceStream(0xFFFF_FFFF, &spec, nil, nil) else { return }
        stream = opened
        refill()
        SDL_ResumeAudioStreamDevice(opened)
    }

    /// Keeps a round or two queued: called a few times a second.
    func refill() {
        guard let stream else { return }
        let bytes = round.count * 2
        while SDL_GetAudioStreamQueued(stream) < Int32(bytes) {
            round.withUnsafeBytes { buffer in
                _ = SDL_PutAudioStreamData(stream, buffer.baseAddress, Int32(bytes))
            }
        }
    }

    func stop() {
        if let stream { SDL_DestroyAudioStream(stream) }
        stream = nil
    }

    #else

    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player = try? AVAudioPlayer(data: Data(Chime.wav()))
        player?.numberOfLoops = -1
        player?.play()
    }

    func refill() { }

    func stop() {
        player?.stop()
        player = nil
    }

    #endif
}

#endif
