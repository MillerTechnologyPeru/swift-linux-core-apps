//
//  TextFile.swift
//  CoreApps
//

/// How a text file's bytes stand for its characters.
public enum TextEncoding: String, CaseIterable, Hashable, Sendable {
    case utf8
    /// UTF-8 with a byte order mark before the text.
    case utf8WithMark
    case utf16LittleEndian
    case utf16BigEndian
    /// Latin-1: what a file is read as when it's none of the others.
    case latin1

    public var name: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf8WithMark: "UTF-8 with BOM"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .latin1: "Latin-1"
        }
    }
}

/// How a text file ends its lines.
public enum LineEnding: String, CaseIterable, Hashable, Sendable {
    /// A line feed, as Unix has it.
    case lineFeed
    /// A carriage return and a line feed, as Windows has it.
    case carriageReturnLineFeed
    /// A carriage return, as old Macs had it.
    case carriageReturn

    public var name: String {
        switch self {
        case .lineFeed: "Unix (LF)"
        case .carriageReturnLineFeed: "Windows (CRLF)"
        case .carriageReturn: "Classic Mac (CR)"
        }
    }

    var text: String {
        switch self {
        case .lineFeed: "\n"
        case .carriageReturnLineFeed: "\r\n"
        case .carriageReturn: "\r"
        }
    }
}

/// A text file read into memory: its text with every line ending a line
/// feed, and what it takes to write it back as it was.
public struct TextFile: Hashable, Sendable {

    public var text: String

    public var encoding: TextEncoding

    public var lineEnding: LineEnding

    public init(text: String = "", encoding: TextEncoding = .utf8, lineEnding: LineEnding = .lineFeed) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
    }

    /// Why bytes aren't read as text.
    public enum Failure: Error, Hashable, Sendable {
        /// The file has zero bytes in it, as programs and pictures do.
        case binary
    }

    /// Reads a file's bytes as text, working out its encoding and how it
    /// ends its lines.
    public init(bytes: [UInt8]) throws {
        var encoding = TextEncoding.utf8
        var body = bytes[...]
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            encoding = .utf8WithMark
            body = bytes.dropFirst(3)
        } else if bytes.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LittleEndian
            body = bytes.dropFirst(2)
        } else if bytes.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BigEndian
            body = bytes.dropFirst(2)
        }
        var text: String
        switch encoding {
        case .utf16LittleEndian, .utf16BigEndian:
            var units: [UInt16] = []
            units.reserveCapacity(body.count / 2)
            var index = body.startIndex
            while index + 1 < body.endIndex {
                let first = UInt16(body[index]), second = UInt16(body[index + 1])
                units.append(encoding == .utf16BigEndian ? first << 8 | second : second << 8 | first)
                index += 2
            }
            text = String(decoding: units, as: UTF16.self)
        default:
            guard !body.contains(0) else { throw Failure.binary }
            if let valid = Self.utf8(body) {
                text = valid
            } else {
                // Not UTF-8: every byte is a character of its number.
                encoding = .latin1
                text = ""
                text.unicodeScalars.append(contentsOf: body.map { Unicode.Scalar($0) })
            }
        }
        lineEnding = Self.lineEnding(of: text)
        self.encoding = encoding
        self.text = Self.normalized(text)
    }

    /// Bytes as UTF-8, or `nil` if they aren't.
    static func utf8(_ bytes: ArraySlice<UInt8>) -> String? {
        var decoder = UTF8()
        var iterator = bytes.makeIterator()
        var scalars = String.UnicodeScalarView()
        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar): scalars.append(scalar)
            case .emptyInput: return String(scalars)
            case .error: return nil
            }
        }
    }

    /// The line ending a text uses most.
    static func lineEnding(of text: String) -> LineEnding {
        var feeds = 0, returns = 0, both = 0
        var previous: Unicode.Scalar?
        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                if previous == "\r" {
                    both += 1
                    returns -= 1
                } else {
                    feeds += 1
                }
            } else if scalar == "\r" {
                returns += 1
            }
            previous = scalar
        }
        if both > feeds, both >= returns { return .carriageReturnLineFeed }
        if returns > feeds { return .carriageReturn }
        return .lineFeed
    }

    /// A text with every line ending made a line feed.
    static func normalized(_ text: String) -> String {
        guard text.unicodeScalars.contains("\r") else { return text }
        var result = String.UnicodeScalarView()
        var previous: Unicode.Scalar?
        for scalar in text.unicodeScalars {
            if scalar == "\r" {
                result.append("\n")
            } else if scalar == "\n", previous == "\r" {
                // The line feed of a pair, already written.
            } else {
                result.append(scalar)
            }
            previous = scalar
        }
        return String(result)
    }

    /// The file's bytes, in its encoding and with its line endings.
    public var bytes: [UInt8] {
        var scalars = String.UnicodeScalarView()
        if lineEnding == .lineFeed {
            scalars = text.unicodeScalars
        } else {
            for scalar in text.unicodeScalars {
                if scalar == "\n" {
                    scalars.append(contentsOf: lineEnding.text.unicodeScalars)
                } else {
                    scalars.append(scalar)
                }
            }
        }
        let written = String(scalars)
        switch encoding {
        case .utf8:
            return Array(written.utf8)
        case .utf8WithMark:
            return [0xEF, 0xBB, 0xBF] + Array(written.utf8)
        case .utf16LittleEndian:
            return [0xFF, 0xFE] + written.utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
        case .utf16BigEndian:
            return [0xFE, 0xFF] + written.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        case .latin1:
            // A character Latin-1 hasn't got can't be written in it: the
            // file becomes UTF-8 instead, which `canKeepEncoding` warns of.
            guard canKeepEncoding else { return Array(written.utf8) }
            return written.unicodeScalars.map { UInt8($0.value) }
        }
    }

    /// Whether the text can still be written in the file's encoding.
    public var canKeepEncoding: Bool {
        encoding != .latin1 || text.unicodeScalars.allSatisfy { $0.value < 256 }
    }
}
