//
//  PlayerView.swift
//  CoreApps
//

import AppMedia
import AppUI
import CoreAppsUI
import VideosCore

/// A video playing: its picture, and below it the scrubber, the transport
/// and the volume. Full screen shows the picture alone, with the controls
/// over it at a tap.
struct PlayerView: View {

    let video: Video

    let player: MediaPlayer

    let close: () -> Void

    @State private var isFullScreen = false

    var body: some View {
        VStack(spacing: 16) {
            VideoSurface(player)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, maxHeight: 320)
                .onTapGesture(count: 2) { isFullScreen = true }
                .accessibilityIdentifier("picture")
            VStack(spacing: 16) {
                ScrubberBar(player: player)
                TransportBar(player: player)
                VolumeBar(player: player)
                PlayerStatus(player: player)
            }
            .padding(.horizontal, Metrics.screenPadding)
            Spacer()
        }
        .navigationTitle(video.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Videos", action: close)
                    .accessibilityIdentifier("library")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isFullScreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityIdentifier("full-screen")
            }
        }
        .fullScreen(isPresented: $isFullScreen) {
            FullScreenPlayer(player: player) { isFullScreen = false }
        }
    }
}

/// The picture filling the screen. A tap shows or hides the controls over
/// it.
struct FullScreenPlayer: View {

    let player: MediaPlayer

    let done: () -> Void

    @State private var showsControls = true

    var body: some View {
        ZStack {
            VideoSurface(player)
                .onTapGesture { showsControls.toggle() }
                .accessibilityIdentifier("full-screen-picture")
            if showsControls {
                VStack {
                    HStack {
                        Button(action: done) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                        }
                        .accessibilityIdentifier("exit-full-screen")
                        Spacer()
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        ScrubberBar(player: player)
                        HStack {
                            TransportBar(player: player)
                            Spacer()
                        }
                        VolumeBar(player: player)
                    }
                    .padding(Metrics.screenPadding)
                    .background(Color.black.opacity(0.6))
                }
                .foregroundStyle(Color.white)
                .padding(8)
            }
        }
        .background(Color.black)
        .onAppear { WindowFullScreen.set(true) }
        .onDisappear { WindowFullScreen.set(false) }
    }
}

extension View {

    /// Covers the window with `content` while `isPresented`: a full-screen
    /// cover where the flavor has one, and on a Mac, which hasn't, a sheet
    /// in a window taken full screen.
    @ViewBuilder
    func fullScreen<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if Apple && os(macOS)
        sheet(isPresented: isPresented, content: content)
        #else
        fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }
}
