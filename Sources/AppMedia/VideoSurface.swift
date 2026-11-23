//
//  VideoSurface.swift
//  CoreApps
//

import AppUI

#if Native

/// A player's picture, fitted inside the space it's offered, on black.
/// The frames are GStreamer's, published to the player's surface from its
/// streaming thread and shown by Cacao's compositor.
public struct VideoSurface: View {

    let player: MediaPlayer

    public init(_ player: MediaPlayer) {
        self.player = player
    }

    public var body: some View {
        ZStack {
            Color.black
            if player.videoSize.width > 0, player.videoSize.height > 0 {
                ExternalSurfaceView(player.surface)
                    .aspectRatio(
                        CGSize(width: player.videoSize.width, height: player.videoSize.height),
                        contentMode: .fit
                    )
            }
        }
    }
}

#elseif Apple

import AVFoundation

/// A player's picture, fitted inside the space it's offered, on black, in
/// an `AVPlayerLayer`. The controls are the app's own.
public struct VideoSurface: View {

    let player: MediaPlayer

    public init(_ player: MediaPlayer) {
        self.player = player
    }

    public var body: some View {
        ZStack {
            Color.black
            PlayerLayerView(player: player.avPlayer)
        }
    }
}

#if os(iOS)

import UIKit

private struct PlayerLayerView: UIViewRepresentable {

    let player: AVPlayer?

    func makeUIView(context: Context) -> LayerView {
        LayerView()
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.playerLayer.player = player
    }

    final class LayerView: UIView {

        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer {
            let layer = layer as! AVPlayerLayer
            layer.videoGravity = .resizeAspect
            return layer
        }
    }
}

#else

import AppKit

private struct PlayerLayerView: NSViewRepresentable {

    let player: AVPlayer?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        view.layer = layer
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view.layer as? AVPlayerLayer)?.player = player
    }
}

#endif

#else

/// A player's picture, which the host decodes and shows: AppRuntime's
/// `VideoPlayer`, with the app's own controls rather than the platform's.
public struct VideoSurface: View {

    let player: MediaPlayer

    public init(_ player: MediaPlayer) {
        self.player = player
    }

    public var body: some View {
        VideoPlayer(player, scaling: .fit, controls: .none)
    }
}

#endif
