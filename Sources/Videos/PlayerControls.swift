//
//  PlayerControls.swift
//  CoreApps
//

import AppMedia
import AppUI
import CoreAppsUI
import VideosCore

/// How far the skip buttons go, in seconds.
let skipInterval: Double = 10

/// The scrubber, with the time gone on its left and the time left on its
/// right.
struct ScrubberBar: View {

    let player: MediaPlayer

    var body: some View {
        let clock = PlaybackClock(position: player.currentTime, duration: player.duration)
        VStack(spacing: 2) {
            Slider(value: position(clock), in: clock.range)
                .disabled(!clock.isSeekable)
                .accessibilityIdentifier("scrubber")
            HStack {
                Text(clock.elapsedText)
                    .accessibilityIdentifier("elapsed")
                Spacer()
                Text(clock.remainingText)
                    .accessibilityIdentifier("remaining")
            }
            .font(.caption)
        }
    }

    /// The slider's value: where playing is, and where to move it to.
    private func position(_ clock: PlaybackClock) -> Binding<Double> {
        Binding(
            get: { clock.clampedPosition },
            set: { player.currentTime = PlaybackClock.clamp($0, to: player.duration) }
        )
    }
}

/// Back, play or pause, and forward.
struct TransportBar: View {

    let player: MediaPlayer

    var body: some View {
        let clock = PlaybackClock(position: player.currentTime, duration: player.duration)
        HStack(spacing: 32) {
            Button {
                player.currentTime = clock.skipped(by: -skipInterval)
            } label: {
                Image(systemName: "backward.fill")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            }
            .disabled(!clock.isSeekable)
            .accessibilityIdentifier("back")
            Button {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 64, height: 64)
            }
            .disabled(player.status != .ready)
            .accessibilityIdentifier("play")
            Button {
                player.currentTime = clock.skipped(by: skipInterval)
            } label: {
                Image(systemName: "forward.fill")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            }
            .disabled(!clock.isSeekable)
            .accessibilityIdentifier("forward")
        }
    }
}

/// The speaker, which mutes, and the volume.
struct VolumeBar: View {

    let player: MediaPlayer

    var body: some View {
        let level = VolumeLevel(volume: player.volume, isMuted: player.isMuted)
        HStack(spacing: 8) {
            Button {
                apply(level.toggled())
            } label: {
                Image(systemName: level.symbolName)
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            }
            .accessibilityIdentifier("mute")
            Slider(value: Binding(
                get: { Double(level.isMuted ? 0 : level.volume) },
                set: { apply(VolumeLevel(volume: Float($0))) }
            ), in: 0...1)
            .accessibilityIdentifier("volume")
        }
    }

    private func apply(_ level: VolumeLevel) {
        player.volume = level.volume
        player.isMuted = level.isMuted
    }
}

/// What the player says while it isn't simply playing: loading, waiting
/// for data, or why it couldn't play.
struct PlayerStatus: View {

    let player: MediaPlayer

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("status")
        }
    }

    private var message: String? {
        switch player.status {
        case .loading:
            return "Loading…"
        case .failed:
            let reason = player.error?.message ?? ""
            return reason.isEmpty ? "This video can't be played." : "This video can't be played: \(reason)"
        case .ready where player.isBuffering:
            return "Waiting for the video…"
        case .ready where !player.hasVideo:
            return "This has sound and no picture."
        default:
            return nil
        }
    }
}
