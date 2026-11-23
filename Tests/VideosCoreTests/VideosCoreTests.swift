import Testing
@testable import VideosCore

@Suite struct PlaybackClockTests {

    @Test func timesAreMinutesAndSeconds() {
        #expect(PlaybackClock.text(0) == "0:00")
        #expect(PlaybackClock.text(7.9) == "0:07")
        #expect(PlaybackClock.text(750) == "12:30")
        #expect(PlaybackClock.text(3723) == "1:02:03")
        #expect(PlaybackClock.text(-4) == "0:00")
        #expect(PlaybackClock.text(.nan) == "0:00")
        #expect(PlaybackClock.text(.infinity) == "0:00")
    }

    @Test func aLongVideoShowsHoursThroughout() {
        #expect(PlaybackClock.text(7, longest: 3600) == "0:00:07")
        #expect(PlaybackClock.text(7, longest: 3599) == "0:07")
    }

    @Test func theBarShowsTimeGoneAndLeft() {
        let clock = PlaybackClock(position: 65, duration: 200)
        #expect(clock.elapsedText == "1:05")
        #expect(clock.remainingText == "-2:15")
        #expect(clock.isSeekable)
        #expect(clock.range == 0...200)
    }

    @Test func aPositionPastTheEndIsTheEnd() {
        let clock = PlaybackClock(position: 250, duration: 200)
        #expect(clock.clampedPosition == 200)
        #expect(clock.elapsedText == "3:20")
        #expect(clock.remainingText == "-0:00")
        #expect(PlaybackClock(position: -3, duration: 200).clampedPosition == 0)
    }

    @Test func anUnknownLengthIsLive() {
        let clock = PlaybackClock(position: 12, duration: nil)
        #expect(!clock.isSeekable)
        #expect(clock.remainingText == "Live")
        #expect(clock.elapsedText == "0:12")
        #expect(clock.range == 0...1)
        #expect(!PlaybackClock(position: 0, duration: 0).isSeekable)
        #expect(!PlaybackClock(position: 0, duration: .infinity).isSeekable)
    }

    @Test func skippingStaysWithinTheVideo() {
        let clock = PlaybackClock(position: 5, duration: 60)
        #expect(clock.skipped(by: 10) == 15)
        #expect(clock.skipped(by: -10) == 0)
        #expect(PlaybackClock(position: 55, duration: 60).skipped(by: 10) == 60)
        #expect(PlaybackClock(position: 55, duration: nil).skipped(by: 10) == 65)
    }
}

@Suite struct VolumeLevelTests {

    @Test func theSpeakerShowsTheVolume() {
        #expect(VolumeLevel(volume: 0).symbolName == "speaker.slash.fill")
        #expect(VolumeLevel(volume: 0.2).symbolName == "speaker.wave.1.fill")
        #expect(VolumeLevel(volume: 0.5).symbolName == "speaker.wave.2.fill")
        #expect(VolumeLevel(volume: 0.9).symbolName == "speaker.wave.3.fill")
        #expect(VolumeLevel(volume: 0.9, isMuted: true).symbolName == "speaker.slash.fill")
    }

    @Test func volumeStaysBetweenNothingAndAll() {
        #expect(VolumeLevel(volume: 3).volume == 1)
        #expect(VolumeLevel(volume: -1).volume == 0)
        #expect(VolumeLevel(volume: .nan).volume == 0)
        #expect(VolumeLevel(volume: 0.9).stepped(by: 0.25).volume == 1)
    }

    @Test func theSpeakerMutesAndUnmutes() {
        let level = VolumeLevel(volume: 0.6)
        let muted = level.toggled()
        #expect(muted.isMuted)
        #expect(muted.volume == 0.6)
        #expect(muted.toggled() == level)
        // A volume dragged to nothing comes back, rather than staying silent.
        #expect(VolumeLevel(volume: 0).toggled() == VolumeLevel(volume: 0.25))
        #expect(VolumeLevel(volume: 0, isMuted: true).toggled() == VolumeLevel(volume: 0.25))
    }

    @Test func steppingUnmutes() {
        #expect(!VolumeLevel(volume: 0.5, isMuted: true).stepped(by: 0.1).isMuted)
    }
}

@Suite struct VideoLocationTests {

    @Test func addressesAreOnTheWeb() {
        #expect(VideoLocation("https://example.com/films/trailer.mp4") == .web("https://example.com/films/trailer.mp4"))
        #expect(VideoLocation("  HTTP://example.com/a.webm \n") == .web("HTTP://example.com/a.webm"))
        #expect(VideoLocation("https://") == nil)
    }

    @Test func pathsAndFileAddressesAreFiles() {
        #expect(VideoLocation("/home/me/Videos/Holiday.mkv") == .file("/home/me/Videos/Holiday.mkv"))
        #expect(VideoLocation("clip.mp4") == .file("clip.mp4"))
        #expect(VideoLocation("file:///home/me/My%20Film.mov") == .file("/home/me/My Film.mov"))
        #expect(VideoLocation("file://relative") == nil)
    }

    @Test func otherSchemesAndNothingAreNotVideos() {
        #expect(VideoLocation("") == nil)
        #expect(VideoLocation("   ") == nil)
        #expect(VideoLocation("rtsp://camera.local/stream") == nil)
    }

    @Test func titlesAreNamesWithoutExtensions() {
        #expect(VideoLocation.file("/home/me/Videos/Holiday.mkv").title == "Holiday")
        #expect(VideoLocation.file("/tmp/.hidden").title == ".hidden")
        #expect(VideoLocation.web("https://example.com/a/Big%20Buck%20Bunny.mp4?t=10#x").title == "Big Buck Bunny")
        #expect(VideoLocation.web("https://example.com").title == "example.com")
        #expect(VideoLocation.web("https://example.com/").title == "example.com")
    }

    @Test func extensionsSayWhatAFileIs() {
        #expect(VideoLocation.file("/a/B.MP4").fileExtension == "mp4")
        #expect(VideoLocation.file("/a/B.MP4").mimeType == "video/mp4")
        #expect(VideoLocation.file("/a/b.webm").mimeType == "video/webm")
        #expect(VideoLocation.file("/a/b.mkv").looksLikeVideo)
        #expect(!VideoLocation.file("/a/notes.txt").looksLikeVideo)
        #expect(!VideoLocation.file("/a/README").looksLikeVideo)
        #expect(VideoLocation.web("https://example.com/live").looksLikeVideo)
        #expect(VideoLocation.web("https://example.com").fileExtension == nil)
    }

    @Test func percentEscapesAreDecoded() {
        #expect(VideoLocation.percentDecoded("a%20b%C3%A9") == "a bé")
        #expect(VideoLocation.percentDecoded("100%") == "100%")
        #expect(VideoLocation.percentDecoded("%zz") == "%zz")
    }
}
