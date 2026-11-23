//
//  AppleCamera.swift
//  CoreApps
//

#if Apple

@preconcurrency import AVFoundation
import ImageIO
import Observation
import SwiftUI

/// A camera, as AppRuntime's `Camera` is: the part the apps use, over an
/// `AVCaptureSession`. Show what it sees with `CameraPreview(camera)`.
///
/// It's observable: a view that reads `state`, `zoomFactor` or
/// `recordingDuration` is updated when they change. The session is set up
/// and run on a queue of its own, and its answers come back to the main
/// actor.
@MainActor
@Observable
public final class Camera {

    // MARK: Access

    /// The cameras this device has.
    public static var positions: [CameraPosition] {
        var positions: [CameraPosition] = []
        if device(for: .back) != nil { positions.append(.back) }
        if device(for: .front) != nil { positions.append(.front) }
        if device(for: .external) != nil { positions.append(.external) }
        return positions
    }

    /// Whether the app may use the camera now. Never asks.
    public static var access: CameraAccess {
        positions.isEmpty ? .unavailable : access(AVCaptureDevice.authorizationStatus(for: .video))
    }

    /// Whether the app may record sound now. Never asks.
    public static var microphoneAccess: CameraAccess {
        AVCaptureDevice.default(for: .audio) == nil ? .unavailable : access(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// Asks the user for the camera if they haven't decided.
    public static func requestAccess(completion: @escaping (CameraAccess) -> Void) {
        request(.video, available: !positions.isEmpty, completion: completion)
    }

    /// Asks the user for the microphone, for a video with sound.
    public static func requestMicrophoneAccess(completion: @escaping (CameraAccess) -> Void) {
        request(.audio, available: AVCaptureDevice.default(for: .audio) != nil, completion: completion)
    }

    private static func request(_ media: AVMediaType, available: Bool, completion: @escaping (CameraAccess) -> Void) {
        guard available else { return completion(.unavailable) }
        guard AVCaptureDevice.authorizationStatus(for: media) == .notDetermined else {
            return completion(access(AVCaptureDevice.authorizationStatus(for: media)))
        }
        // Answered on the main thread, where it was asked.
        nonisolated(unsafe) let completion = completion
        AVCaptureDevice.requestAccess(for: media) { granted in
            DispatchQueue.main.async {
                completion(granted ? .authorized : .denied)
            }
        }
    }

    private static func access(_ status: AVAuthorizationStatus) -> CameraAccess {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
    }

    // MARK: State

    public private(set) var state: CameraState = .stopped

    /// Which camera is on, or was last.
    public private(set) var position: CameraPosition = .back

    /// 1 is the main lens; a phone's ultra wide is below it. Clamped to
    /// `zoomRange`.
    public var zoomFactor: Double {
        get { zoom }
        set { setZoom(newValue) }
    }

    public private(set) var zoomRange: ClosedRange<Double> = 1...1

    public private(set) var hasFlash = false

    /// For photos, where the camera has a flash.
    public var flashMode: CameraFlashMode = .off

    public private(set) var isRecording = false

    /// Seconds into the recording; after it, its length.
    public private(set) var recordingDuration: Double = 0

    /// Why it's `.failed`.
    public private(set) var error: CameraError?

    /// Called with the video when a recording ends, however it ended.
    @ObservationIgnored public var onRecordingFinished: ((CapturedVideo) -> Void)?

    private var zoom: Double = 1

    // MARK: Session

    @ObservationIgnored private let capture = Capture()

    /// The device's zoom for a factor of 1: the main lens, past a virtual
    /// device's ultra wide.
    @ObservationIgnored private var zoomScale: Double = 1

    @ObservationIgnored private var device: AVCaptureDevice?

    @ObservationIgnored private var photoDelegates: [Int64: PhotoDelegate] = [:]

    @ObservationIgnored private var recordingDelegate: RecordingDelegate?

    @ObservationIgnored private var recordingTimer: Timer?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    public init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: capture.session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.state = .interrupted }
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: capture.session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    if self?.state == .interrupted { self?.state = .running }
                }
            },
        ]
    }

    /// What `CameraPreview` shows.
    var session: AVCaptureSession { capture.session }

    // MARK: Running

    /// Turns on a camera; on one that's running, it switches.
    public func start(_ position: CameraPosition = .back) {
        guard let device = Self.device(for: position) else {
            fail(.unavailable)
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            fail(.notAuthorized)
            return
        }
        self.position = position
        self.device = device
        state = .starting
        error = nil
        let withAudio = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        capture.queue.async { [capture] in
            let started = capture.configure(device: device, audio: withAudio)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard started else { return self.fail(.unavailable) }
                    self.deviceStarted(device)
                }
            }
        }
    }

    public func stop() {
        if isRecording {
            capture.movieOutput.stopRecording()
        }
        state = .stopped
        capture.queue.async { [capture] in
            capture.session.stopRunning()
        }
    }

    private func deviceStarted(_ device: AVCaptureDevice) {
        #if os(iOS)
        // A virtual device with an ultra wide starts at it; its first
        // switch-over is the main lens, which people call 1×.
        let scale = device.virtualDeviceSwitchOverVideoZoomFactors.first.map { Double(truncating: $0) } ?? 1
        zoomScale = device.deviceType == .builtInWideAngleCamera ? 1 : scale
        let lower = Double(device.minAvailableVideoZoomFactor) / zoomScale
        let upper = min(Double(device.maxAvailableVideoZoomFactor), zoomScale * 15) / zoomScale
        zoomRange = lower...max(lower, upper)
        #else
        // A Mac's cameras don't zoom.
        zoomRange = 1...1
        #endif
        hasFlash = device.hasFlash
        state = .running
        setZoom(1)
    }

    private func setZoom(_ factor: Double) {
        let clamped = min(max(factor, zoomRange.lowerBound), zoomRange.upperBound)
        zoom = clamped
        #if os(iOS)
        guard let device else { return }
        let value = CGFloat(clamped * zoomScale)
        capture.queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = min(max(value, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.unlockForConfiguration()
        }
        #endif
    }

    private func fail(_ error: CameraError) {
        self.error = error
        state = .failed
    }

    // MARK: Photos

    /// Takes a photo: a JPEG, upright, written to `file`.
    public func capturePhoto(to file: CaptureFile, completion: @escaping (Result<CapturedPhoto, CameraError>) -> Void) {
        guard state == .running else { return completion(.failure(.notRunning)) }
        guard photoDelegates.isEmpty, !isRecording else { return completion(.failure(.busy)) }
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        let flash: AVCaptureDevice.FlashMode = switch flashMode {
        case .off: .off
        case .on: .on
        case .auto: .auto
        }
        if capture.photoOutput.supportedFlashModes.contains(flash) {
            settings.flashMode = flash
        }
        let id = settings.uniqueID
        nonisolated(unsafe) let completion = completion
        let delegate = PhotoDelegate(url: URL(fileURLWithPath: file)) { [weak self] result in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.photoDelegates[id] = nil
                    completion(result.map { CapturedPhoto(path: file, width: $0.width, height: $0.height) })
                }
            }
        }
        photoDelegates[id] = delegate
        let angle = rotationAngle()
        capture.queue.async { [capture] in
            if let connection = capture.photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            capture.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    // MARK: Videos

    /// Starts recording to `file`, with sound when `audio` and the user
    /// allows the microphone.
    public func startRecording(to file: CaptureFile, audio: Bool = true, completion: @escaping (Result<Void, CameraError>) -> Void) {
        guard state == .running else { return completion(.failure(.notRunning)) }
        guard !isRecording, photoDelegates.isEmpty else { return completion(.failure(.busy)) }
        let url = URL(fileURLWithPath: file)
        try? FileManager.default.removeItem(at: url)
        let delegate = RecordingDelegate { [weak self] duration, failed in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.recordingEnded(file: file, duration: duration, failed: failed)
                }
            }
        }
        recordingDelegate = delegate
        isRecording = true
        recordingDuration = 0
        let started = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.recordingDuration = Date().timeIntervalSince(started)
            }
        }
        let angle = rotationAngle()
        capture.queue.async { [capture] in
            if let connection = capture.movieOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if let connection = capture.movieOutput.connection(with: .audio) {
                connection.isEnabled = audio
            }
            capture.movieOutput.startRecording(to: url, recordingDelegate: delegate)
        }
        completion(.success(()))
    }

    @ObservationIgnored private var stopCompletion: ((Result<CapturedVideo, CameraError>) -> Void)?

    public func stopRecording(completion: @escaping (Result<CapturedVideo, CameraError>) -> Void) {
        guard isRecording else { return completion(.failure(.notRunning)) }
        stopCompletion = completion
        capture.queue.async { [capture] in
            capture.movieOutput.stopRecording()
        }
    }

    private func recordingEnded(file: CaptureFile, duration: Double, failed: Bool) {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingDuration = duration
        recordingDelegate = nil
        let video = CapturedVideo(path: file, duration: duration, contentType: "video/quicktime")
        let completion = stopCompletion
        stopCompletion = nil
        if failed, !FileManager.default.fileExists(atPath: file) {
            completion?(.failure(.writeFailed))
            return
        }
        completion?(.success(video))
        onRecordingFinished?(video)
    }

    // MARK: Devices

    /// The way up for what's captured: the device held upright.
    private func rotationAngle() -> CGFloat {
        guard let device else { return 0 }
        return AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil).videoRotationAngleForHorizonLevelCapture
    }

    private static func device(for position: CameraPosition) -> AVCaptureDevice? {
        #if os(iOS)
        let types: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera,
                                                   .builtInWideAngleCamera, .external]
        #else
        let types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external]
        #endif
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
        switch position {
        case .back: return devices.first { $0.position == .back }
        case .front: return devices.first { $0.position == .front }
        case .external: return devices.first { $0.deviceType == .external }
        }
    }
}

/// The session and its outputs, changed only on `queue`.
private final class Capture: @unchecked Sendable {

    let session = AVCaptureSession()

    let photoOutput = AVCapturePhotoOutput()

    let movieOutput = AVCaptureMovieFileOutput()

    let queue = DispatchQueue(label: "org.pureswift.camera.session")

    private var videoInput: AVCaptureDeviceInput?

    private var audioInput: AVCaptureDeviceInput?

    /// Shows `device`, with the microphone when `audio`, and runs.
    func configure(device: AVCaptureDevice, audio: Bool) -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            if !session.isRunning {
                session.startRunning()
            }
        }
        session.sessionPreset = .high
        if let videoInput {
            session.removeInput(videoInput)
            self.videoInput = nil
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return false
        }
        session.addInput(input)
        videoInput = input
        if audio, audioInput == nil, let microphone = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: microphone), session.canAddInput(input) {
            session.addInput(input)
            audioInput = input
        }
        if !session.outputs.contains(photoOutput), session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        return true
    }
}

/// Writes a photo's JPEG, and says its upright size.
private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    let url: URL

    let completion: (Result<(width: Int, height: Int), CameraError>) -> Void

    init(url: URL, completion: @escaping (Result<(width: Int, height: Int), CameraError>) -> Void) {
        self.url = url
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        guard error == nil, let data = photo.fileDataRepresentation() else {
            return completion(.failure(.unknown))
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return completion(.failure(.writeFailed))
        }
        let dimensions = photo.resolvedSettings.photoDimensions
        // The orientation the file records turns a sideways picture
        // upright.
        let orientation = (photo.metadata[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1
        let sideways = orientation >= 5
        completion(.success(sideways
            ? (Int(dimensions.height), Int(dimensions.width))
            : (Int(dimensions.width), Int(dimensions.height))))
    }
}

/// Says when a recording's file is whole.
private final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {

    let finished: (_ duration: Double, _ failed: Bool) -> Void

    init(finished: @escaping (_ duration: Double, _ failed: Bool) -> Void) {
        self.finished = finished
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection],
                    error: (any Error)?) {
        finished(output.recordedDuration.seconds.isFinite ? output.recordedDuration.seconds : 0, error != nil)
    }
}

/// Shows what a camera sees. It takes the space it's offered and fills it,
/// cropping, unless told to fit. The front camera's is mirrored.
public struct CameraPreview: View {

    let camera: Camera

    let scaling: CameraScaling

    public init(_ camera: Camera, scaling: CameraScaling = .fill) {
        self.camera = camera
        self.scaling = scaling
    }

    public var body: some View {
        PreviewLayerView(session: camera.session, gravity: scaling == .fill ? .resizeAspectFill : .resizeAspect)
            .background(Color.black)
    }
}

#if os(iOS)

import UIKit

private struct PreviewLayerView: UIViewRepresentable {

    let session: AVCaptureSession

    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: LayerView, context: Context) {
        view.previewLayer.videoGravity = gravity
    }

    final class LayerView: UIView {

        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

#else

import AppKit

private struct PreviewLayerView: NSViewRepresentable {

    let session: AVCaptureSession

    let gravity: AVLayerVideoGravity

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view.layer as? AVCaptureVideoPreviewLayer)?.videoGravity = gravity
    }
}

#endif

#endif
