//
//  GStreamerEngine.swift
//  CoreApps
//

#if Native

import Cacao
import Foundation

/// Plays a source through a GStreamer `playbin`, which finds its demuxer
/// and decoders, keeps sound and picture in time and plays the sound
/// through the system's sound server.
///
/// Its pictures go to an `appsink` as RGBA with square pixels. The sink
/// calls back on GStreamer's streaming thread as each frame comes due,
/// and the frame is published from there to the player's
/// `ExternalSurface`, which the compositor shows on the main thread: no
/// frame waits for the main loop, and nothing on the main thread waits
/// for GStreamer. The bus is read on the main thread when the player
/// polls, so no GLib main loop runs.
@MainActor
final class GStreamerEngine: PlaybackEngine {

    typealias Pointer = UnsafeMutableRawPointer

    private let surface: ExternalSurface

    // Read by `deinit`, which isn't on the main thread's actor; nothing
    // else touches them off it.
    nonisolated(unsafe) private var pipeline: Pointer?

    nonisolated(unsafe) private var bus: Pointer?

    /// What the app sink's callbacks publish to, kept alive by the sink.
    private var frames: FrameSink?

    /// Waiting for the pipeline to reach paused the first time.
    private var isLoading = false

    /// A seek is settling: the position read meanwhile is stale.
    private var isSeeking = false

    private var wantsPlaying = false

    private var isBuffering = false

    private var volume: Float = 1

    private var isMuted = false

    private var lastSize = MediaSize.zero

    init(surface: ExternalSurface) {
        self.surface = surface
    }

    deinit {
        guard let gst = GStreamer.shared else { return }
        if let pipeline {
            _ = gst.elementSetState(pipeline, GStreamer.null)
            gst.objectUnref(pipeline)
        }
        if let bus { gst.objectUnref(bus) }
    }

    // MARK: Loading

    func load(_ source: MediaSource) throws {
        unload()
        guard let gst = GStreamer.shared else {
            throw MediaError(.unavailable, message: "GStreamer isn't installed")
        }
        let uri: String
        switch source {
        case .url(let url):
            uri = url
        case .file(let path):
            guard FileManager.default.fileExists(atPath: path) else {
                throw MediaError(.notFound, message: "There's no file at \(path)")
            }
            let absolute = path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
            guard let made = gst.filenameToURI(absolute, nil) else {
                throw MediaError(.notFound, message: "\(path) can't be named as a URI")
            }
            uri = String(cString: made)
            gst.free(made)
        }
        guard let pipeline = gst.elementFactoryMake("playbin", nil) else {
            throw MediaError(.unavailable, message: "GStreamer has no playbin: install its base plugins")
        }
        guard let sink = gst.elementFactoryMake("appsink", nil) else {
            gst.objectUnref(pipeline)
            throw MediaError(.unavailable, message: "GStreamer has no appsink: install its base plugins")
        }
        // RGBA, as the surface takes it, in square pixels so the picture's
        // size is its shape.
        if let caps = gst.capsFromString("video/x-raw,format=RGBA,pixel-aspect-ratio=1/1") {
            gst.appSinkSetCaps(sink, caps)
            gst.miniObjectUnref(caps)
        }
        // Only the newest frame matters: one waiting is enough.
        gst.set(sink, "max-buffers", uint: 2)
        gst.set(sink, "drop", bool: true)
        let frames = FrameSink(gst: gst, surface: surface)
        frames.attach(to: sink)
        self.frames = frames
        // The playbin takes the sink's reference.
        gst.set(pipeline, "video-sink", object: sink)
        gst.set(pipeline, "uri", string: uri)
        gst.set(pipeline, "volume", double: Double(volume))
        gst.set(pipeline, "mute", bool: isMuted)
        self.pipeline = pipeline
        self.bus = gst.elementGetBus(pipeline)
        isLoading = true
        if gst.elementSetState(pipeline, GStreamer.paused) == GStreamer.stateChangeFailure {
            unload()
            throw MediaError(.unsupportedFormat, message: "GStreamer can't open \(uri)")
        }
    }

    func unload() {
        guard let gst = GStreamer.shared else { return }
        if let pipeline {
            _ = gst.elementSetState(pipeline, GStreamer.null)
            gst.objectUnref(pipeline)
        }
        if let bus { gst.objectUnref(bus) }
        pipeline = nil
        bus = nil
        frames = nil
        isLoading = false
        isSeeking = false
        wantsPlaying = false
        isBuffering = false
        lastSize = .zero
    }

    // MARK: Playing

    func play() {
        wantsPlaying = true
        guard let gst = GStreamer.shared, let pipeline, !isBuffering else { return }
        _ = gst.elementSetState(pipeline, GStreamer.playing)
    }

    func pause() {
        wantsPlaying = false
        guard let gst = GStreamer.shared, let pipeline else { return }
        _ = gst.elementSetState(pipeline, GStreamer.paused)
    }

    func seek(to seconds: Double, accurate: Bool) {
        guard let gst = GStreamer.shared, let pipeline else { return }
        let flags = GStreamer.seekFlush | (accurate ? GStreamer.seekAccurate : GStreamer.seekKeyUnit)
        if gst.elementSeekSimple(pipeline, GStreamer.formatTime, flags, Int64(seconds * 1_000_000_000)) != 0 {
            isSeeking = true
        }
    }

    func setVolume(_ volume: Float) {
        self.volume = volume
        guard let gst = GStreamer.shared, let pipeline else { return }
        // The playbin's volume is linear, 1 being the source's own.
        gst.set(pipeline, "volume", double: Double(volume))
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        guard let gst = GStreamer.shared, let pipeline else { return }
        gst.set(pipeline, "mute", bool: muted)
    }

    // MARK: Following

    func position() -> Double? {
        guard let gst = GStreamer.shared, let pipeline, !isSeeking else { return nil }
        var nanoseconds: Int64 = 0
        guard gst.elementQueryPosition(pipeline, GStreamer.formatTime, &nanoseconds) != 0, nanoseconds >= 0 else {
            return nil
        }
        return Double(nanoseconds) / 1_000_000_000
    }

    private func duration() -> Double? {
        guard let gst = GStreamer.shared, let pipeline else { return nil }
        var nanoseconds: Int64 = 0
        guard gst.elementQueryDuration(pipeline, GStreamer.formatTime, &nanoseconds) != 0, nanoseconds > 0 else {
            return nil
        }
        return Double(nanoseconds) / 1_000_000_000
    }

    func poll() -> [PlaybackEvent] {
        guard let gst = GStreamer.shared, let pipeline, let bus else { return [] }
        var events: [PlaybackEvent] = []
        // One mask for every kind the engine follows: popping by one kind
        // would throw away the others ahead of it.
        let kinds = GStreamer.messageError | GStreamer.messageEOS | GStreamer.messageAsyncDone
            | GStreamer.messageDurationChanged | GStreamer.messageBuffering
        while self.pipeline != nil, let message = gst.busPopFiltered(bus, kinds) {
            defer { gst.miniObjectUnref(message) }
            switch gst.type(of: message) {
            case GStreamer.messageError:
                let text = gst.errorText(message)
                unload()
                return events + [.failed(MediaError(.unsupportedFormat, message: text))]
            case GStreamer.messageAsyncDone:
                isSeeking = false
                guard isLoading else { continue }
                isLoading = false
                let size = frames?.size ?? .zero
                lastSize = size
                events.append(.ready(.init(
                    duration: duration(),
                    videoSize: size,
                    hasVideo: gst.int(pipeline, "n-video") > 0,
                    hasAudio: gst.int(pipeline, "n-audio") > 0
                )))
                if wantsPlaying { play() }
            case GStreamer.messageDurationChanged:
                events.append(.duration(duration()))
            case GStreamer.messageBuffering:
                // A stream fills its buffer paused, then goes on.
                var percent: Int32 = 100
                gst.messageParseBuffering(message, &percent)
                let waiting = percent < 100
                guard waiting != isBuffering else { continue }
                isBuffering = waiting
                events.append(.buffering(waiting))
                if wantsPlaying {
                    _ = gst.elementSetState(pipeline, waiting ? GStreamer.paused : GStreamer.playing)
                }
            case GStreamer.messageEOS:
                wantsPlaying = false
                _ = gst.elementSetState(pipeline, GStreamer.paused)
                events.append(.ended)
            default:
                break
            }
        }
        if let size = frames?.size, size != lastSize, size != .zero {
            lastSize = size
            events.append(.videoSize(size))
        }
        return events
    }
}

/// What the app sink calls on GStreamer's streaming thread: it takes each
/// frame as it comes due and publishes its pixels to the surface. Its
/// size is read on the main thread.
final class FrameSink: @unchecked Sendable {

    private let gst: GStreamer

    private let surface: ExternalSurface

    private let lock = NSLock()

    private var latestSize = MediaSize.zero

    init(gst: GStreamer, surface: ExternalSurface) {
        self.gst = gst
        self.surface = surface
    }

    /// The size of the last frame published.
    var size: MediaSize {
        lock.lock()
        defer { lock.unlock() }
        return latestSize
    }

    /// Sets the sink's callbacks to this, which the sink keeps until it
    /// goes.
    func attach(to sink: UnsafeMutableRawPointer) {
        // GstAppSinkCallbacks: eos, new_preroll, new_sample, then fields
        // newer GStreamers added and padding, all left empty.
        let pointerSize = MemoryLayout<UnsafeRawPointer>.size
        let callbacks = UnsafeMutableRawPointer.allocate(byteCount: 16 * pointerSize, alignment: pointerSize)
        callbacks.initializeMemory(as: UInt8.self, repeating: 0, count: 16 * pointerSize)
        defer { callbacks.deallocate() }
        typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Int32
        let preroll: Callback = { sink, data in
            guard let sink, let data else { return GStreamer.flowOK }
            let frames = Unmanaged<FrameSink>.fromOpaque(data).takeUnretainedValue()
            frames.publish(frames.gst.appSinkPullPreroll(sink))
            return GStreamer.flowOK
        }
        let sample: Callback = { sink, data in
            guard let sink, let data else { return GStreamer.flowOK }
            let frames = Unmanaged<FrameSink>.fromOpaque(data).takeUnretainedValue()
            frames.publish(frames.gst.appSinkPullSample(sink))
            return GStreamer.flowOK
        }
        callbacks.storeBytes(of: preroll, toByteOffset: 1 * pointerSize, as: Callback.self)
        callbacks.storeBytes(of: sample, toByteOffset: 2 * pointerSize, as: Callback.self)
        let release: @convention(c) (UnsafeMutableRawPointer?) -> Void = { data in
            guard let data else { return }
            Unmanaged<FrameSink>.fromOpaque(data).release()
        }
        gst.appSinkSetCallbacks(sink, callbacks, Unmanaged.passRetained(self).toOpaque(), release)
    }

    /// Publishes a sample's picture, and lets it go.
    private func publish(_ sample: UnsafeMutableRawPointer?) {
        guard let sample else { return }
        defer { gst.miniObjectUnref(sample) }
        guard let caps = gst.sampleGetCaps(sample),
              let structure = gst.capsGetStructure(caps, 0),
              let buffer = gst.sampleGetBuffer(sample) else { return }
        var width: Int32 = 0, height: Int32 = 0
        guard gst.structureGetInt(structure, "width", &width) != 0,
              gst.structureGetInt(structure, "height", &height) != 0,
              width > 0, height > 0 else { return }
        // GstMapInfo: memory, flags, data, size, then room to spare.
        let pointerSize = MemoryLayout<UnsafeRawPointer>.size
        let info = UnsafeMutableRawPointer.allocate(byteCount: 32 * pointerSize, alignment: pointerSize)
        info.initializeMemory(as: UInt8.self, repeating: 0, count: 32 * pointerSize)
        defer { info.deallocate() }
        guard gst.bufferMap(buffer, info, GStreamer.mapRead) != 0 else { return }
        defer { gst.bufferUnmap(buffer, info) }
        guard let data = info.load(fromByteOffset: 2 * pointerSize, as: UnsafeRawPointer?.self) else { return }
        let count = info.load(fromByteOffset: 3 * pointerSize, as: Int.self)
        let rows = Int(height)
        // RGBA rows are 4-byte aligned already; take the stride from the
        // buffer's size all the same, in case a decoder padded them.
        let bytesPerRow = max(Int(width) * 4, count / rows)
        guard count >= bytesPerRow * rows else { return }
        surface.publish(
            pixels: UnsafeRawBufferPointer(start: data, count: count),
            width: Int(width),
            height: rows,
            bytesPerRow: bytesPerRow,
            format: .rgba,
            rowOrder: .topFirst,
            isOpaque: true
        )
        lock.lock()
        latestSize = MediaSize(width: Int(width), height: rows)
        lock.unlock()
    }
}

#endif
