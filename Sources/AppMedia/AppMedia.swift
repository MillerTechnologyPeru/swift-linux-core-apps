//
//  AppMedia.swift
//  CoreApps
//

// Media playing, as the flavor being built has it, in AppRuntime's shape:
// a `MediaPlayer` the app loads, plays, pauses and seeks, and a
// `VideoSurface` that shows its picture. Apps import this module instead
// of a media framework, as they import `AppUI` instead of a toolkit.
//
// - A guest plays through AppRuntime's `DynamicMedia`: the host decodes
//   and shows the picture, and nothing of the media crosses to the guest.
// - A program on Cacao plays through GStreamer, opened at run time, its
//   pictures published from GStreamer's thread to an `ExternalSurface`.
// - A program on Apple's SwiftUI plays through AVFoundation.
//
// The programs' `MediaPlayer` has the part of `DynamicMedia`'s that the
// apps use, with the same names, so an app's code is the same in every
// flavor but for where its sources come from: a guest's files are
// `FilePath`s, a program's are paths.

#if !Native && !Apple

@_exported import DynamicMedia
@_exported import DynamicFiles

#else

/// What a player plays.
public enum MediaSource: Equatable, Sendable {

    /// `http` or `https`.
    case url(String)

    /// A file's path.
    case file(String)
}

/// Whether there's something to play.
public enum MediaStatus: Equatable, Sendable {

    /// Nothing loaded.
    case empty

    /// Loading what was given.
    case loading

    /// Ready to play.
    case ready

    /// It can't be played: see `MediaPlayer.error`.
    case failed
}

/// Why a source didn't play.
public struct MediaError: Error, Equatable, Sendable {

    public enum Code: Int32, Sendable {
        case unknown = 0
        case notFound = 1
        case unsupportedFormat = 2
        case network = 3
        case notPermitted = 4
        /// The data is damaged.
        case decoding = 5
        /// The system has no media stack to play with.
        case unavailable = 6
    }

    public var code: Code

    /// What the system said, for people to read.
    public var message: String

    public init(_ code: Code, message: String = "") {
        self.code = code
        self.message = message
    }
}

/// A picture's size in pixels.
public struct MediaSize: Equatable, Sendable {

    public var width: Int

    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public static let zero = MediaSize(width: 0, height: 0)
}

#endif
