//
//  Places.swift
//  CoreApps
//

import Foundation

/// The user's folders for kinds of things, as the desktop names them.
public enum UserFolder: String, CaseIterable, Hashable, Sendable {
    case desktop = "DESKTOP"
    case documents = "DOCUMENTS"
    case downloads = "DOWNLOAD"
    case music = "MUSIC"
    case pictures = "PICTURES"
    case videos = "VIDEOS"
    case templates = "TEMPLATES"
    case publicShare = "PUBLICSHARE"

    /// The folder's name in the home folder, unless the user moved it.
    var defaultName: String {
        switch self {
        case .desktop: "Desktop"
        case .documents: "Documents"
        case .downloads: "Downloads"
        case .music: "Music"
        case .pictures: "Pictures"
        case .videos: "Videos"
        case .templates: "Templates"
        case .publicShare: "Public"
        }
    }

    public var symbolName: String {
        switch self {
        case .desktop: "square"
        case .documents: "doc"
        case .downloads: "arrow.down"
        case .music: "play"
        case .pictures: "photo"
        case .videos: "play"
        case .templates: "doc"
        case .publicShare: "person"
        }
    }
}

/// Where the user's folders are: what `xdg-user-dirs` wrote in
/// `user-dirs.dirs`, or the usual names in the home folder.
public struct UserFolders: Hashable, Sendable {

    public var home: URL

    private var paths: [UserFolder: URL] = [:]

    public init(home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true), configuration: String? = nil) {
        self.home = home
        let text = configuration ?? Self.configuration(home: home)
        paths = Self.parse(text ?? "", home: home)
    }

    /// The text of `user-dirs.dirs`, if there is one.
    static func configuration(home: URL, environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        var config = home.appendingPathComponent(".config", isDirectory: true)
        if let path = environment["XDG_CONFIG_HOME"], path.hasPrefix("/") {
            config = URL(fileURLWithPath: path, isDirectory: true)
        }
        return try? String(contentsOf: config.appendingPathComponent("user-dirs.dirs"), encoding: .utf8)
    }

    /// The folders in a `user-dirs.dirs`: lines of
    /// `XDG_MUSIC_DIR="$HOME/Music"`. A folder set to the home folder
    /// itself is one the user turned off.
    static func parse(_ text: String, home: URL) -> [UserFolder: URL] {
        var paths: [UserFolder: URL] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("XDG_"), let equals = line.firstIndex(of: "=") else { continue }
            let key = line[line.index(line.startIndex, offsetBy: 4)..<equals]
            guard key.hasSuffix("_DIR"), let folder = UserFolder(rawValue: String(key.dropLast(4))) else { continue }
            var value = String(line[line.index(after: equals)...])
            guard value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 else { continue }
            value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
            let url: URL
            if value == "$HOME" || value == "$HOME/" {
                continue
            } else if value.hasPrefix("$HOME/") {
                url = home.appendingPathComponent(String(value.dropFirst(6)), isDirectory: true)
            } else if value.hasPrefix("/") {
                url = URL(fileURLWithPath: value, isDirectory: true)
            } else {
                continue
            }
            paths[folder] = url
        }
        return paths
    }

    /// Where one of the folders is, whether or not it exists.
    public func url(for folder: UserFolder) -> URL {
        if let url = paths[folder] { return url }
        #if canImport(Darwin)
        if folder == .videos { return home.appendingPathComponent("Movies", isDirectory: true) }
        #endif
        return home.appendingPathComponent(folder.defaultName, isDirectory: true)
    }
}

/// A file system that is mounted: a disk, a partition, a memory card.
public struct Volume: Identifiable, Hashable, Sendable {

    /// Where its files appear.
    public var url: URL

    public var name: String

    /// The device it's on, such as `/dev/sda1`.
    public var device: String

    /// The kind of file system, such as `ext4`.
    public var fileSystem: String

    /// Whether it can be taken out: it's mounted where removable media are.
    public var isRemovable: Bool

    public var id: URL { url }

    /// Bytes free for the user, and in all.
    public var space: (free: Int64, total: Int64)? {
        Volume.space(at: url)
    }

    /// Bytes free and in all on the file system a folder is on.
    public static func space(at url: URL) -> (free: Int64, total: Int64)? {
        guard let values = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
              let free = (values[.systemFreeSize] as? NSNumber)?.int64Value,
              let total = (values[.systemSize] as? NSNumber)?.int64Value else { return nil }
        return (free, total)
    }

    /// The file systems that hold files, as opposed to the kernel's own.
    private static let pseudo: Set<String> = [
        "proc", "sysfs", "devtmpfs", "devpts", "tmpfs", "cgroup", "cgroup2", "pstore", "bpf", "tracefs", "debugfs",
        "securityfs", "configfs", "fusectl", "mqueue", "hugetlbfs", "autofs", "binfmt_misc", "efivarfs", "ramfs",
        "overlay", "squashfs", "nsfs", "rpc_pipefs", "selinuxfs", "fuse.portal", "fuse.gvfsd-fuse",
    ]

    /// File systems reached over a network, which aren't listed.
    private static let network: Set<String> = ["nfs", "nfs4", "cifs", "smb3", "smbfs", "fuse.sshfs", "9p", "ceph", "afs", "davfs", "ncpfs"]

    /// The volumes in the text of `/proc/self/mounts`: lines of device,
    /// mount point, file system and options. The root is left out, being
    /// listed as the computer, and so are the system's own mounts.
    public static func parse(mounts text: String) -> [Volume] {
        var volumes: [Volume] = []
        var seen: Set<String> = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ")
            guard fields.count >= 3 else { continue }
            let device = unescape(String(fields[0])), path = unescape(String(fields[1])), type = String(fields[2])
            guard device.hasPrefix("/dev/"), !pseudo.contains(type), !network.contains(type) else { continue }
            guard path != "/", !path.hasPrefix("/boot"), !path.hasPrefix("/snap"), !path.hasPrefix("/var/lib"), !path.hasPrefix("/sys"), !path.hasPrefix("/proc") else { continue }
            guard seen.insert(path).inserted else { continue }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            volumes.append(Volume(
                url: url,
                name: url.lastPathComponent,
                device: device,
                fileSystem: type,
                isRemovable: path.hasPrefix("/media/") || path.hasPrefix("/run/media/") || path.hasPrefix("/mnt/")
            ))
        }
        return volumes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A field of the mounts file with its octal escapes (`\040` is a
    /// space) put back.
    static func unescape(_ field: String) -> String {
        var bytes: [UInt8] = []
        let source = Array(field.utf8)
        var index = 0
        while index < source.count {
            if source[index] == UInt8(ascii: "\\"), index + 3 < source.count,
               let value = UInt8(String(decoding: source[(index + 1)...(index + 3)], as: UTF8.self), radix: 8) {
                bytes.append(value)
                index += 4
            } else {
                bytes.append(source[index])
                index += 1
            }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// The volumes mounted now. Empty where the system doesn't say.
    public static func mounted() -> [Volume] {
        guard let text = try? String(contentsOfFile: "/proc/self/mounts", encoding: .utf8) else { return [] }
        return parse(mounts: text)
    }
}
