//
//  ImageFormat.swift
//  CoreApps
//

/// The kinds of image file, told apart by how their first bytes go.
public enum ImageFormat: String, CaseIterable, Hashable, Sendable {
    case png
    case jpeg
    case gif
    case webp
    case bmp
    case tiff
    case heif

    /// The format's name as people write it.
    public var name: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .gif: "GIF"
        case .webp: "WebP"
        case .bmp: "BMP"
        case .tiff: "TIFF"
        case .heif: "HEIF"
        }
    }

    /// The format of a file that starts with some bytes, if it's one known.
    public init?(header bytes: [UInt8]) {
        func starts(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            bytes.count >= offset + signature.count && Array(bytes[offset..<(offset + signature.count)]) == signature
        }
        if starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            self = .png
        } else if starts([0xFF, 0xD8, 0xFF]) {
            self = .jpeg
        } else if starts(Array("GIF87a".utf8)) || starts(Array("GIF89a".utf8)) {
            self = .gif
        } else if starts(Array("RIFF".utf8)), starts(Array("WEBP".utf8), at: 8) {
            self = .webp
        } else if starts(Array("BM".utf8)) {
            self = .bmp
        } else if starts([0x49, 0x49, 0x2A, 0x00]) || starts([0x4D, 0x4D, 0x00, 0x2A]) {
            self = .tiff
        } else if starts(Array("ftyp".utf8), at: 4), bytes.count >= 12 {
            // The brand says which of the ISO family the file is.
            let brand = String(decoding: bytes[8..<12], as: UTF8.self)
            guard ["heic", "heix", "hevc", "heim", "heis", "mif1", "msf1", "avif"].contains(brand) else { return nil }
            self = .heif
        } else {
            return nil
        }
    }
}

/// How large an image is, in pixels.
public struct PixelSize: Hashable, Sendable {

    public var width: Int

    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Reads an image's size from the start of its file, without decoding
    /// it: enough of the file for its header. `nil` for a format whose
    /// header isn't read here (TIFF and HEIF), or a file cut short.
    public init?(header bytes: [UInt8]) {
        guard let format = ImageFormat(header: bytes) else { return nil }
        func big16(_ offset: Int) -> Int? {
            bytes.count >= offset + 2 ? Int(bytes[offset]) << 8 | Int(bytes[offset + 1]) : nil
        }
        func big32(_ offset: Int) -> Int? {
            guard bytes.count >= offset + 4 else { return nil }
            return Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
        }
        func little16(_ offset: Int) -> Int? {
            bytes.count >= offset + 2 ? Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 : nil
        }
        func little24(_ offset: Int) -> Int? {
            bytes.count >= offset + 3 ? Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 : nil
        }
        func little32(_ offset: Int) -> Int? {
            guard bytes.count >= offset + 4 else { return nil }
            return Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }
        var size: (Int, Int)?
        switch format {
        case .png:
            // The IHDR chunk comes first: its width and height are at 16.
            if let width = big32(16), let height = big32(20) { size = (width, height) }
        case .gif:
            if let width = little16(6), let height = little16(8) { size = (width, height) }
        case .bmp:
            // The height is negative for rows stored top first.
            if let width = little32(18), let height = little32(22) {
                let signed = Int(Int32(truncatingIfNeeded: height))
                size = (width, abs(signed))
            }
        case .jpeg:
            // Segments follow one another, each a marker and a length,
            // until the start of frame, which has the size.
            var offset = 2
            while offset + 4 <= bytes.count {
                guard bytes[offset] == 0xFF else { offset += 1; continue }
                let marker = bytes[offset + 1]
                if marker == 0xFF { offset += 1; continue }
                // Markers that stand alone, without a length.
                if marker == 0xD8 || marker == 0x01 || (0xD0...0xD7).contains(marker) { offset += 2; continue }
                let isFrame = (0xC0...0xCF).contains(marker) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
                if isFrame {
                    if let height = big16(offset + 5), let width = big16(offset + 7) { size = (width, height) }
                    break
                }
                guard let length = big16(offset + 2), length >= 2 else { break }
                offset += 2 + length
            }
        case .webp:
            guard bytes.count >= 16 else { break }
            let chunk = String(decoding: bytes[12..<16], as: UTF8.self)
            switch chunk {
            case "VP8X":
                if let width = little24(24), let height = little24(27) { size = (width + 1, height + 1) }
            case "VP8 ":
                if let width = little16(26), let height = little16(28) { size = (width & 0x3FFF, height & 0x3FFF) }
            case "VP8L":
                if let bits = little32(21) {
                    size = ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
                }
            default:
                break
            }
        case .tiff, .heif:
            break
        }
        guard let size, size.0 > 0, size.1 > 0 else { return nil }
        self.init(width: size.0, height: size.1)
    }
}
