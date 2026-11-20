//
//  Bytes.swift
//  CoreApps
//

/// Reading numbers and text out of a file's bytes.
struct ByteReader {

    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var count: Int { bytes.count }

    func has(_ length: Int, at offset: Int) -> Bool {
        offset >= 0 && length >= 0 && offset + length <= bytes.count
    }

    func big16(_ offset: Int) -> Int? {
        has(2, at: offset) ? Int(bytes[offset]) << 8 | Int(bytes[offset + 1]) : nil
    }

    func big24(_ offset: Int) -> Int? {
        has(3, at: offset) ? Int(bytes[offset]) << 16 | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) : nil
    }

    func big32(_ offset: Int) -> Int? {
        guard has(4, at: offset) else { return nil }
        return Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
    }

    func little16(_ offset: Int) -> Int? {
        has(2, at: offset) ? Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 : nil
    }

    func little32(_ offset: Int) -> Int? {
        guard has(4, at: offset) else { return nil }
        return Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
    }

    /// Four 7-bit bytes, as ID3 writes sizes so that none looks like the
    /// start of an MP3 frame.
    func synchsafe32(_ offset: Int) -> Int? {
        guard has(4, at: offset) else { return nil }
        return Int(bytes[offset] & 0x7F) << 21 | Int(bytes[offset + 1] & 0x7F) << 14
            | Int(bytes[offset + 2] & 0x7F) << 7 | Int(bytes[offset + 3] & 0x7F)
    }

    func slice(_ offset: Int, _ length: Int) -> [UInt8]? {
        has(length, at: offset) ? Array(bytes[offset..<(offset + length)]) : nil
    }

    /// Whether the bytes at an offset are a text's, as ASCII.
    func matches(_ text: String, at offset: Int) -> Bool {
        let wanted = Array(text.utf8)
        return has(wanted.count, at: offset) && Array(bytes[offset..<(offset + wanted.count)]) == wanted
    }

    /// Where a run of bytes first appears at or after an offset.
    func find(_ pattern: [UInt8], from start: Int = 0) -> Int? {
        guard !pattern.isEmpty, bytes.count >= pattern.count, start >= 0 else { return nil }
        var index = start
        let last = bytes.count - pattern.count
        while index <= last {
            if bytes[index] == pattern[0], Array(bytes[index..<(index + pattern.count)]) == pattern {
                return index
            }
            index += 1
        }
        return nil
    }
}

/// Text in the encodings tags are written in.
enum TagText {

    static func utf8(_ bytes: [UInt8]) -> String {
        String(decoding: bytes, as: UTF8.self)
    }

    /// Latin-1: each byte is the Unicode scalar of its number.
    static func latin1(_ bytes: [UInt8]) -> String {
        var text = ""
        for byte in bytes { text.unicodeScalars.append(Unicode.Scalar(byte)) }
        return text
    }

    /// UTF-16, with a byte order mark saying which end comes first, or the
    /// order given when there's none.
    static func utf16(_ bytes: [UInt8], bigEndian: Bool = false) -> String {
        var bytes = bytes[...]
        var big = bigEndian
        if bytes.count >= 2 {
            if bytes[bytes.startIndex] == 0xFF, bytes[bytes.startIndex + 1] == 0xFE {
                big = false
                bytes = bytes.dropFirst(2)
            } else if bytes[bytes.startIndex] == 0xFE, bytes[bytes.startIndex + 1] == 0xFF {
                big = true
                bytes = bytes.dropFirst(2)
            }
        }
        var units: [UInt16] = []
        var index = bytes.startIndex
        while index + 1 < bytes.endIndex {
            let first = UInt16(bytes[index]), second = UInt16(bytes[index + 1])
            units.append(big ? first << 8 | second : second << 8 | first)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// A value as tags have it: without the zeros that end it, or the
    /// spaces around it.
    static func cleaned(_ text: String) -> String? {
        var scalars = Array(text.unicodeScalars)
        if let end = scalars.firstIndex(of: "\u{0}") { scalars = Array(scalars[..<end]) }
        func isSpace(_ scalar: Unicode.Scalar) -> Bool { scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" }
        while let last = scalars.last, isSpace(last) { scalars.removeLast() }
        while let first = scalars.first, isSpace(first) { scalars.removeFirst() }
        guard !scalars.isEmpty else { return nil }
        var result = ""
        result.unicodeScalars.append(contentsOf: scalars)
        return result
    }

    /// The number a text starts with: "3" and "3/12" are both 3.
    static func leadingNumber(_ text: String) -> Int? {
        var value = 0, digits = 0
        for scalar in text.unicodeScalars {
            guard scalar.value >= 48, scalar.value <= 57 else { break }
            value = value * 10 + Int(scalar.value - 48)
            digits += 1
            if digits > 9 { break }
        }
        return digits > 0 ? value : nil
    }
}
