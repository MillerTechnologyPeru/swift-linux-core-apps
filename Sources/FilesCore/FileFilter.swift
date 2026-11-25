//
//  FileFilter.swift
//  CoreApps
//

import Foundation

/// A kind of file a file chooser offers to show, as apps describe one to
/// the desktop's portal: a name, and the name patterns and MIME types that
/// belong to it.
public struct FileFilter: Hashable, Sendable {

    /// What a filter matches files by.
    public enum Rule: Hashable, Sendable {

        /// A shell pattern for the whole name: `*.png`, `*.[jJ][pP][gG]`,
        /// `Report-??.txt`.
        case glob(String)

        /// A MIME type, or a family of them: `image/png`, `image/*`.
        case mimeType(String)
    }

    /// What the user sees, such as “Images”.
    public var name: String

    public var rules: [Rule]

    public init(name: String, rules: [Rule]) {
        self.name = name
        self.rules = rules
    }

    /// Whether a file with this name is of the kind. Folders aren't asked:
    /// a chooser always shows them, to go into.
    public func matches(_ fileName: String) -> Bool {
        rules.contains { rule in
            switch rule {
            case let .glob(pattern):
                FileFilter.glob(pattern, matches: fileName)
            case let .mimeType(type):
                MIMEType.guess(forFileName: fileName).map { MIMEType.is($0, a: type) } ?? false
            }
        }
    }

    /// Whether a name fits a shell pattern, whatever the case of its
    /// letters: `*` stands for any run of characters, `?` for one, and
    /// `[…]` for one of those inside (`[!…]` for one not inside).
    public static func glob(_ pattern: String, matches name: String) -> Bool {
        let pattern = Array(pattern.lowercased()), name = Array(name.lowercased())
        return match(pattern[...], name[...])
    }

    private static func match(_ pattern: ArraySlice<Character>, _ name: ArraySlice<Character>) -> Bool {
        var pattern = pattern, name = name
        while let token = pattern.first {
            switch token {
            case "*":
                pattern = pattern.dropFirst()
                // Collapse runs of stars, then try every split.
                while pattern.first == "*" { pattern = pattern.dropFirst() }
                if pattern.isEmpty { return true }
                var rest = name
                while true {
                    if match(pattern, rest) { return true }
                    guard !rest.isEmpty else { return false }
                    rest = rest.dropFirst()
                }
            case "?":
                guard !name.isEmpty else { return false }
                pattern = pattern.dropFirst()
                name = name.dropFirst()
            case "[":
                guard let character = name.first,
                      let close = pattern.dropFirst(2).firstIndex(of: "]") else {
                    // An unclosed bracket stands for itself.
                    guard name.first == "[" else { return false }
                    pattern = pattern.dropFirst()
                    name = name.dropFirst()
                    continue
                }
                var set = pattern[pattern.index(after: pattern.startIndex) ..< close]
                let negated = set.first == "!" || set.first == "^"
                if negated { set = set.dropFirst() }
                guard set.contains(character) != negated else { return false }
                pattern = pattern[pattern.index(after: close)...]
                name = name.dropFirst()
            default:
                guard name.first == token else { return false }
                pattern = pattern.dropFirst()
                name = name.dropFirst()
            }
        }
        return name.isEmpty
    }
}

/// MIME types, as far as a file's name tells them.
public enum MIMEType {

    /// The types of the name extensions a desktop meets most, lower case.
    static let byExtension: [String: String] = [
        // Images
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp",
        "svg": "image/svg+xml", "bmp": "image/bmp", "tif": "image/tiff", "tiff": "image/tiff", "heic": "image/heic",
        "ico": "image/vnd.microsoft.icon",
        // Text
        "txt": "text/plain", "md": "text/markdown", "csv": "text/csv", "html": "text/html", "htm": "text/html",
        "css": "text/css", "xml": "application/xml", "json": "application/json", "yaml": "application/yaml",
        "yml": "application/yaml", "toml": "application/toml", "log": "text/x-log", "vcf": "text/vcard",
        "ics": "text/calendar", "swift": "text/x-swift", "c": "text/x-csrc", "h": "text/x-chdr",
        "cpp": "text/x-c++src", "py": "text/x-python", "js": "text/javascript", "sh": "application/x-shellscript",
        "rs": "text/rust", "go": "text/x-go",
        // Documents
        "pdf": "application/pdf", "odt": "application/vnd.oasis.opendocument.text",
        "ods": "application/vnd.oasis.opendocument.spreadsheet",
        "odp": "application/vnd.oasis.opendocument.presentation",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "doc": "application/msword", "rtf": "application/rtf",
        // Sound and video
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "aac": "audio/aac", "flac": "audio/flac", "ogg": "audio/ogg",
        "opus": "audio/ogg", "wav": "audio/x-wav", "mp4": "video/mp4", "m4v": "video/mp4", "mov": "video/quicktime",
        "mkv": "video/x-matroska", "webm": "video/webm", "avi": "video/x-msvideo",
        // Archives
        "zip": "application/zip", "tar": "application/x-tar", "gz": "application/gzip", "xz": "application/x-xz",
        "bz2": "application/x-bzip2", "zst": "application/zstd", "7z": "application/x-7z-compressed",
    ]

    /// Types that are kinds of others, beyond a `text/` type being plain
    /// text: what `is(_:a:)` follows.
    static let parents: [String: String] = [
        "application/xml": "text/plain", "application/json": "text/plain", "application/yaml": "text/plain",
        "application/toml": "text/plain", "application/x-shellscript": "text/plain", "image/svg+xml": "application/xml",
        "text/vcard": "text/plain", "text/x-vcard": "text/plain",
    ]

    /// Other names apps use for the same type.
    static let aliases: [String: String] = [
        "text/x-vcard": "text/vcard", "text/directory": "text/vcard", "image/jpg": "image/jpeg",
        "application/x-gzip": "application/gzip", "text/xml": "application/xml", "application/javascript": "text/javascript",
    ]

    /// The type of a file, from its name extension.
    public static func guess(forFileName name: String) -> String? {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : byExtension[ext]
    }

    /// Whether a type is another, or a kind of it: `image/png` is
    /// `image/*`, and any `text/` type is `text/plain`.
    public static func `is`(_ type: String, a other: String) -> Bool {
        let type = canonical(type), other = canonical(other)
        if other == "*/*" || other == "application/octet-stream" { return true }
        if other.hasSuffix("/*") { return type.hasPrefix(other.dropLast()) }
        var current: String? = type
        var steps = 0
        while let candidate = current, steps < 8 {
            if candidate == other { return true }
            current = parents[candidate] ?? (candidate.hasPrefix("text/") && candidate != "text/plain" ? "text/plain" : nil)
            steps += 1
        }
        return false
    }

    private static func canonical(_ type: String) -> String {
        let type = type.lowercased()
        return aliases[type] ?? type
    }
}
