//
//  Document.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import FilesCore
import Foundation
import TextCore

/// Why a file isn't opened.
enum DocumentFailure: Error {
    case tooLarge(Int)
    case notText
    case system(String)

    var message: String {
        switch self {
        case let .tooLarge(bytes): "This file is \(ByteCount.format(Int64(bytes))), more than the editor opens."
        case .notText: "This file isn't text."
        case let .system(reason): reason
        }
    }
}

/// A text file being edited: its text, the edits made to it, and where it
/// is on disk.
@MainActor
final class Document: ObservableObject {

    /// The largest file opened. Larger ones wait for a text view that
    /// doesn't keep the whole file as one string.
    static let byteLimit = 5 << 20

    @Published private(set) var url: URL

    /// The text in the editor.
    @Published var text: String {
        didSet {
            guard text != history.current else { return }
            history.record(text, at: Self.now)
        }
    }

    @Published private(set) var history: EditHistory

    /// The file's encoding and line endings, kept for writing it back.
    @Published private(set) var file: TextFile

    /// What went wrong, shown until dismissed.
    @Published var failure: String?

    private static var now: Double {
        ProcessInfo.processInfo.systemUptime
    }

    init(url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.byteLimit else { throw DocumentFailure.tooLarge(size) }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocumentFailure.system(error.localizedDescription)
        }
        guard let read = try? TextFile(bytes: [UInt8](data)) else { throw DocumentFailure.notText }
        self.url = url
        file = read
        text = read.text
        history = EditHistory(read.text)
    }

    var name: String { url.lastPathComponent }

    var isModified: Bool { history.isModified }

    /// Writes the text to its file, in the file's encoding and with its
    /// line endings.
    func save() {
        var written = file
        written.text = text
        do {
            try Data(written.bytes).write(to: url, options: .atomic)
            // A text Latin-1 couldn't hold was written as UTF-8.
            if !written.canKeepEncoding { written.encoding = .utf8 }
            file = written
            history.markSaved()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// Writes the text to another file in the same folder, which becomes
    /// the document's.
    func save(as name: String) {
        let destination = url.deletingLastPathComponent().appendingPathComponent(name)
        guard destination.path == url.path || !FileManager.default.fileExists(atPath: destination.path) else {
            failure = "There is already a file named “\(name)”."
            return
        }
        url = destination
        save()
    }

    func undo() {
        if let previous = history.undo() { text = previous }
    }

    func redo() {
        if let next = history.redo() { text = next }
    }

    /// Replaces every match of a search.
    ///
    /// - Returns: How many were replaced.
    @discardableResult
    func replaceAll(_ search: TextSearch, with replacement: String) -> Int {
        let result = search.replacingAll(in: text, with: replacement)
        guard result.count > 0 else { return 0 }
        history.record(result.text, at: Self.now, isSeparate: true)
        text = result.text
        return result.count
    }

    func replace(_ match: TextMatch, of search: TextSearch, with replacement: String) {
        let result = search.replacing(match, in: text, with: replacement)
        guard result != text else { return }
        history.record(result, at: Self.now, isSeparate: true)
        text = result
    }

    /// Reads the file again, dropping the edits not saved.
    func revert() {
        guard let data = try? Data(contentsOf: url), let read = try? TextFile(bytes: [UInt8](data)) else {
            failure = "The file couldn't be read again."
            return
        }
        file = read
        history = EditHistory(read.text)
        text = read.text
    }

    func setLineEnding(_ ending: LineEnding) {
        file.lineEnding = ending
    }

    /// Makes a new, empty document in a folder.
    static func create(in folder: URL) throws -> URL {
        let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let url = folder.appendingPathComponent(DocumentName.untitled(among: taken))
        try Data().write(to: url, options: .withoutOverwriting)
        return url
    }
}

#endif
