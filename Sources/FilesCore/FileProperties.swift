//
//  FileProperties.swift
//  CoreApps
//

import Foundation

/// Who may do what with a file: read, write and execute, for its owner,
/// its group and everyone else.
public struct Permissions: Hashable, Sendable {

    /// The nine bits, as `chmod` has them: `0o644`.
    public var mode: Int

    public init(mode: Int) {
        self.mode = mode & 0o777
    }

    public enum Who: Int, CaseIterable, Hashable, Sendable {
        case owner = 6
        case group = 3
        case others = 0

        public var name: String {
            switch self {
            case .owner: "Owner"
            case .group: "Group"
            case .others: "Others"
            }
        }
    }

    public enum Access: Int, CaseIterable, Hashable, Sendable {
        case read = 4
        case write = 2
        case execute = 1
    }

    public func allows(_ access: Access, for who: Who) -> Bool {
        mode & (access.rawValue << who.rawValue) != 0
    }

    public mutating func set(_ access: Access, for who: Who, to isAllowed: Bool) {
        let bit = access.rawValue << who.rawValue
        mode = isAllowed ? mode | bit : mode & ~bit
    }

    /// Whether anyone may run the file as a program.
    public var isExecutable: Bool {
        get { mode & 0o111 != 0 }
        set {
            // Whoever may read the file may run it, as `chmod +x` would
            // have it under the usual mask.
            if newValue {
                for who in Who.allCases where allows(.read, for: who) { set(.execute, for: who, to: true) }
                if mode & 0o111 == 0 { set(.execute, for: .owner, to: true) }
            } else {
                mode &= ~0o111
            }
        }
    }

    /// As `ls -l` writes them: `rw-r--r--`.
    public var symbolic: String {
        var text = ""
        for who in Who.allCases {
            text += allows(.read, for: who) ? "r" : "-"
            text += allows(.write, for: who) ? "w" : "-"
            text += allows(.execute, for: who) ? "x" : "-"
        }
        return text
    }

    /// What a group of people may do, in words, for a file or a folder.
    public func summary(for who: Who, isFolder: Bool) -> String {
        let read = allows(.read, for: who), write = allows(.write, for: who), execute = allows(.execute, for: who)
        if isFolder {
            if read && write && execute { return "Create and delete files" }
            if read && execute { return "Access files" }
            if read { return "List files only" }
            return "None"
        }
        if read && write { return "Read and write" }
        if read { return "Read-only" }
        if write { return "Write-only" }
        return "None"
    }
}

/// What's known of a file or folder, for its properties.
public struct FileProperties: Sendable {

    public var url: URL

    public var name: String

    public var kind: FileKind

    /// A file's size in bytes; `nil` for a folder, whose contents are
    /// counted apart.
    public var size: Int64?

    /// How many items are directly in a folder.
    public var itemCount: Int?

    public var created: Date?

    public var modified: Date?

    public var accessed: Date?

    public var owner: String?

    public var group: String?

    public var permissions: Permissions?

    /// Where a symbolic link leads.
    public var linkTarget: String?

    /// Bytes free on the volume a folder is on.
    public var freeSpace: Int64?

    public var isFolder: Bool { kind == .folder }

    /// The folder the item is in.
    public var parent: String {
        url.deletingLastPathComponent().path
    }

    /// Reads an item's properties.
    public static func load(_ url: URL) throws -> FileProperties {
        let manager = FileManager.default
        let attributes = try manager.attributesOfItem(atPath: url.path)
        let type = attributes[.type] as? FileAttributeType
        let linkTarget = type == .typeSymbolicLink ? try? manager.destinationOfSymbolicLink(atPath: url.path) : nil
        var isDirectory: ObjCBool = false
        // A link to a folder is a folder to the user.
        let isFolder = manager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        let values = try? url.resourceValues(forKeys: [.contentAccessDateKey])
        return FileProperties(
            url: url,
            name: url.lastPathComponent,
            kind: isFolder ? .folder : FileKind(pathExtension: url.pathExtension),
            size: isFolder ? nil : (attributes[.size] as? NSNumber)?.int64Value,
            itemCount: isFolder ? (try? manager.contentsOfDirectory(atPath: url.path).count) : nil,
            created: attributes[.creationDate] as? Date,
            modified: attributes[.modificationDate] as? Date,
            accessed: values?.contentAccessDate,
            owner: attributes[.ownerAccountName] as? String,
            group: attributes[.groupOwnerAccountName] as? String,
            permissions: (attributes[.posixPermissions] as? NSNumber).map { Permissions(mode: $0.intValue) },
            linkTarget: linkTarget,
            freeSpace: isFolder ? Volume.space(at: url)?.free : nil
        )
    }

    /// The size of all a folder holds, and how many items that is. Stops
    /// counting at a limit, for folders as large as a disk.
    ///
    /// - Returns: The bytes and items counted, and whether the limit cut
    ///   the count short.
    public static func contents(of folder: URL, limit: Int = 100_000) -> (bytes: Int64, items: Int, isComplete: Bool) {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return (0, 0, true)
        }
        var bytes: Int64 = 0, items = 0
        for case let url as URL in walker {
            items += 1
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true {
                bytes += Int64(values.fileSize ?? 0)
            }
            if items >= limit { return (bytes, items, false) }
        }
        return (bytes, items, true)
    }

    /// Changes who may do what with an item.
    ///
    /// - Parameter recursively: For a folder, also everything inside it.
    ///   Files inside keep their own execute bits: a folder's mean
    ///   "enter", which isn't for files.
    public static func setPermissions(_ permissions: Permissions, of url: URL, recursively: Bool = false) throws {
        let manager = FileManager.default
        try manager.setAttributes([.posixPermissions: NSNumber(value: permissions.mode)], ofItemAtPath: url.path)
        guard recursively, let walker = manager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for case let inner as URL in walker {
            let isFolder = (try? inner.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            var mode = permissions.mode
            if !isFolder {
                let current = ((try? manager.attributesOfItem(atPath: inner.path))?[.posixPermissions] as? NSNumber)?.intValue ?? 0
                mode = (mode & ~0o111) | (current & 0o111)
            }
            try manager.setAttributes([.posixPermissions: NSNumber(value: mode)], ofItemAtPath: inner.path)
        }
    }
}
