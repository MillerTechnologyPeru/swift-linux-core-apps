//
//  VideoLocation.swift
//  CoreApps
//

/// Where a video is: a file, or an address on the web. What someone
/// types or passes on the command line is read as one or the other.
public enum VideoLocation: Hashable, Sendable {

    /// A file's path.
    case file(String)

    /// An `http` or `https` address.
    case web(String)

    /// Reads what was typed: an address with a scheme the player streams,
    /// a `file://` address, or a path. Spaces around it are dropped;
    /// nothing, or another scheme, is `nil`.
    public init?(_ text: String) {
        let trimmed = Self.trimmed(text)
        guard !trimmed.isEmpty else { return nil }
        let lower = Self.asciiLowercased(trimmed)
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            // An address needs a host after its scheme.
            let rest = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            guard rest.count >= 2 else { return nil }
            self = .web(trimmed)
        } else if lower.hasPrefix("file://") {
            let path = Self.percentDecoded(String(trimmed.dropFirst(7)))
            guard path.hasPrefix("/") else { return nil }
            self = .file(path)
        } else if Self.hasScheme(trimmed) {
            return nil
        } else {
            self = .file(trimmed)
        }
    }

    /// The title to show: the file's name, or the address's last part,
    /// without its extension or query.
    public var title: String {
        let path: String
        switch self {
        case .file(let file):
            path = file
        case .web(let address):
            var withoutQuery = address
            if let mark = withoutQuery.firstIndex(where: { $0 == "?" || $0 == "#" }) {
                withoutQuery = String(withoutQuery[..<mark])
            }
            path = Self.percentDecoded(withoutQuery)
        }
        let parts = path.split(separator: "/")
        guard let last = parts.last else { return path }
        // An address with nothing after its host is named by its host.
        if case .web = self, parts.count <= 2 { return String(last) }
        let name = String(last)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name }
        return String(name[..<dot])
    }

    /// The file's extension, lowercased, or the address's.
    public var fileExtension: String? {
        let name = lastComponent
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        let ext = Self.asciiLowercased(String(name[name.index(after: dot)...]))
        return ext.isEmpty ? nil : ext
    }

    /// Whether the extension is one of a video the player expects, or
    /// there's none to go by (as for many addresses).
    public var looksLikeVideo: Bool {
        guard let ext = fileExtension else {
            if case .web = self { return true }
            return false
        }
        return Self.videoExtensions.contains(ext)
    }

    /// The extensions of the videos people keep, as GStreamer and
    /// AVFoundation play them.
    public static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "webm", "avi", "ogv", "ogg", "mpg", "mpeg", "ts", "m2ts", "3gp", "wmv", "flv",
    ]

    /// The MIME type the extension stands for, for a host that asks.
    public var mimeType: String? {
        switch fileExtension {
        case "mp4", "m4v": "video/mp4"
        case "mov": "video/quicktime"
        case "mkv": "video/x-matroska"
        case "webm": "video/webm"
        case "avi": "video/x-msvideo"
        case "ogv", "ogg": "video/ogg"
        case "mpg", "mpeg": "video/mpeg"
        case "ts", "m2ts": "video/mp2t"
        case "3gp": "video/3gpp"
        default: nil
        }
    }

    private var lastComponent: String {
        let path: String
        switch self {
        case .file(let file): path = file
        case .web(let address):
            var withoutQuery = address
            if let mark = withoutQuery.firstIndex(where: { $0 == "?" || $0 == "#" }) {
                withoutQuery = String(withoutQuery[..<mark])
            }
            let parts = withoutQuery.split(separator: "/")
            // The host alone has no extension.
            guard parts.count > 2 else { return "" }
            path = withoutQuery
        }
        return path.split(separator: "/").last.map(String.init) ?? ""
    }

    /// Whether `text` has `://` in it, as an address of another scheme
    /// does. Embedded Swift has no substring search.
    static func hasScheme(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        guard bytes.count >= 3 else { return false }
        for index in 0...(bytes.count - 3)
        where bytes[index] == UInt8(ascii: ":") && bytes[index + 1] == UInt8(ascii: "/") && bytes[index + 2] == UInt8(ascii: "/") {
            return true
        }
        return false
    }

    /// A to Z as a to z, and nothing else changed: schemes and extensions
    /// are ASCII.
    static func asciiLowercased(_ text: String) -> String {
        String(decoding: text.utf8.map { $0 >= 65 && $0 <= 90 ? $0 + 32 : $0 }, as: UTF8.self)
    }

    private static func trimmed(_ text: String) -> String {
        var scalars = Substring(text)
        while let first = scalars.first, first == " " || first == "\t" || first == "\n" || first == "\r" {
            scalars = scalars.dropFirst()
        }
        while let last = scalars.last, last == " " || last == "\t" || last == "\n" || last == "\r" {
            scalars = scalars.dropLast()
        }
        return String(scalars)
    }

    /// `%20` and the rest as the bytes they stand for, in UTF-8; a `%`
    /// that isn't followed by two hex digits is kept.
    static func percentDecoded(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var decoded: [UInt8] = []
        decoded.reserveCapacity(bytes.count)
        var index = 0
        func hex(_ byte: UInt8) -> UInt8? {
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
            default: nil
            }
        }
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "%"), index + 2 < bytes.count,
               let high = hex(bytes[index + 1]), let low = hex(bytes[index + 2]) {
                decoded.append(high << 4 | low)
                index += 3
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: decoded, as: UTF8.self)
    }
}
