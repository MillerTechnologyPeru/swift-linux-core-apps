//
//  FileName.swift
//  CoreApps
//

import Foundation

/// What a file can be called.
public enum FileName {

    /// Why a name can't be given to a file.
    public enum Problem: Error, Hashable, Sendable {
        /// Nothing but spaces.
        case empty
        /// A slash separates folders in a path.
        case containsSlash
        /// "." and ".." mean a folder and the one above it.
        case reserved
        /// Longer than a file system stores: 255 bytes of UTF-8.
        case tooLong
    }

    /// A name as it's given to a file: without the spaces and line breaks
    /// around it.
    public static func cleaned(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What's wrong with a cleaned name, or `nil` if a file can have it.
    public static func problem(with name: String) -> Problem? {
        if name.isEmpty { return .empty }
        if name.contains("/") { return .containsSlash }
        if name == "." || name == ".." { return .reserved }
        if name.utf8.count > 255 { return .tooLong }
        return nil
    }

    /// A name no item of a folder has: the name itself, or with the first
    /// free number after it, before the extension: "Notes 2.txt".
    ///
    /// - Parameter taken: The names in the folder.
    public static func unique(_ name: String, among taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }
        var stem = name, suffix = ""
        // A leading dot is a hidden file's, not an extension's.
        if let dot = name.lastIndex(of: "."), dot != name.startIndex {
            stem = String(name[..<dot])
            suffix = String(name[dot...])
        }
        var number = 2
        while taken.contains("\(stem) \(number)\(suffix)") {
            number += 1
        }
        return "\(stem) \(number)\(suffix)"
    }
}

extension FileName.Problem: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .empty: "A name can't be empty."
        case .containsSlash: "A name can't contain a slash."
        case .reserved: "That name is reserved."
        case .tooLong: "That name is too long."
        }
    }
}
