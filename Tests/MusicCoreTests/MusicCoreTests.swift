import Testing
@testable import MusicCore

// MARK: Building files

private func ascii(_ text: String) -> [UInt8] { Array(text.utf8) }

private func big(_ value: Int, _ count: Int) -> [UInt8] {
    (0..<count).reversed().map { UInt8(value >> ($0 * 8) & 0xFF) }
}

private func little(_ value: Int, _ count: Int) -> [UInt8] {
    (0..<count).map { UInt8(value >> ($0 * 8) & 0xFF) }
}

private func synchsafe(_ value: Int) -> [UInt8] {
    [UInt8(value >> 21 & 0x7F), UInt8(value >> 14 & 0x7F), UInt8(value >> 7 & 0x7F), UInt8(value & 0x7F)]
}

/// An ID3 text frame in UTF-8.
private func frame(_ name: String, _ text: String, version: Int = 3) -> [UInt8] {
    let body = [UInt8(3)] + ascii(text)
    let size = version == 4 ? synchsafe(body.count) : big(body.count, 4)
    return ascii(name) + size + [0, 0] + body
}

private func id3(_ frames: [UInt8], version: Int = 3) -> [UInt8] {
    ascii("ID3") + [UInt8(version), 0, 0] + synchsafe(frames.count) + frames
}

/// Vorbis comments: the encoder's name, then the values.
private func comments(_ values: [String]) -> [UInt8] {
    let vendor = ascii("test")
    var bytes = little(vendor.count, 4) + vendor + little(values.count, 4)
    for value in values { bytes += little(ascii(value).count, 4) + ascii(value) }
    return bytes
}

/// An MPEG-4 box.
private func box(_ name: String, _ body: [UInt8]) -> [UInt8] {
    big(body.count + 8, 4) + name.unicodeScalars.map { UInt8($0.value) } + body
}

@Suite struct AudioFormatTests {

    @Test func formatsAreKnownByTheirFirstBytes() {
        #expect(AudioFormat(header: ascii("fLaC") + [0]) == .flac)
        #expect(AudioFormat(header: ascii("OggS") + [0]) == .ogg)
        #expect(AudioFormat(header: ascii("RIFF") + [0, 0, 0, 0] + ascii("WAVE")) == .wav)
        #expect(AudioFormat(header: [0, 0, 0, 32] + ascii("ftypM4A ")) == .m4a)
        #expect(AudioFormat(header: ascii("ID3") + [3, 0, 0]) == .mp3)
        #expect(AudioFormat(header: [0xFF, 0xFB, 0x90, 0x00]) == .mp3)
    }

    @Test func otherFilesAreNotAudio() {
        #expect(AudioFormat(header: []) == nil)
        #expect(AudioFormat(header: ascii("hello")) == nil)
        #expect(AudioFormat(header: ascii("RIFF") + [0, 0, 0, 0] + ascii("WEBP")) == nil)
        // Sync bits with a layer that doesn't exist.
        #expect(AudioFormat(header: [0xFF, 0xF9]) == nil)
    }
}

@Suite struct TagTextTests {

    @Test func encodings() {
        #expect(TagText.latin1([0x63, 0x61, 0x66, 0xE9]) == "café")
        #expect(TagText.utf16([0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00]) == "hi")
        #expect(TagText.utf16([0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69]) == "hi")
        #expect(TagText.utf16([0x00, 0x68], bigEndian: true) == "h")
    }

    @Test func valuesLoseTheirPaddingAndEndAtAZero() {
        #expect(TagText.cleaned("  Song \u{0}junk") == "Song")
        #expect(TagText.cleaned("\u{0}\u{0}") == nil)
        #expect(TagText.cleaned("   ") == nil)
    }

    @Test func numbersLeadTheirText() {
        #expect(TagText.leadingNumber("3/12") == 3)
        #expect(TagText.leadingNumber("2024-05-01") == 2024)
        #expect(TagText.leadingNumber("x") == nil)
    }
}

@Suite struct ID3Tests {

    @Test func aTagOfVersion3() {
        let frames = frame("TIT2", "Blue in Green") + frame("TPE1", "Miles Davis") + frame("TALB", "Kind of Blue")
            + frame("TRCK", "3/5") + frame("TYER", "1959") + frame("TCON", "(8)")
        let tags = TrackTags(header: id3(frames))
        #expect(tags.title == "Blue in Green")
        #expect(tags.artist == "Miles Davis")
        #expect(tags.album == "Kind of Blue")
        #expect(tags.trackNumber == 3)
        #expect(tags.year == 1959)
        #expect(tags.genre == "Jazz")
    }

    @Test func aTagOfVersion4HasSynchsafeFrameSizesAndADate() {
        let long = String(repeating: "a", count: 200)
        let frames = frame("TIT2", long, version: 4) + frame("TDRC", "2001-03-04", version: 4) + frame("TCON", "Ambient", version: 4)
        let tags = TrackTags(header: id3(frames, version: 4))
        #expect(tags.title == long)
        #expect(tags.year == 2001)
        #expect(tags.genre == "Ambient")
    }

    @Test func aTagOfVersion2HasShortNames() {
        func short(_ name: String, _ text: String) -> [UInt8] {
            let body = [UInt8(0)] + ascii(text)
            return ascii(name) + big(body.count, 3) + body
        }
        let tags = TrackTags(header: id3(short("TT2", "Title") + short("TP1", "Artist") + short("TRK", "7"), version: 2))
        #expect(tags.title == "Title")
        #expect(tags.artist == "Artist")
        #expect(tags.trackNumber == 7)
    }

    @Test func textInOtherEncodings() {
        let latin = ascii("TIT2") + big(5, 4) + [0, 0] + [0, 0x63, 0x61, 0x66, 0xE9]
        let wide = ascii("TPE1") + big(7, 4) + [0, 0] + [1, 0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00]
        let tags = TrackTags(header: id3(latin + wide))
        #expect(tags.title == "café")
        #expect(tags.artist == "hi")
    }

    @Test func otherFramesAndPaddingArePassedOver() {
        let picture = ascii("APIC") + big(4, 4) + [0, 0] + [1, 2, 3, 4]
        let frames = picture + frame("TIT2", "After") + [UInt8](repeating: 0, count: 32)
        #expect(TrackTags(header: id3(frames)).title == "After")
    }

    @Test func theOldTagAtTheEndFillsWhatIsMissing() {
        func padded(_ text: String, _ length: Int) -> [UInt8] {
            ascii(text) + [UInt8](repeating: 0, count: length - text.utf8.count)
        }
        var tail = ascii("TAG") + padded("Old Title", 30) + padded("Old Artist", 30) + padded("Old Album", 30) + ascii("1987")
        tail += padded("comment", 28) + [0, 9, 17]
        #expect(tail.count == 128)

        let alone = TrackTags(header: [0xFF, 0xFB, 0x90, 0x00], tail: tail)
        #expect(alone.title == "Old Title")
        #expect(alone.artist == "Old Artist")
        #expect(alone.album == "Old Album")
        #expect(alone.year == 1987)
        #expect(alone.trackNumber == 9)
        #expect(alone.genre == "Rock")

        let both = TrackTags(header: id3(frame("TIT2", "New Title")), tail: tail)
        #expect(both.title == "New Title")
        #expect(both.artist == "Old Artist")
    }

    @Test func lengthFromAConstantBitRate() {
        // MPEG 1 layer III, 128 kbit/s, 44.1 kHz: 16,000 bytes a second.
        let header: [UInt8] = [0xFF, 0xFB, 0x90, 0x00] + [UInt8](repeating: 0, count: 64)
        let tags = TrackTags(header: header, fileSize: 1_600_000)
        #expect(tags.duration == 100)
    }

    @Test func lengthFromAFrameCount() {
        // Stereo MPEG 1: the count comes 32 bytes after the frame's header.
        var bytes: [UInt8] = [0xFF, 0xFB, 0x90, 0x00] + [UInt8](repeating: 0, count: 32)
        bytes += ascii("Xing") + big(1, 4) + big(4410, 4)
        let tags = TrackTags(header: bytes, fileSize: 9_999_999)
        // 4410 frames of 1152 samples at 44,100 a second.
        #expect(tags.duration == 115.2)
    }

    @Test func lengthIsMeasuredFromAfterTheTag() {
        let tag = id3(frame("TIT2", "T"))
        let bytes = tag + [0xFF, 0xFB, 0x90, 0x00] + [UInt8](repeating: 0, count: 64)
        let tags = TrackTags(header: bytes, fileSize: tag.count + 160_000)
        #expect(tags.duration == 10)
        #expect(tags.title == "T")
    }
}

@Suite struct OtherFormatTests {

    @Test func flacHasItsLengthAndComments() {
        // 44,100 Hz, 2 channels, 16 bits, 441,000 samples: ten seconds.
        var info = [UInt8](repeating: 0, count: 10)
        let rate = 44100, samples = 441_000
        info += [UInt8(rate >> 12 & 0xFF), UInt8(rate >> 4 & 0xFF), UInt8(rate & 0x0F) << 4 | 0x02, 0xF0 | UInt8(samples >> 32 & 0x0F)]
        info += big(samples & 0xFFFF_FFFF, 4) + [UInt8](repeating: 0, count: 16)
        let tagged = comments(["TITLE=So What", "artist=Miles Davis", "ALBUM=Kind of Blue", "TRACKNUMBER=1", "DATE=1959-08-17", "GENRE=Jazz"])
        let bytes = ascii("fLaC") + [0] + big(info.count, 3) + info + [0x84] + big(tagged.count, 3) + tagged
        let tags = TrackTags(header: bytes)
        #expect(tags.duration == 10)
        #expect(tags.title == "So What")
        #expect(tags.artist == "Miles Davis")
        #expect(tags.album == "Kind of Blue")
        #expect(tags.trackNumber == 1)
        #expect(tags.year == 1959)
        #expect(tags.genre == "Jazz")
    }

    @Test func oggVorbisAndOpusHaveCommentsAfterTheirMarkers() {
        let page = ascii("OggS") + [UInt8](repeating: 0, count: 24)
        let vorbis = page + [0x01] + ascii("vorbis") + [0, 0, 0] + page + [0x03] + ascii("vorbis") + comments(["TITLE=One", "ARTIST=Two"])
        #expect(TrackTags(header: vorbis).title == "One")
        #expect(TrackTags(header: vorbis).artist == "Two")

        let opus = page + ascii("OpusHead") + [1, 2] + page + ascii("OpusTags") + comments(["ALBUM=Three"])
        #expect(TrackTags(header: opus).album == "Three")
        #expect(TrackTags(header: page).isEmpty)
    }

    @Test func wavHasItsLengthAndItsInfo() {
        func chunk(_ name: String, _ body: [UInt8]) -> [UInt8] {
            ascii(name) + little(body.count, 4) + body + (body.count % 2 == 1 ? [0] : [])
        }
        // 16-bit stereo at 44,100 Hz: 176,400 bytes a second.
        let format = little(1, 2) + little(2, 2) + little(44100, 4) + little(176_400, 4) + little(4, 2) + little(16, 2)
        let info = ascii("INFO") + chunk("INAM", ascii("Tone\u{0}")) + chunk("IART", ascii("Nobody"))
        // The sound itself isn't needed, only how long it says it is.
        let bytes = ascii("RIFF") + little(0, 4) + ascii("WAVE") + chunk("fmt ", format) + chunk("LIST", info)
            + ascii("data") + little(352_800, 4)
        let tags = TrackTags(header: bytes)
        #expect(tags.duration == 2)
        #expect(tags.title == "Tone")
        #expect(tags.artist == "Nobody")
    }

    @Test func mpeg4HasBoxesInsideBoxes() {
        func item(_ name: String, _ value: [UInt8]) -> [UInt8] {
            box(name, box("data", big(1, 4) + big(0, 4) + value))
        }
        let list = item("\u{A9}nam", ascii("Song")) + item("\u{A9}ART", ascii("Singer")) + item("\u{A9}alb", ascii("Record"))
            + item("\u{A9}day", ascii("2010")) + item("trkn", [0, 0, 0, 4, 0, 10, 0, 0])
        // Version and flags, two dates, a time scale of 1000 and 185,500 of them.
        let movieHeader = big(0, 4) + big(0, 4) + big(0, 4) + big(1000, 4) + big(185_500, 4)
        let movie = box("moov", box("mvhd", movieHeader) + box("udta", box("meta", big(0, 4) + box("hdlr", [0, 0]) + box("ilst", list))))
        let bytes = box("ftyp", ascii("M4A ") + big(0, 4)) + box("free", [1, 2, 3]) + movie
        let tags = TrackTags(header: bytes)
        #expect(tags.title == "Song")
        #expect(tags.artist == "Singer")
        #expect(tags.album == "Record")
        #expect(tags.year == 2010)
        #expect(tags.trackNumber == 4)
        #expect(tags.duration == 185.5)
    }

    @Test func filesCutShortOrBrokenGiveWhatTheyCan() {
        #expect(TrackTags(header: ascii("fLaC")).isEmpty)
        #expect(TrackTags(header: ascii("ID3") + [3, 0, 0, 0]).isEmpty)
        #expect(TrackTags(header: [0, 0, 0, 8] + ascii("ftyp")).isEmpty)
        #expect(TrackTags(header: ascii("not music")).isEmpty)
        // A frame that says it's longer than the file is read as far as
        // the file goes.
        let broken = id3(ascii("TIT2") + big(5000, 4) + [0, 0, 3] + ascii("Cut"))
        #expect(TrackTags(header: broken).title == "Cut")
    }
}

/// A generator that counts up, so shuffles come out the same each time.
private struct Counting: RandomNumberGenerator {
    var state: UInt64 = 1
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite struct PlayQueueTests {

    @Test func anEmptyQueuePlaysNothing() {
        var queue = PlayQueue<String>()
        #expect(queue.current == nil)
        #expect(!queue.hasNext && !queue.hasPrevious)
        do { let result = queue.next(); #expect(!result) }
        do { let result = queue.finished(); #expect(result == nil) }
    }

    @Test func playingStartsAtTheTrackAskedFor() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b", "c"], startingAt: "b")
        #expect(queue.current == "b")
        #expect(queue.upcoming == ["c"])
        #expect(queue.hasNext && queue.hasPrevious)
    }

    @Test func withoutRepeatTheQueueStopsAtItsEnd() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b"])
        do { let result = queue.finished(); #expect(result == "b") }
        do { let result = queue.next(); #expect(!result) }
        #expect(queue.current == "b")
        do { let result = queue.finished(); #expect(result == nil) }
    }

    @Test func repeatingAllGoesRound() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b"], startingAt: "b")
        queue.repeatMode = .all
        #expect(queue.hasNext)
        do { let result = queue.next(); #expect(result) }
        #expect(queue.current == "a")
        do { let result = queue.previous(); #expect(result) }
        #expect(queue.current == "b")
        do { let result = queue.finished(); #expect(result == "a") }
    }

    @Test func repeatingOnePlaysTheSameTrackAgainButNextStillMoves() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b"])
        queue.repeatMode = .one
        do { let result = queue.finished(); #expect(result == "a") }
        do { let result = queue.next(); #expect(result) }
        #expect(queue.current == "b")
    }

    @Test func previousStartsTheTrackAgainOnceItIsUnderWay() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b"], startingAt: "b")
        do { let result = queue.previous(elapsed: 10); #expect(!result) }
        #expect(queue.current == "b")
        do { let result = queue.previous(elapsed: 1); #expect(result) }
        #expect(queue.current == "a")
        do { let result = queue.previous(); #expect(!result) }
    }

    @Test func shufflingKeepsTheTrackPlayingAndPlaysEveryTrackOnce() {
        var generator = Counting()
        var queue = PlayQueue<Int>()
        queue.play(Array(1...8), startingAt: 5)
        queue.setShuffled(true, using: &generator)
        #expect(queue.current == 5)
        #expect(queue.upcoming.count == 7)
        #expect(Set(queue.upcoming) == Set([1, 2, 3, 4, 6, 7, 8]))
        #expect(queue.upcoming != [6, 7, 8, 1, 2, 3, 4])

        queue.next()
        let playing = queue.current
        queue.setShuffled(false, using: &generator)
        #expect(queue.current == playing)
        #expect(queue.order == Array(0..<8))
    }

    @Test func aShuffledQueueStaysShuffledForNewTracks() {
        var generator = Counting()
        var queue = PlayQueue<Int>()
        queue.setShuffled(true, using: &generator)
        queue.play(Array(1...6), startingAt: 3, using: &generator)
        #expect(queue.isShuffled)
        #expect(queue.current == 3)
        #expect(Set(queue.upcoming) == Set([1, 2, 4, 5, 6]))
    }

    @Test func jumpingGoesToATrackInTheQueue() {
        var queue = PlayQueue<String>()
        queue.play(["a", "b", "c"])
        queue.jump(to: "c")
        #expect(queue.current == "c")
        queue.jump(to: "z")
        #expect(queue.current == "c")
    }

    @Test func theRepeatButtonGoesRoundItsModes() {
        #expect(RepeatMode.off.next == .all)
        #expect(RepeatMode.all.next == .one)
        #expect(RepeatMode.one.next == .off)
    }
}

@Suite struct LibraryTests {

    private func track(_ file: String, title: String? = nil, artist: String? = nil, album: String? = nil, number: Int? = nil, seconds: Double? = nil) -> Track {
        Track(id: "/music/" + file, fileName: file, tags: TrackTags(title: title, artist: artist, album: album, trackNumber: number, duration: seconds))
    }

    @Test func aTrackWithoutTagsGoesByItsFile() {
        let track = track("01 Intro.mp3")
        #expect(track.title == "01 Intro")
        #expect(track.artist == "Unknown Artist")
        #expect(track.album == "Unknown Album")
        #expect(self.track(".hidden").title == ".hidden")
    }

    @Test func songsAreByTitleWhateverTheCaseOrALeadingThe() {
        let tracks = [track("a", title: "zebra"), track("b", title: "The Apple"), track("c", title: "Banana")]
        #expect(Library.songs(tracks).map(\.title) == ["The Apple", "Banana", "zebra"])
    }

    @Test func albumsGatherTracksInTheOrderOfTheirNumbers() {
        let tracks = [
            track("a", title: "Two", artist: "X", album: "First", number: 2, seconds: 100),
            track("b", title: "One", artist: "X", album: "First", number: 1, seconds: 50),
            track("c", title: "No Number", artist: "X", album: "First"),
            track("d", title: "Other", artist: "Y", album: "First", number: 1),
            track("e", title: "Solo", artist: "X", album: "Second", number: 1),
        ]
        let albums = Library.albums(tracks)
        #expect(albums.map(\.name) == ["First", "First", "Second"])
        #expect(albums.map(\.artist) == ["X", "Y", "X"])
        #expect(albums[0].tracks.map(\.title) == ["One", "Two", "No Number"])
        #expect(albums[0].duration == 150)
    }

    @Test func artistsHaveTheirAlbums() {
        let tracks = [
            track("a", artist: "The Beatles", album: "Help!"),
            track("b", artist: "The Beatles", album: "Abbey Road"),
            track("c", artist: "ABBA", album: "Arrival"),
            track("d"),
        ]
        let artists = Library.artists(tracks)
        #expect(artists.map(\.name) == ["ABBA", "The Beatles", "Unknown Artist"])
        #expect(artists[1].albums.map(\.name) == ["Abbey Road", "Help!"])
        #expect(artists[1].trackCount == 2)
    }

    @Test func searchLooksInTitlesArtistsAndAlbums() {
        let tracks = [track("a", title: "Blue", artist: "X"), track("b", title: "Red", artist: "Bluebird"), track("c", title: "Red", album: "Green")]
        #expect(Library.search(tracks, for: "blue").count == 2)
        #expect(Library.search(tracks, for: "GREEN").count == 1)
        #expect(Library.search(tracks, for: "").count == 3)
    }

    @Test func timesAreWrittenAsPlayersWriteThem() {
        #expect(Library.time(0) == "0:00")
        #expect(Library.time(7) == "0:07")
        #expect(Library.time(187.9) == "3:07")
        #expect(Library.time(3765) == "1:02:45")
        #expect(Library.time(-5) == "0:00")
        #expect(Library.time(.nan) == "0:00")
    }
}
