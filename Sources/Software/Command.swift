//
//  Command.swift
//  CoreApps
//

#if Native || Apple

import Foundation

/// What a command printed, and how it ended.
nonisolated struct CommandResult: Sendable {

    var status: Int32

    var output: String

    var errorOutput: String

    var succeeded: Bool { status == 0 }
}

/// Running the programs the store installs with: `flatpak` and
/// `linux-app`. iOS runs no other programs, so there they're never found.
nonisolated enum Command {

    /// The program's path on `PATH`, if it's there.
    static func find(_ name: String) -> String? {
        #if os(iOS)
        return nil
        #else
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin"
        for directory in path.split(separator: ":") {
            let candidate = String(directory) + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
        #endif
    }

    /// Runs a program to its end, off the main thread, and gives what it
    /// printed; `nil` when it couldn't start.
    static func run(_ executable: String, _ arguments: [String]) async -> CommandResult? {
        #if os(iOS)
        return nil
        #else
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runNow(executable, arguments))
            }
        }
        #endif
    }

    /// Starts a program and leaves it running: an app being opened.
    @discardableResult
    static func launch(_ executable: String, _ arguments: [String]) -> Bool {
        #if os(iOS)
        return false
        #else
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return true
        } catch {
            return false
        }
        #endif
    }

    #if !os(iOS)
    private static func runNow(_ executable: String, _ arguments: [String]) -> CommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
        } catch {
            return nil
        }
        // Both pipes are read at once, so a program filling one while the
        // other is read doesn't wait forever.
        let errorData = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData.data = errors.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        return CommandResult(
            status: process.terminationStatus,
            output: String(decoding: outputData, as: UTF8.self),
            errorOutput: String(decoding: errorData.data, as: UTF8.self)
        )
    }

    /// Written on one thread and read on another after it's done.
    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }
    #endif
}

#endif
