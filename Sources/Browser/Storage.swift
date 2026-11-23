//
//  Storage.swift
//  CoreApps
//

#if Native || Apple
import Foundation
#else
import DynamicDefaults
#endif

/// What the browser keeps between runs, as text: in AppRuntime's defaults
/// for a guest, Foundation's on Apple's platforms, and on Cacao a file for
/// each in `$XDG_DATA_HOME/browser` (`~/.local/share/browser`), as Linux's
/// Foundation doesn't write its defaults out before a program ends.
enum Storage {

    enum Key: String {
        case bookmarks
        case history
        case tabs
        case searchEngine
    }

    static func string(_ key: Key) -> String? {
        #if Native
        guard let data = try? Data(contentsOf: file(key)) else { return nil }
        return String(decoding: data, as: UTF8.self)
        #else
        UserDefaults.standard.string(forKey: key.rawValue)
        #endif
    }

    static func set(_ value: String, _ key: Key) {
        #if Native
        let file = file(key)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(value.utf8).write(to: file, options: .atomic)
        #else
        UserDefaults.standard.set(value, forKey: key.rawValue)
        #endif
    }

    #if Native
    private static func file(_ key: Key) -> URL {
        let data: URL
        if let path = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], path.hasPrefix("/") {
            data = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            data = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share", isDirectory: true)
        }
        return data.appendingPathComponent("browser", isDirectory: true).appendingPathComponent(key.rawValue)
    }
    #endif
}
