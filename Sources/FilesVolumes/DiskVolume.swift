//
//  DiskVolume.swift
//  CoreApps
//

import FilesCore
import Foundation

/// A file system UDisks knows of, mounted or not: a partition of a disk, a
/// memory card, a disk image set up as a loop device.
public struct DiskVolume: Identifiable, Hashable, Sendable {

    /// The block device's object, such as
    /// `/org/freedesktop/UDisks2/block_devices/sdb1`.
    public var objectPath: String

    /// The device, such as `/dev/sdb1`.
    public var device: String

    /// The name the file system was given, if any.
    public var label: String

    /// The kind of file system, such as `vfat` or `ext4`.
    public var fileSystem: String

    /// Its size in bytes.
    public var size: UInt64

    /// Where it's mounted, if it is.
    public var mountPoints: [String]

    /// The drive it's on, as UDisks names it; `nil` for one with none,
    /// such as a loop device.
    public var drive: Drive?

    /// The disk image behind a loop device.
    public var backingFile: String?

    /// Whether UDisks marks it as the system's own, such as the root file
    /// system's partition: such volumes aren't offered to mount.
    public var isSystem: Bool

    /// Whether UDisks asks that it not be shown at all.
    public var isIgnored: Bool

    /// A name UDisks suggests showing.
    public var hintName: String

    public var id: String { objectPath }

    /// A drive a volume is on.
    public struct Drive: Hashable, Sendable {

        public var objectPath: String

        public var vendor: String

        public var model: String

        /// Whether its media can be taken out, as a card reader's can.
        public var isRemovable: Bool

        /// Whether it can eject its media, as an optical drive can.
        public var isEjectable: Bool

        /// Whether it can be powered off before unplugging, as a USB stick
        /// can.
        public var canPowerOff: Bool

        public init(objectPath: String, vendor: String = "", model: String = "", isRemovable: Bool = false, isEjectable: Bool = false, canPowerOff: Bool = false) {
            self.objectPath = objectPath
            self.vendor = vendor
            self.model = model
            self.isRemovable = isRemovable
            self.isEjectable = isEjectable
            self.canPowerOff = canPowerOff
        }

        /// Its vendor and model, as a person would name it.
        public var name: String {
            [vendor, model].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    public init(
        objectPath: String,
        device: String,
        label: String = "",
        fileSystem: String = "",
        size: UInt64 = 0,
        mountPoints: [String] = [],
        drive: Drive? = nil,
        backingFile: String? = nil,
        isSystem: Bool = false,
        isIgnored: Bool = false,
        hintName: String = ""
    ) {
        self.objectPath = objectPath
        self.device = device
        self.label = label
        self.fileSystem = fileSystem
        self.size = size
        self.mountPoints = mountPoints
        self.drive = drive
        self.backingFile = backingFile
        self.isSystem = isSystem
        self.isIgnored = isIgnored
        self.hintName = hintName
    }

    public var isMounted: Bool {
        !mountPoints.isEmpty
    }

    /// Where its files are, while it's mounted.
    public var mountURL: URL? {
        mountPoints.first.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Whether it's a loop device: a disk image.
    public var isLoop: Bool {
        backingFile != nil
    }

    /// Whether it can be taken away: its drive's media comes out, the drive
    /// powers off, or it's a disk image to detach.
    public var isRemovable: Bool {
        isLoop || drive.map { $0.isRemovable || $0.isEjectable || $0.canPowerOff } ?? false
    }

    /// What to call it: its label, the name UDisks suggests, the disk
    /// image's name, or its size and drive.
    public var name: String {
        if !label.isEmpty { return label }
        if !hintName.isEmpty { return hintName }
        if let backingFile { return (backingFile as NSString).lastPathComponent }
        let size = size > 0 ? ByteCount.format(Int64(clamping: size)) + " Volume" : "Volume"
        if let drive, !drive.name.isEmpty { return "\(size) on \(drive.name)" }
        return size
    }

    /// Whether the sidebar lists it: not ignored, not the system's own
    /// unless removable, and not where the system lives.
    public var isShown: Bool {
        guard !isIgnored else { return false }
        if mountPoints.contains(where: { $0 == "/" || $0.hasPrefix("/boot") || $0 == "/home" || $0.hasPrefix("/var") }) {
            return false
        }
        return !isSystem || isRemovable
    }

    /// The volumes to list, by name.
    public static func shown(_ volumes: [DiskVolume]) -> [DiskVolume] {
        volumes.filter(\.isShown).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Why UDisks didn't do what was asked, said for a person.
public enum DiskVolumeError: Error, Hashable, Sendable, LocalizedError {

    /// Polkit said no: there's no agent to ask for a password, or the
    /// user may not.
    case notAuthorized(action: String)

    /// Files on it are open.
    case busy(name: String)

    /// UDisks isn't running, or there's no system bus.
    case unavailable

    case failed(String)

    public var errorDescription: String? {
        switch self {
        case let .notAuthorized(action):
            "You aren't allowed to \(action). The system asks an administrator, and no authentication agent is running to ask for the password."
        case let .busy(name):
            "“\(name)” is busy: close the files and programs using it, then try again."
        case .unavailable:
            "Disks can't be managed here: UDisks isn't running."
        case let .failed(message):
            message
        }
    }
}
