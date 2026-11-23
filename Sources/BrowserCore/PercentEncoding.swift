//
//  PercentEncoding.swift
//  CoreApps
//

/// Percent-encoding, for a search's query.
public enum PercentEncoding {

    /// A query value as a form sends it: spaces as `+`, and every byte
    /// but the unreserved ones (`A-Z a-z 0-9 - . _ ~`) as `%XX`.
    public static func encodeQuery(_ text: String) -> String {
        var output: [UInt8] = []
        for byte in text.utf8 {
            if Text.isASCIILetter(byte) || Text.isASCIIDigit(byte)
                || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "~") {
                output.append(byte)
            } else if byte == UInt8(ascii: " ") {
                output.append(UInt8(ascii: "+"))
            } else {
                output.append(UInt8(ascii: "%"))
                output.append(hexDigit(byte >> 4))
                output.append(hexDigit(byte & 0x0F))
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// A query value back as text: `+` as a space and `%XX` as its byte.
    /// A `%` without two hex digits after it stays as it is.
    public static func decodeQuery(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "+") {
                output.append(UInt8(ascii: " "))
            } else if byte == UInt8(ascii: "%"), index + 2 < bytes.count,
                      let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                output.append(high << 4 | low)
                index += 2
            } else {
                output.append(byte)
            }
            index += 1
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func hexDigit(_ value: UInt8) -> UInt8 {
        value < 10 ? UInt8(ascii: "0") + value : UInt8(ascii: "A") + value - 10
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        default: nil
        }
    }
}
