//
//  TrackTags.swift
//  CoreApps
//

/// What a music file says of itself: its tags, and how long it plays.
public struct TrackTags: Hashable, Sendable {

    public var title: String?

    public var artist: String?

    public var album: String?

    /// The track's number on its album.
    public var trackNumber: Int?

    public var year: Int?

    public var genre: String?

    /// How long the track plays, in seconds, where the file's header says.
    public var duration: Double?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        trackNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        duration: Double? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.trackNumber = trackNumber
        self.year = year
        self.genre = genre
        self.duration = duration
    }

    /// Whether the file said nothing.
    public var isEmpty: Bool {
        self == TrackTags()
    }

    /// Fills what's missing here from other tags.
    public func merging(_ other: TrackTags) -> TrackTags {
        TrackTags(
            title: title ?? other.title,
            artist: artist ?? other.artist,
            album: album ?? other.album,
            trackNumber: trackNumber ?? other.trackNumber,
            year: year ?? other.year,
            genre: genre ?? other.genre,
            duration: duration ?? other.duration
        )
    }

    /// Reads the tags of a file.
    ///
    /// - Parameters:
    ///   - bytes: The start of the file: as much as holds its tags. For
    ///     MPEG-4 that may be all of it, as the tags can come last.
    ///   - tail: The file's last 128 bytes, where the oldest kind of MP3
    ///     tag is kept.
    ///   - fileSize: The whole file's size in bytes, for working out how
    ///     long an MP3 plays.
    public init(header bytes: [UInt8], tail: [UInt8] = [], fileSize: Int? = nil) {
        self.init()
        guard let format = AudioFormat(header: bytes) else { return }
        let reader = ByteReader(bytes)
        switch format {
        case .mp3:
            self = Self.id3v2(reader).merging(Self.id3v1(tail))
            duration = Self.mp3Duration(reader, fileSize: fileSize ?? bytes.count)
        case .flac:
            self = Self.flac(reader)
        case .ogg:
            self = Self.ogg(reader)
        case .wav:
            self = Self.wav(reader)
        case .m4a:
            self = Self.mp4(reader)
        }
    }

    /// Sets a field from a tag's name, as Vorbis comments name them.
    private mutating func set(_ name: String, _ value: String) {
        guard let value = TagText.cleaned(value) else { return }
        switch name.uppercased() {
        case "TITLE": title = title ?? value
        case "ARTIST": artist = artist ?? value
        case "ALBUM": album = album ?? value
        case "TRACKNUMBER": trackNumber = trackNumber ?? TagText.leadingNumber(value)
        case "DATE", "YEAR": year = year ?? TagText.leadingNumber(value)
        case "GENRE": genre = genre ?? value
        default: break
        }
    }

    // MARK: ID3

    /// The tag at the start of an MP3: a header, then frames of a name, a
    /// size and a value.
    static func id3v2(_ reader: ByteReader) -> TrackTags {
        var tags = TrackTags()
        guard reader.matches("ID3", at: 0), reader.count >= 10, let size = reader.synchsafe32(6) else { return tags }
        let version = Int(reader.bytes[3])
        let flags = reader.bytes[5]
        var offset = 10
        let end = min(reader.count, 10 + size)
        // An extended header comes before the frames.
        if flags & 0x40 != 0 {
            let extended = version == 4 ? reader.synchsafe32(offset) : reader.big32(offset).map { $0 + 4 }
            offset += extended ?? 0
        }
        // Version 2 has names of three letters and sizes of three bytes.
        let nameLength = version == 2 ? 3 : 4
        let headerLength = version == 2 ? 6 : 10
        while offset + headerLength <= end {
            guard let nameBytes = reader.slice(offset, nameLength), nameBytes[0] != 0 else { break }
            let name = TagText.utf8(nameBytes)
            let length: Int?
            switch version {
            case 2: length = reader.big24(offset + 3)
            case 4: length = reader.synchsafe32(offset + 4)
            default: length = reader.big32(offset + 4)
            }
            guard let length, length > 0, let value = reader.slice(offset + headerLength, min(length, end - offset - headerLength)) else { break }
            offset += headerLength + length
            guard name.hasPrefix("T"), let text = id3Text(value) else { continue }
            switch name {
            case "TIT2", "TT2": tags.title = text
            case "TPE1", "TP1": tags.artist = text
            case "TALB", "TAL": tags.album = text
            case "TRCK", "TRK": tags.trackNumber = TagText.leadingNumber(text)
            case "TYER", "TDRC", "TYE": tags.year = TagText.leadingNumber(text)
            case "TCON", "TCO": tags.genre = id3Genre(text)
            default: break
            }
        }
        return tags
    }

    /// A text frame's value: a byte saying the encoding, then the text.
    private static func id3Text(_ value: [UInt8]) -> String? {
        guard let encoding = value.first else { return nil }
        let body = Array(value.dropFirst())
        let text: String
        switch encoding {
        case 0: text = TagText.latin1(body)
        case 1: text = TagText.utf16(body)
        case 2: text = TagText.utf16(body, bigEndian: true)
        default: text = TagText.utf8(body)
        }
        return TagText.cleaned(text)
    }

    /// A genre, which older tags write as a number in brackets: "(17)".
    private static func id3Genre(_ text: String) -> String {
        guard text.hasPrefix("("), let close = text.firstIndex(of: ")") else { return text }
        let rest = String(text[text.index(after: close)...])
        if let named = TagText.cleaned(rest) { return named }
        let inside = String(text[text.index(after: text.startIndex)..<close])
        return TagText.leadingNumber(inside).flatMap(genreName) ?? text
    }

    /// The names of the numbered genres that are still met.
    private static func genreName(_ number: Int) -> String? {
        let names = [
            "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal",
            "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
            "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop",
            "Vocal", "Jazz+Funk", "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game",
            "Sound Clip", "Gospel", "Noise", "Alternative Rock", "Bass", "Soul", "Punk",
        ]
        return names.indices.contains(number) ? names[number] : nil
    }

    /// The tag at the end of an MP3: 128 bytes of fields of fixed widths.
    static func id3v1(_ tail: [UInt8]) -> TrackTags {
        guard tail.count >= 128 else { return TrackTags() }
        let reader = ByteReader(Array(tail.suffix(128)))
        guard reader.matches("TAG", at: 0) else { return TrackTags() }
        func field(_ offset: Int, _ length: Int) -> String? {
            reader.slice(offset, length).flatMap { TagText.cleaned(TagText.latin1($0)) }
        }
        var tags = TrackTags(title: field(3, 30), artist: field(33, 30), album: field(63, 30))
        tags.year = field(93, 4).flatMap(TagText.leadingNumber)
        // A zero before the last byte of the comment makes that byte the track.
        if reader.bytes[125] == 0, reader.bytes[126] != 0 {
            tags.trackNumber = Int(reader.bytes[126])
        }
        tags.genre = genreName(Int(reader.bytes[127]))
        return tags
    }

    /// How long an MP3 plays, from its first frame: exactly when the frame
    /// counts the frames, else as the file's size at the frame's bit rate.
    static func mp3Duration(_ reader: ByteReader, fileSize: Int) -> Double? {
        var offset = 0
        if reader.matches("ID3", at: 0), let size = reader.synchsafe32(6) {
            offset = 10 + size
        }
        // The first frame, within a little of where it should be.
        let limit = min(reader.count - 4, offset + 4096)
        while offset <= limit {
            if reader.bytes[offset] == 0xFF, reader.bytes[offset + 1] & 0xE0 == 0xE0 { break }
            offset += 1
        }
        guard offset <= limit else { return nil }
        let second = reader.bytes[offset + 1], third = reader.bytes[offset + 2], fourth = reader.bytes[offset + 3]
        let versionBits = (second >> 3) & 0x03, layerBits = (second >> 1) & 0x03
        // Only layer III, which is what an MP3 is.
        guard versionBits != 1, layerBits == 1 else { return nil }
        let isVersion1 = versionBits == 3
        let rates1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
        let rates2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0]
        let bitRate = (isVersion1 ? rates1 : rates2)[Int(third >> 4)] * 1000
        let baseRates = [44100, 48000, 32000, 0]
        var sampleRate = baseRates[Int((third >> 2) & 0x03)]
        if versionBits == 2 { sampleRate /= 2 } else if versionBits == 0 { sampleRate /= 4 }
        guard bitRate > 0, sampleRate > 0 else { return nil }
        let samplesPerFrame = isVersion1 ? 1152 : 576
        // A file of varying bit rate counts its frames after the first
        // frame's side information.
        let isMono = (fourth >> 6) == 3
        let side = isVersion1 ? (isMono ? 17 : 32) : (isMono ? 9 : 17)
        let info = offset + 4 + side
        if reader.matches("Xing", at: info) || reader.matches("Info", at: info),
           let flags = reader.big32(info + 4), flags & 1 != 0, let frames = reader.big32(info + 8), frames > 0 {
            return Double(frames * samplesPerFrame) / Double(sampleRate)
        }
        return Double(fileSize - offset) * 8 / Double(bitRate)
    }

    // MARK: Vorbis comments

    /// Comments as FLAC and Ogg keep them: the encoder's name, a count,
    /// then values of `NAME=value`, each after its length.
    static func vorbisComments(_ reader: ByteReader, at start: Int) -> TrackTags {
        var tags = TrackTags()
        guard let vendor = reader.little32(start), let count = reader.little32(start + 4 + vendor) else { return tags }
        var offset = start + 8 + vendor
        for _ in 0..<min(count, 1000) {
            guard let length = reader.little32(offset), let value = reader.slice(offset + 4, length) else { break }
            offset += 4 + length
            let text = TagText.utf8(value)
            guard let equals = text.firstIndex(of: "=") else { continue }
            tags.set(String(text[..<equals]), String(text[text.index(after: equals)...]))
        }
        return tags
    }

    /// A FLAC file: blocks of a kind and a length. The first says how long
    /// the stream is; the comments are in a later one.
    static func flac(_ reader: ByteReader) -> TrackTags {
        var tags = TrackTags()
        var duration: Double?
        var offset = 4
        while let header = reader.big32(offset) {
            let isLast = header >> 31 == 1, kind = (header >> 24) & 0x7F, length = header & 0xFF_FFFF
            let body = offset + 4
            if kind == 0, reader.has(18, at: body) {
                // 20 bits of sample rate, 3 of channels, 5 of depth, then 36
                // of how many samples there are.
                let rate = Int(reader.bytes[body + 10]) << 12 | Int(reader.bytes[body + 11]) << 4 | Int(reader.bytes[body + 12]) >> 4
                let samples = Int(reader.bytes[body + 13] & 0x0F) << 32 | (reader.big32(body + 14) ?? 0)
                if rate > 0, samples > 0 { duration = Double(samples) / Double(rate) }
            } else if kind == 4 {
                tags = vorbisComments(reader, at: body)
            }
            offset = body + length
            if isLast { break }
        }
        tags.duration = duration
        return tags
    }

    /// An Ogg file, Vorbis or Opus: the comments follow a marker in the
    /// second packet. A page's header in the middle of long comments isn't
    /// stepped over, so those are read as far as it.
    static func ogg(_ reader: ByteReader) -> TrackTags {
        if let marker = reader.find([0x03] + Array("vorbis".utf8)) {
            return vorbisComments(reader, at: marker + 7)
        }
        if let marker = reader.find(Array("OpusTags".utf8)) {
            return vorbisComments(reader, at: marker + 8)
        }
        return TrackTags()
    }

    // MARK: WAV

    /// A WAV file: chunks of a name and a length. `fmt ` has the rate of
    /// bytes, `data` the sound, and `LIST` of `INFO` the tags.
    static func wav(_ reader: ByteReader) -> TrackTags {
        var tags = TrackTags()
        var byteRate: Int?
        var offset = 12
        while reader.has(8, at: offset), let length = reader.little32(offset + 4) {
            let body = offset + 8
            if reader.matches("fmt ", at: offset) {
                byteRate = reader.little32(body + 8)
            } else if reader.matches("data", at: offset) {
                if let byteRate, byteRate > 0 { tags.duration = Double(length) / Double(byteRate) }
            } else if reader.matches("LIST", at: offset), reader.matches("INFO", at: body) {
                var inner = body + 4
                let end = min(reader.count, body + length)
                while inner + 8 <= end, let size = reader.little32(inner + 4), let value = reader.slice(inner + 8, min(size, end - inner - 8)) {
                    let text = TagText.utf8(value)
                    if reader.matches("INAM", at: inner) { tags.set("TITLE", text) }
                    if reader.matches("IART", at: inner) { tags.set("ARTIST", text) }
                    if reader.matches("IPRD", at: inner) { tags.set("ALBUM", text) }
                    if reader.matches("ICRD", at: inner) { tags.set("DATE", text) }
                    if reader.matches("IGNR", at: inner) { tags.set("GENRE", text) }
                    if reader.matches("ITRK", at: inner) { tags.set("TRACKNUMBER", text) }
                    inner += 8 + size + size % 2
                }
            }
            // Chunks are padded to an even length.
            offset = body + length + length % 2
        }
        return tags
    }

    // MARK: MPEG-4

    /// An MPEG-4 file: boxes inside boxes. The tags are under
    /// `moov/udta/meta/ilst`, and the length under `moov/mvhd`.
    static func mp4(_ reader: ByteReader) -> TrackTags {
        var tags = TrackTags()

        /// The boxes directly between two offsets, by name.
        func boxes(from start: Int, to end: Int) -> [(name: String, body: Int, end: Int)] {
            var found: [(String, Int, Int)] = []
            var offset = start
            while offset + 8 <= end, var size = reader.big32(offset), let name = reader.slice(offset + 4, 4) {
                var header = 8
                if size == 1 {
                    // A size too large for four bytes follows the name.
                    guard let high = reader.big32(offset + 8), let low = reader.big32(offset + 12), high == 0 else { break }
                    size = low
                    header = 16
                } else if size == 0 {
                    size = end - offset
                }
                guard size >= header else { break }
                found.append((TagText.latin1(name), offset + header, min(end, offset + size)))
                offset += size
            }
            return found
        }

        guard let moov = boxes(from: 0, to: reader.count).first(where: { $0.name == "moov" }) else { return tags }
        let inMoov = boxes(from: moov.body, to: moov.end)
        if let header = inMoov.first(where: { $0.name == "mvhd" }) {
            // The time scale and the length, 32 or 64 bits by the version.
            let isLong = reader.has(1, at: header.body) && reader.bytes[header.body] == 1
            let scale = reader.big32(header.body + (isLong ? 20 : 12))
            let length = isLong ? reader.big32(header.body + 28) : reader.big32(header.body + 16)
            if let scale, let length, scale > 0, length > 0 { tags.duration = Double(length) / Double(scale) }
        }
        guard let udta = inMoov.first(where: { $0.name == "udta" }),
              let meta = boxes(from: udta.body, to: udta.end).first(where: { $0.name == "meta" }),
              // `meta` has four bytes of version and flags before its boxes.
              let list = boxes(from: meta.body + 4, to: meta.end).first(where: { $0.name == "ilst" }) else { return tags }
        for item in boxes(from: list.body, to: list.end) {
            guard let data = boxes(from: item.body, to: item.end).first(where: { $0.name == "data" }),
                  let value = reader.slice(data.body + 8, data.end - data.body - 8) else { continue }
            switch item.name {
            case "\u{A9}nam": tags.set("TITLE", TagText.utf8(value))
            case "\u{A9}ART": tags.set("ARTIST", TagText.utf8(value))
            case "\u{A9}alb": tags.set("ALBUM", TagText.utf8(value))
            case "\u{A9}day": tags.set("DATE", TagText.utf8(value))
            case "\u{A9}gen": tags.set("GENRE", TagText.utf8(value))
            case "trkn":
                // Two zero bytes, then the number in two.
                if value.count >= 4 { tags.trackNumber = Int(value[2]) << 8 | Int(value[3]) }
            default: break
            }
        }
        return tags
    }
}
