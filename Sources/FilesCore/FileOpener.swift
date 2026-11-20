//
//  FileOpener.swift
//  CoreApps
//

import Foundation

/// Handing files to other programs: the one that opens a kind of file, a
/// terminal, the archivers.
public enum FileOpener {

    /// Where a program is, among the folders programs are looked for in.
    public static func find(_ program: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        let path = environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        for folder in path.split(separator: ":") {
            let url = URL(fileURLWithPath: String(folder), isDirectory: true).appendingPathComponent(program)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }

    #if os(macOS) || os(Linux)

    /// Runs a program, waiting for it if asked.
    ///
    /// - Returns: What it exited with, or 0 for one not waited for.
    @discardableResult
    static func run(_ program: URL, _ arguments: [String], in folder: URL? = nil, waits: Bool = false) throws -> Int32 {
        let process = Process()
        process.executableURL = program
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        guard waits else { return 0 }
        process.waitUntilExit()
        return process.terminationStatus
    }

    #endif

    /// Whether files can be opened in other programs here.
    public static var canOpen: Bool {
        #if os(macOS)
        true
        #elseif os(Linux)
        find("xdg-open") != nil
        #else
        false
        #endif
    }

    /// Opens a file with the program the desktop has for its kind.
    public static func open(_ file: URL) throws {
        #if os(macOS)
        try run(URL(fileURLWithPath: "/usr/bin/open"), [file.path])
        #elseif os(Linux)
        guard let opener = find("xdg-open") else {
            throw FileOperations.Failure.unsupported("There is nothing to open files with.")
        }
        try run(opener, [file.path])
        #else
        throw FileOperations.Failure.unsupported("Files can't be opened in other apps here.")
        #endif
    }

    /// The terminals looked for, in order of preference.
    static let terminals = ["x-terminal-emulator", "kgx", "gnome-terminal", "ptyxis", "konsole", "foot", "alacritty", "xterm"]

    /// Whether a terminal can be opened here.
    public static var canOpenTerminal: Bool {
        #if os(macOS)
        true
        #elseif os(Linux)
        terminals.contains { find($0) != nil }
        #else
        false
        #endif
    }

    /// Opens a terminal in a folder.
    public static func openTerminal(in folder: URL) throws {
        #if os(macOS)
        try run(URL(fileURLWithPath: "/usr/bin/open"), ["-a", "Terminal", folder.path])
        #elseif os(Linux)
        guard let terminal = terminals.lazy.compactMap({ find($0) }).first else {
            throw FileOperations.Failure.unsupported("No terminal was found.")
        }
        try run(terminal, [], in: folder)
        #else
        throw FileOperations.Failure.unsupported("There is no terminal here.")
        #endif
    }
}

/// Packing items into an archive, and unpacking one, with the system's
/// `tar` and `unzip`.
public enum Archive {

    /// Whether a file is an archive that can be unpacked here.
    public static func canExtract(_ file: URL) -> Bool {
        #if os(macOS) || os(Linux)
        let name = file.lastPathComponent.lowercased()
        if name.hasSuffix(".zip") {
            return FileOpener.find("unzip") != nil || FileOpener.find("bsdtar") != nil
        }
        let suffixes = [".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.zst"]
        return suffixes.contains { name.hasSuffix($0) } && FileOpener.find("tar") != nil
        #else
        false
        #endif
    }

    public static var canCompress: Bool {
        #if os(macOS) || os(Linux)
        FileOpener.find("tar") != nil
        #else
        false
        #endif
    }

    /// An archive's name without its extensions: "photos" for
    /// "photos.tar.gz".
    static func stem(of name: String) -> String {
        let lower = name.lowercased()
        for suffix in [".tar.gz", ".tar.xz", ".tar.bz2", ".tar.zst", ".tgz", ".txz", ".tbz2", ".tar", ".zip"] where lower.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }

    /// Unpacks an archive into a new folder beside it, named after it.
    ///
    /// - Returns: The folder.
    @discardableResult
    public static func extract(_ archive: URL) throws -> URL {
        #if os(macOS) || os(Linux)
        let parent = archive.deletingLastPathComponent()
        let folder = try FileOperations.createFolder(named: stem(of: archive.lastPathComponent), in: parent)
        let status: Int32
        if archive.lastPathComponent.lowercased().hasSuffix(".zip"), let unzip = FileOpener.find("unzip") {
            status = try FileOpener.run(unzip, ["-q", archive.path, "-d", folder.path], waits: true)
        } else if let tar = FileOpener.find(archive.lastPathComponent.lowercased().hasSuffix(".zip") ? "bsdtar" : "tar") {
            status = try FileOpener.run(tar, ["-xf", archive.path, "-C", folder.path], waits: true)
        } else {
            status = 127
        }
        guard status == 0 else {
            try? FileManager.default.removeItem(at: folder)
            throw FileOperations.Failure.unsupported("“\(archive.lastPathComponent)” couldn't be unpacked.")
        }
        return folder
        #else
        throw FileOperations.Failure.unsupported("Archives can't be unpacked here.")
        #endif
    }

    /// Packs items of one folder into a `.tar.gz` beside them.
    ///
    /// - Parameter name: The archive's name without an extension; one
    ///   item's own name if left out, else "Archive".
    /// - Returns: The archive.
    @discardableResult
    public static func compress(_ items: [URL], named name: String? = nil) throws -> URL {
        #if os(macOS) || os(Linux)
        guard let first = items.first, let tar = FileOpener.find("tar") else {
            throw FileOperations.Failure.unsupported("Archives can't be made here.")
        }
        let parent = first.deletingLastPathComponent()
        let stem = name ?? (items.count == 1 ? first.lastPathComponent : "Archive")
        // The number goes before the whole extension: "Photos 2.tar.gz".
        let taken = FileOperations.names(in: parent)
        var unique = stem + ".tar.gz", number = 2
        while taken.contains(unique) {
            unique = "\(stem) \(number).tar.gz"
            number += 1
        }
        let archive = parent.appendingPathComponent(unique)
        let status = try FileOpener.run(tar, ["-czf", archive.path, "-C", parent.path, "--"] + items.map(\.lastPathComponent), waits: true)
        guard status == 0 else {
            try? FileManager.default.removeItem(at: archive)
            throw FileOperations.Failure.unsupported("The archive couldn't be made.")
        }
        return archive
        #else
        throw FileOperations.Failure.unsupported("Archives can't be made here.")
        #endif
    }
}
