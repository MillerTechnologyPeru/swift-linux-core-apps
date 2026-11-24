//
//  CacaoCamera.swift
//  CoreApps
//

#if Native

import AppUI
import Observation

/// A camera on Cacao: none yet. Linux capture (the camera portal and
/// PipeWire, or V4L2) isn't written, so this says the device has no camera,
/// and every capture fails with `unavailable`. It has `DynamicCamera`'s
/// names, so the app's code is the same as a guest's.
@MainActor
@Observable
public final class Camera {

    public static var positions: [CameraPosition] { [] }

    public static var access: CameraAccess { .unavailable }

    public static var microphoneAccess: CameraAccess { .unavailable }

    public static func requestAccess(completion: @escaping (CameraAccess) -> Void) {
        completion(.unavailable)
    }

    public static func requestMicrophoneAccess(completion: @escaping (CameraAccess) -> Void) {
        completion(.unavailable)
    }

    public private(set) var state: CameraState = .stopped

    public private(set) var position: CameraPosition = .back

    public var zoomFactor: Double = 1

    public var zoomRange: ClosedRange<Double> { 1...1 }

    public var hasFlash: Bool { false }

    public var flashMode: CameraFlashMode = .off

    public var isRecording: Bool { false }

    public var recordingDuration: Double { 0 }

    public private(set) var error: CameraError?

    @ObservationIgnored public var onRecordingFinished: ((CapturedVideo) -> Void)?

    public init() { }

    public func start(_ position: CameraPosition = .back) {
        self.position = position
        state = .failed
        error = .unavailable
    }

    public func stop() {
        state = .stopped
    }

    public func capturePhoto(to file: CaptureFile, completion: @escaping (Result<CapturedPhoto, CameraError>) -> Void) {
        completion(.failure(.unavailable))
    }

    public func startRecording(to file: CaptureFile, audio: Bool = true, completion: @escaping (Result<Void, CameraError>) -> Void) {
        completion(.failure(.unavailable))
    }

    public func stopRecording(completion: @escaping (Result<CapturedVideo, CameraError>) -> Void) {
        completion(.failure(.notRunning))
    }
}

/// What a camera sees: on Cacao, nothing yet.
public struct CameraPreview: View {

    public init(_ camera: Camera, scaling: CameraScaling = .fill) { }

    public var body: some View {
        Color.black
    }
}

#endif
