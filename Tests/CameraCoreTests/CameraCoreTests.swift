//
//  CameraCoreTests.swift
//  CoreApps
//

import Testing
@testable import CameraCore

@Suite struct CaptureTests {

    @Test func namesOfCaptures() throws {
        let photo = try #require(Capture(name: "IMG_0007.jpg"))
        #expect(photo.mode == .photo)
        #expect(photo.number == 7)
        let video = try #require(Capture(name: "VID_0123.MP4"))
        #expect(video.mode == .video)
        #expect(video.number == 123)
        #expect(Capture(name: "VID_0002.webm")?.mode == .video)
    }

    @Test func otherFilesArentCaptures() {
        #expect(Capture(name: "notes.txt") == nil)
        #expect(Capture(name: "IMG_.jpg") == nil)
        #expect(Capture(name: "IMG_12a.jpg") == nil)
        #expect(Capture(name: "IMG_0001.png") == nil)
        #expect(Capture(name: "VID_0001.jpg") == nil)
        #expect(Capture(name: "IMG_0001.jpg.part") == nil)
    }

    @Test func theNextNameFollowsTheHighest() {
        #expect(Capture.nextName(for: .photo, after: []) == "IMG_0001.jpg")
        #expect(Capture.nextName(for: .video, after: ["IMG_0004.jpg", "VID_0009.mp4", "x.txt"]) == "VID_0010.mp4")
        #expect(Capture.nextName(for: .photo, after: ["IMG_9999.jpg"]) == "IMG_10000.jpg")
    }

    @Test func listsAreNewestFirst() {
        let list = Capture.list(["IMG_0002.jpg", "notes.txt", "VID_0003.mp4", "IMG_0001.jpg"])
        #expect(list.map { $0.name } == ["VID_0003.mp4", "IMG_0002.jpg", "IMG_0001.jpg"])
    }
}

@Suite struct ControlsTests {

    @Test func zoomPresetsInTheRange() {
        #expect(ZoomLevels.presets(lower: 0.5, upper: 15) == [0.5, 1, 2, 3, 5, 10])
        #expect(ZoomLevels.presets(lower: 1, upper: 2.5) == [1, 2])
        #expect(ZoomLevels.presets(lower: 1, upper: 1).isEmpty)
    }

    @Test func theCurrentPreset() {
        let presets: [Double] = [0.5, 1, 2]
        #expect(ZoomLevels.current(1.4, in: presets) == 1)
        #expect(ZoomLevels.current(2, in: presets) == 2)
        #expect(ZoomLevels.current(0.3, in: presets) == 0.5)
    }

    @Test func zoomLabels() {
        #expect(ZoomLevels.label(0.5) == "0.5×")
        #expect(ZoomLevels.label(1) == "1×")
        #expect(ZoomLevels.label(2.44) == "2.4×")
        #expect(ZoomLevels.label(9.96) == "10×")
    }

    @Test func recordingTimes() {
        #expect(RecordingTime.format(0) == "0:00")
        #expect(RecordingTime.format(7.9) == "0:07")
        #expect(RecordingTime.format(750) == "12:30")
        #expect(RecordingTime.format(3723) == "1:02:03")
        #expect(RecordingTime.format(-.infinity) == "0:00")
    }

    @Test func flashStepsThroughItsSettings() {
        #expect(FlashSetting.off.next == .auto)
        #expect(FlashSetting.auto.next == .on)
        #expect(FlashSetting.on.next == .off)
    }
}
