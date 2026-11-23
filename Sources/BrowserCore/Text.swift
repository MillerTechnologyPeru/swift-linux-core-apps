//
//  Text.swift
//  CoreApps
//

/// Byte-level text helpers. URLs and what's typed into the address bar are
/// worked on as UTF-8, which is what they are on the wire, and nothing
/// here needs Foundation.
enum Text {

    static func isASCIILetter(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z")) || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
    }

    static func isASCIIDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r")
    }

    /// ASCII letters lowercased; everything else as it is.
    static func asciiLowercased(_ text: String) -> String {
        String(decoding: asciiLowercased(Array(text.utf8)), as: UTF8.self)
    }

    static func asciiLowercased(_ bytes: [UInt8]) -> [UInt8] {
        bytes.map { $0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z") ? $0 + 32 : $0 }
    }

    /// The text without the whitespace at either end.
    static func trimmed(_ text: String) -> String {
        let bytes = Array(text.utf8)
        guard let first = bytes.firstIndex(where: { !isWhitespace($0) }),
              let last = bytes.lastIndex(where: { !isWhitespace($0) }) else {
            return ""
        }
        return String(decoding: bytes[first...last], as: UTF8.self)
    }

    /// The text after its first `count` bytes.
    static func dropping(_ count: Int, from text: String) -> String {
        String(decoding: Array(text.utf8.dropFirst(count)), as: UTF8.self)
    }

    /// Whether `needle` is in `haystack`, both bytes.
    static func contains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty else { return true }
        guard haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            if haystack[start..<(start + needle.count)].elementsEqual(needle) {
                return true
            }
        }
        return false
    }

    static func hasPrefix(_ bytes: [UInt8], _ prefix: [UInt8]) -> Bool {
        bytes.count >= prefix.count && bytes[..<prefix.count].elementsEqual(prefix)
    }

    static func hasSuffix(_ bytes: [UInt8], _ suffix: [UInt8]) -> Bool {
        bytes.count >= suffix.count && bytes[(bytes.count - suffix.count)...].elementsEqual(suffix)
    }

    /// For matching what's typed against titles and addresses: ASCII
    /// letters lowercased, so case is ignored.
    static func folded(_ text: String) -> [UInt8] {
        asciiLowercased(Array(text.utf8))
    }

    /// Whether a word of `text` starts with `prefix`; words are split at
    /// anything that isn't a letter or digit.
    static func hasWordPrefix(_ text: [UInt8], _ prefix: [UInt8]) -> Bool {
        guard !prefix.isEmpty else { return true }
        var atWordStart = true
        for index in text.indices {
            let byte = text[index]
            let isWordByte = isASCIILetter(byte) || isASCIIDigit(byte) || byte >= 0x80
            if isWordByte, atWordStart, hasPrefix(Array(text[index...]), prefix) {
                return true
            }
            atWordStart = !isWordByte
        }
        return false
    }
}
