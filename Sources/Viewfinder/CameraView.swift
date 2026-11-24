//
//  CameraView.swift
//  CoreApps
//

import AppCamera
import AppUI
import CameraCore
import CoreAppsUI

/// The camera: what it sees, and under it the zoom, the mode, the shutter,
/// the last capture and the switch between cameras.
public struct CameraView: View {

    @State private var camera = Camera()

    @State private var store = CaptureStore()

    @State private var access = CameraAccess.notDetermined

    @State private var mode = CaptureMode.photo

    @State private var flash = FlashSetting.off

    @State private var captures: [Capture] = []

    @State private var isBusy = false

    @State private var isShowingCaptures = false

    @State private var problem: String?

    public init() { }

    public var body: some View {
        ZStack {
            CameraColors.background
                .fullBleed()
            content
        }
        .onAppear(perform: appear)
        .onDisappear { camera.stop() }
        .sheet(isPresented: $isShowingCaptures) {
            CapturesView(store: store, captures: captures, deleted: reload, done: { isShowingCaptures = false })
        }
    }

    @ViewBuilder
    private var content: some View {
        switch access {
        case .authorized:
            VStack(spacing: 0) {
                topBar
                ZStack {
                    CameraPreview(camera)
                    if camera.state == .failed {
                        notice(Self.message(camera.error))
                    } else if camera.state == .interrupted {
                        notice("The camera is in use by something else.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(CameraColors.text)
                        .padding(.top, 8)
                }
                controls
            }
        case .notDetermined:
            VStack(spacing: 16) {
                notice("Camera needs your leave to use the camera.")
                Button("Allow Camera", action: requestAccess)
                    .accessibilityIdentifier("allow-camera")
            }
        case .unavailable:
            notice("This device has no camera.")
        default:
            notice("Camera isn't allowed to use the camera. You can allow it in the system's settings.")
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(CameraColors.text)
            .multilineTextAlignment(.center)
            .padding(32)
    }

    // MARK: Controls

    private var topBar: some View {
        HStack {
            if camera.hasFlash && mode == .photo {
                Button {
                    flash = flash.next
                } label: {
                    Image(systemName: flash.symbol)
                        .foregroundStyle(flash == .off ? CameraColors.text : CameraColors.flash)
                        .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                }
                .plainButton()
                .accessibilityLabel(flash.name)
                .accessibilityIdentifier("flash")
            }
            Spacer()
            if camera.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .foregroundStyle(CameraColors.record)
                        .frame(width: 8, height: 8)
                    Text(RecordingTime.format(camera.recordingDuration))
                        .foregroundStyle(CameraColors.text)
                }
                .accessibilityIdentifier("recording-time")
            }
            Spacer()
            Color(white: 0, opacity: 0)
                .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
        }
        .padding(.horizontal, 8)
        .frame(height: Metrics.minimumTarget + 8)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            zoomButtons
            if !camera.isRecording {
                HStack(spacing: 24) {
                    ForEach(CaptureMode.allCases) { candidate in
                        Button {
                            mode = candidate
                        } label: {
                            Text(candidate.name.uppercased())
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundStyle(candidate == mode ? CameraColors.flash : CameraColors.text)
                        }
                        .plainButton()
                        .accessibilityIdentifier("mode-" + candidate.rawValue)
                    }
                }
            }
            HStack {
                lastCapture
                Spacer()
                shutter
                Spacer()
                switchButton
            }
            .padding(.horizontal, 28)
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var zoomButtons: some View {
        let presets = ZoomLevels.presets(lower: camera.zoomRange.lowerBound, upper: camera.zoomRange.upperBound)
        if !presets.isEmpty {
            let current = ZoomLevels.current(camera.zoomFactor, in: presets)
            HStack(spacing: 8) {
                ForEach(0..<presets.count) { index in
                    let preset = presets[index]
                    Button {
                        camera.zoomFactor = preset
                    } label: {
                        Text(preset == current ? ZoomLevels.label(camera.zoomFactor) : ZoomLevels.label(preset))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(preset == current ? CameraColors.flash : CameraColors.text)
                            .frame(width: 38, height: 38)
                            .background(CameraColors.button)
                            .cornerRadius(19)
                    }
                    .plainButton()
                }
            }
        }
    }

    private var shutter: some View {
        Button(action: shoot) {
            ZStack {
                Circle()
                    .foregroundStyle(CameraColors.text)
                    .frame(width: 72, height: 72)
                Circle()
                    .foregroundStyle(CameraColors.background)
                    .frame(width: 64, height: 64)
                if mode == .video {
                    if camera.isRecording {
                        Rectangle()
                            .foregroundStyle(CameraColors.record)
                            .frame(width: 26, height: 26)
                            .cornerRadius(5)
                    } else {
                        Circle()
                            .foregroundStyle(CameraColors.record)
                            .frame(width: 56, height: 56)
                    }
                } else {
                    Circle()
                        .foregroundStyle(CameraColors.text)
                        .frame(width: 56, height: 56)
                }
            }
        }
        .plainButton()
        .disabled(isBusy || camera.state != .running)
        .accessibilityLabel(mode == .photo ? "Take Photo" : camera.isRecording ? "Stop Recording" : "Record Video")
        .accessibilityIdentifier("shutter")
    }

    @ViewBuilder
    private var lastCapture: some View {
        Button {
            isShowingCaptures = true
        } label: {
            ZStack {
                CameraColors.button
                if let latest = captures.first {
                    if let image = store.image(latest) {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: latest.mode == .video ? "video" : "photo")
                            .foregroundStyle(CameraColors.text)
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipped()
            .cornerRadius(8)
        }
        .plainButton()
        .disabled(captures.isEmpty || camera.isRecording)
        .accessibilityLabel("Photos and Videos")
        .accessibilityIdentifier("captures")
    }

    private var switchButton: some View {
        Button(action: switchCamera) {
            Image(systemName: "camera.rotate")
                .font(.title2)
                .foregroundStyle(CameraColors.text)
                .frame(width: 52, height: 52)
                .background(CameraColors.button)
                .cornerRadius(26)
        }
        .plainButton()
        .disabled(Camera.positions.count < 2 || camera.isRecording)
        .accessibilityLabel("Switch Camera")
        .accessibilityIdentifier("switch-camera")
    }

    // MARK: Actions

    private func appear() {
        reload()
        access = Camera.access
        if access == .authorized {
            camera.start(Camera.positions.first ?? .back)
        }
    }

    private func requestAccess() {
        Camera.requestAccess { granted in
            access = granted
            if granted == .authorized {
                camera.start(Camera.positions.first ?? .back)
            }
        }
    }

    private func reload() {
        store.reload { list in
            captures = list
        }
    }

    private func switchCamera() {
        let positions = Camera.positions
        guard positions.count > 1, let index = positions.firstIndex(of: camera.position) else { return }
        camera.start(positions[(index + 1) % positions.count])
    }

    private func shoot() {
        problem = nil
        switch mode {
        case .photo:
            takePhoto()
        case .video:
            if camera.isRecording {
                stopRecording()
            } else if Camera.microphoneAccess == .notDetermined {
                Camera.requestMicrophoneAccess { _ in startRecording() }
            } else {
                startRecording()
            }
        }
    }

    private func takePhoto() {
        camera.flashMode = switch flash {
        case .off: .off
        case .auto: .auto
        case .on: .on
        }
        isBusy = true
        camera.capturePhoto(to: store.file(store.nextName(for: .photo))) { result in
            isBusy = false
            if case .failure(let error) = result {
                problem = "The photo wasn't taken: " + Self.message(error)
            }
            reload()
        }
    }

    private func startRecording() {
        let audio = Camera.microphoneAccess == .authorized
        camera.startRecording(to: store.file(store.nextName(for: .video)), audio: audio) { result in
            if case .failure(let error) = result {
                problem = "The video didn't start: " + Self.message(error)
            }
        }
    }

    private func stopRecording() {
        isBusy = true
        camera.stopRecording { result in
            isBusy = false
            if case .failure(let error) = result {
                problem = "The video wasn't kept: " + Self.message(error)
            }
            reload()
        }
    }

    static func message(_ error: CameraError?) -> String {
        switch error {
        case .notAuthorized: "Camera isn't allowed to use the camera."
        case .unavailable: "This device has no such camera."
        case .notRunning: "The camera is off."
        case .busy: "The camera is busy."
        case .interrupted: "The camera was taken away."
        case .writeFailed: "There's no room to keep it."
        default: "Something went wrong with the camera."
        }
    }
}

extension View {

    /// Under the status bar and the home indicator too, where the flavor
    /// has safe areas to go past.
    @ViewBuilder
    func fullBleed() -> some View {
        #if Native || Apple
        self.ignoresSafeArea()
        #else
        self
        #endif
    }
}

/// The camera's colors, given as values: a guest's host doesn't know every
/// system color by name. The camera is dark whatever the system's look.
enum CameraColors {
    static let background = Color(white: 0)
    static let text = Color(white: 1)
    static let button = Color(white: 1, opacity: 0.15)
    /// The flash and the mode or zoom chosen.
    static let flash = Color(red: 1, green: 0.8, blue: 0)
    static let record = Color(red: 1, green: 0.23, blue: 0.19)
}
