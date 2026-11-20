//
//  NowPlayingView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation
import MusicCore

/// The track playing, in a bar over the library: tapped, it opens the
/// player.
struct MiniPlayer: View {

    let open: () -> Void

    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: model.duration > 0 ? min(1, model.elapsed / model.duration) : 0)
            HStack(spacing: 8) {
                Button(action: open) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.queue.current?.title ?? "")
                            .lineLimit(1)
                        Text(model.queue.current?.artist ?? "")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: Metrics.minimumTarget, alignment: .leading)
                    // The whole strip opens the player, not only its words.
                    .contentShape(Rectangle())
                }
                .plainButton()
                Button {
                    model.togglePlaying()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                }
                Button {
                    model.next()
                } label: {
                    Image(systemName: "arrow.forward")
                        .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                }
                .disabled(!model.queue.hasNext)
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
        }
        .background(Color.secondary.opacity(0.12))
    }
}

/// The player: the track, how far it's got, and what comes next.
struct NowPlayingView: View {

    let done: () -> Void

    @EnvironmentObject private var model: PlayerModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(model.queue.current?.title ?? "Nothing Playing")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.secondary)
                                .multilineTextAlignment(.center)
                        }
                        VStack(spacing: 2) {
                            Slider(value: position, in: 0...max(1, model.duration))
                            HStack {
                                Text(Library.time(model.elapsed))
                                Spacer()
                                Text(Library.time(model.duration))
                            }
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        }
                        HStack(spacing: 24) {
                            Button {
                                model.previous()
                            } label: {
                                Image(systemName: "arrow.backward")
                                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                            }
                            Button {
                                model.togglePlaying()
                            } label: {
                                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .frame(width: 64, height: 64)
                            }
                            Button {
                                model.next()
                            } label: {
                                Image(systemName: "arrow.forward")
                                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                            }
                            .disabled(!model.queue.hasNext)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                Section {
                    Toggle("Shuffle", isOn: Binding(
                        get: { model.queue.isShuffled },
                        set: { model.setShuffled($0) }
                    ))
                    Picker("Repeat", selection: $model.queue.repeatMode) {
                        Text("Off").tag(RepeatMode.off)
                        Text("All").tag(RepeatMode.all)
                        Text("One").tag(RepeatMode.one)
                    }
                }
                let upcoming = model.queue.upcoming
                if !upcoming.isEmpty {
                    Section("Up Next") {
                        ForEach(upcoming.prefix(50)) { track in
                            TrackRow(track: track, detail: track.artist) {
                                model.jump(to: track)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Now Playing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }

    private var subtitle: String {
        guard let track = model.queue.current else { return "" }
        return "\(track.artist) · \(track.album)"
    }

    /// The slider's value: where playing is, and where to move it to.
    private var position: Binding<Double> {
        Binding(get: { min(model.elapsed, max(1, model.duration)) }, set: { model.seek(to: $0) })
    }
}

#endif
