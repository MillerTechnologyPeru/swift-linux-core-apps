//
//  VideosApp.swift
//  CoreApps
//

import AppMedia
import AppUI
import CoreAppsUI
import VideosCore

/// The video player.
public struct VideosApp: App {

    public init() { }

    public var body: some Scene {
        #if Native || (Apple && os(macOS))
        // On a desktop the window opens at a phone's size.
        WindowGroup("Videos") {
            VideosView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            VideosView()
        }
        #endif
    }
}

/// The library, or the video playing.
public struct VideosView: View {

    /// The one player, kept while videos come and go.
    @State private var player = MediaPlayer()

    @State private var playing: Video?

    @State private var recent: [Video] = []

    public init() { }

    public var body: some View {
        // A stack for each screen: AppRuntime's guest frontend loses a
        // stack's own state when its root view is swapped for another.
        Group {
            if let playing {
                NavigationStack {
                    PlayerView(video: playing, player: player) {
                        player.pause()
                        self.playing = nil
                    }
                }
            } else {
                NavigationStack {
                    LibraryView(recent: recent, open: open)
                }
            }
        }
        .onAppear(perform: openArgument)
    }

    /// Loads a video and plays it from its start.
    private func open(_ video: Video) {
        recent.removeAll { $0.source == video.source }
        recent.insert(video, at: 0)
        playing = video
        player.load(video.source)
        player.play()
    }

    /// A program opens the file or address it's given:
    /// `videos ~/Videos/Holiday.mkv`.
    private func openArgument() {
        #if Native || Apple
        guard playing == nil, CommandLine.arguments.count > 1,
              let location = VideoLocation(CommandLine.arguments[1]),
              let video = Video(location) else { return }
        open(video)
        #endif
    }
}

#if !Native && !Apple

/// A guest's entry point: the host calls it once after loading the app.
@_expose(wasm, "rt_main")
@c(rt_main)
public func videosMain() -> rt_status {
    Runtime.main { VideosApp.run() }
}

#endif
