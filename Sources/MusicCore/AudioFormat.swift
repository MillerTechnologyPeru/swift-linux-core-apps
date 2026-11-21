//
//  AudioFormat.swift
//  CoreApps
//

/// The kinds of audio file, told apart by how their first bytes go.
public enum AudioFormat: String, CaseIterable, Hashable, Sendable {
    case mp3
    case flac
    case ogg
    case wav
    case m4a

    /// The format's name as people write it.
    public var name: String {
        switch self {
        case .mp3: "MP3"
        case .flac: "FLAC"
        case .ogg: "Ogg"
        case .wav: "WAV"
        case .m4a: "MPEG-4"
        }
    }

    /// The format of a file that starts with some bytes, if it's one known.
    public init?(header bytes: [UInt8]) {
        let reader = ByteReader(bytes)
        if reader.matches("fLaC", at: 0) {
            self = .flac
        } else if reader.matches("OggS", at: 0) {
            self = .ogg
        } else if reader.matches("RIFF", at: 0), reader.matches("WAVE", at: 8) {
            self = .wav
        } else if reader.matches("ftyp", at: 4) {
            self = .m4a
        } else if reader.matches("ID3", at: 0) {
            self = .mp3
        } else if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] & 0xE0 == 0xE0, bytes[1] & 0x06 != 0 {
            // An MPEG audio frame's sync bits, with a layer that exists.
            self = .mp3
        } else {
            return nil
        }
    }
}
