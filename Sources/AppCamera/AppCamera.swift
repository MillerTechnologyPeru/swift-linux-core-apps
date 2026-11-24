//
//  AppCamera.swift
//  CoreApps
//

// A camera, as the flavor being built has it, in AppRuntime's shape: a
// `Camera` the app turns on, zooms and takes photos and videos with, and a
// `CameraPreview` that shows what it sees. Apps import this module instead
// of a camera framework, as they import `AppUI` instead of a toolkit.
//
// - A guest's camera is AppRuntime's `DynamicCamera`: the host captures
//   and shows the preview, and writes each photo or video to a file the
//   app names. `Image(contentsOf:)` from `DynamicDrawing` shows a photo.
// - A program on Apple's SwiftUI has the `Camera` in AppleCamera.swift,
//   over an `AVCaptureSession`.
// - A program on Cacao has no camera yet: Linux capture, over PipeWire or
//   V4L2, isn't written, so its `Camera` says the device has none.
//
// The programs' `Camera` has the part of `DynamicCamera`'s that the apps
// use, with the same names. A capture's file is a `CaptureFile`: a guest's
// `FilePath`, and a program's path.

#if !Native && !Apple

@_exported import DynamicCamera
@_exported import DynamicDrawing
@_exported import DynamicFiles

/// Where a photo or video is written.
public typealias CaptureFile = FilePath

#else

/// Where a photo or video is written: a path.
public typealias CaptureFile = String

/// Which way a camera faces.
public enum CameraPosition: Int32, Sendable {
    case back = 1
    case front = 2
    case external = 4
}

/// What a camera is doing.
public enum CameraState: Int32, Sendable {
    case stopped = 0
    case starting = 1
    case running = 2
    case interrupted = 3
    case failed = 4
}

/// Whether a photo is taken with the flash.
public enum CameraFlashMode: Int32, Sendable {
    case off = 0
    case on = 1
    case auto = 2
}

/// Whether the app may use the camera, or the microphone.
public enum CameraAccess: Int32, Sendable {
    case notDetermined = 0
    case restricted = 1
    case denied = 2
    case authorized = 3
    /// This device has no camera, or no microphone.
    case unavailable = 5
}

/// Why a camera, or a capture, failed.
public enum CameraError: Int32, Error, Sendable {
    case unknown = 0
    case cancelled = 1
    case notAuthorized = 2
    case unavailable = 3
    case notRunning = 4
    case busy = 5
    case interrupted = 6
    case writeFailed = 7
}

/// How a preview fills its space.
public enum CameraScaling: Sendable {
    /// All of it, cropped.
    case fill
    /// All of the picture, with bars.
    case fit
}

/// A photo the camera took: a JPEG, upright, at the path asked for.
public struct CapturedPhoto: Equatable, Sendable {
    public var path: CaptureFile
    public var width: Int
    public var height: Int

    public init(path: CaptureFile, width: Int, height: Int) {
        self.path = path
        self.width = width
        self.height = height
    }
}

/// A video the camera recorded, at the path asked for.
public struct CapturedVideo: Equatable, Sendable {
    public var path: CaptureFile
    /// Seconds.
    public var duration: Double
    public var contentType: String

    public init(path: CaptureFile, duration: Double, contentType: String = "video/mp4") {
        self.path = path
        self.duration = duration
        self.contentType = contentType
    }
}

#endif
