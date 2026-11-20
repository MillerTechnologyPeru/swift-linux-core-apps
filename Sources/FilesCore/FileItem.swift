//
//  FileItem.swift
//  CoreApps
//

import Foundation

/// What a file is, as far as its name says: which symbol it gets, and
/// later which app opens it.
public enum FileKind: String, Hashable, Sendable {
    case folder
    case image
    case audio
    case video
    case text
    case archive
    case document
    case other

    /// The kind of a file with a name extension, without its dot.
    public init(pathExtension: String) {
        switch pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "svg":
            self = .image
        case "mp3", "m4a", "aac", "flac", "ogg", "opus", "wav":
            self = .audio
        case "mp4", "m4v", "mov", "mkv", "webm", "avi":
            self = .video
        case "txt", "md", "json", "xml", "yaml", "yml", "toml", "csv", "log", "swift", "c", "h", "py", "sh", "html", "css", "js":
            self = .text
        case "zip", "tar", "gz", "xz", "bz2", "zst", "7z":
            self = .archive
        case "pdf", "doc", "docx", "odt", "rtf", "xls", "xlsx", "ods", "ppt", "pptx", "odp":
            self = .document
        default:
            self = .other
        }
    }

    /// The name of the symbol that stands for the kind.
    public var symbolName: String {
        switch self {
        case .folder: "folder"
        case .image: "photo"
        case .audio: "play"
        case .video: "play"
        case .text: "doc"
        case .archive: "tray"
        case .document: "doc"
        case .other: "doc"
        }
    }
}

/// A file or folder in a listing.
public struct FileItem: Identifiable, Hashable, Sendable {

    public var url: URL

    public var name: String

    public var kind: FileKind

    /// The file's size in bytes; `nil` for a folder.
    public var size: Int64?

    public var modified: Date?

    /// Whether the name starts with a dot.
    public var isHidden: Bool

    public var id: URL { url }

    public var isFolder: Bool { kind == .folder }

    public init(url: URL, name: String, kind: FileKind, size: Int64? = nil, modified: Date? = nil, isHidden: Bool = false) {
        self.url = url
        self.name = name
        self.kind = kind
        self.size = size
        self.modified = modified
        self.isHidden = isHidden
    }
}
