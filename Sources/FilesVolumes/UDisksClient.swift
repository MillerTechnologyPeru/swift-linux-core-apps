//
//  UDisksClient.swift
//  CoreApps
//

// UDisks2 on the system bus. Off the platforms with a D-Bus package, which
// are Linux and macOS, there's none to ask; on macOS there's no UDisks.
#if canImport(DBus)

import DBus
import FilesCore
import Foundation

/// Mounting, unmounting and ejecting through UDisks2, the system's disk
/// service, which asks polkit whether the user may.
public final class UDisksClient: Sendable {

    public static let busName = DBusBusName(rawValue: "org.freedesktop.UDisks2")!

    public static let rootPath = DBusObjectPath(rawValue: "/org/freedesktop/UDisks2")!

    static let objectManager = DBusInterface(rawValue: "org.freedesktop.DBus.ObjectManager")!

    static let blockInterface = "org.freedesktop.UDisks2.Block"

    static let filesystemInterface = DBusInterface(rawValue: "org.freedesktop.UDisks2.Filesystem")!

    static let driveInterface = DBusInterface(rawValue: "org.freedesktop.UDisks2.Drive")!

    static let loopInterface = DBusInterface(rawValue: "org.freedesktop.UDisks2.Loop")!

    public let connection: DBusConnection

    public init(connection: DBusConnection) {
        self.connection = connection
    }

    /// A client on the system bus.
    public static func system() async throws -> UDisksClient {
        do {
            return UDisksClient(connection: try await DBusConnection.connect(to: .system))
        } catch {
            throw DiskVolumeError.unavailable
        }
    }

    // MARK: Reading

    /// The file systems UDisks knows of, mounted or not.
    public func volumes() async throws -> [DiskVolume] {
        let reply: [DBusMessageArgument]
        do {
            reply = try await connection.callMethod(
                destination: Self.busName,
                path: Self.rootPath,
                interface: Self.objectManager,
                method: DBusMember(rawValue: "GetManagedObjects")!
            )
        } catch {
            throw Self.translate(error, action: "list the disks", name: "")
        }
        return reply.first.map(Self.volumes(managedObjects:)) ?? []
    }

    /// The volumes in a `GetManagedObjects` reply, an `a{oa{sa{sv}}}`:
    /// each block device with a file system, with its drive's details.
    public static func volumes(managedObjects argument: DBusMessageArgument) -> [DiskVolume] {
        guard case let .dictionary(objects) = argument else { return [] }
        var interfacesByPath: [String: [String: [String: DBusMessageArgument]]] = [:]
        for object in objects {
            guard case let .objectPath(path) = object.key, case let .dictionary(interfaces) = object.value else { continue }
            var byName: [String: [String: DBusMessageArgument]] = [:]
            for interface in interfaces {
                guard case let .string(name) = interface.key else { continue }
                byName[name] = properties(interface.value)
            }
            interfacesByPath[path.rawValue] = byName
        }
        var volumes: [DiskVolume] = []
        for (path, interfaces) in interfacesByPath {
            guard let block = interfaces[blockInterface],
                  let filesystem = interfaces[filesystemInterface.rawValue],
                  string(block["IdUsage"]) == "filesystem" else { continue }
            var drive: DiskVolume.Drive?
            if case let .objectPath(drivePath)? = block["Drive"], drivePath.rawValue != "/",
               let properties = interfacesByPath[drivePath.rawValue]?[driveInterface.rawValue] {
                drive = DiskVolume.Drive(
                    objectPath: drivePath.rawValue,
                    vendor: string(properties["Vendor"]),
                    model: string(properties["Model"]),
                    isRemovable: bool(properties["MediaRemovable"]) || bool(properties["Removable"]),
                    isEjectable: bool(properties["Ejectable"]),
                    canPowerOff: bool(properties["CanPowerOff"])
                )
            }
            let mountPoints: [String]
            if case let .array(points)? = filesystem["MountPoints"] {
                mountPoints = points.compactMap(bytes)
            } else {
                mountPoints = []
            }
            volumes.append(DiskVolume(
                objectPath: path,
                device: bytes(block["PreferredDevice"]) ?? bytes(block["Device"]) ?? "",
                label: string(block["IdLabel"]),
                fileSystem: string(block["IdType"]),
                size: uint64(block["Size"]),
                mountPoints: mountPoints,
                drive: drive,
                backingFile: interfaces[loopInterface.rawValue].flatMap { bytes($0["BackingFile"]) },
                isSystem: bool(block["HintSystem"]),
                isIgnored: bool(block["HintIgnore"]),
                hintName: string(block["HintName"])
            ))
        }
        return volumes.sorted { $0.objectPath < $1.objectPath }
    }

    // MARK: Changing

    /// Mounts a volume where UDisks chooses, under `/media` or
    /// `/run/media`, and returns where.
    @discardableResult
    public func mount(_ volume: DiskVolume) async throws -> URL {
        let reply = try await call(Self.filesystemInterface, "Mount", on: volume.objectPath, action: "mount “\(volume.name)”", name: volume.name)
        guard case let .string(path)? = reply.first else {
            throw DiskVolumeError.failed("UDisks didn't say where it mounted “\(volume.name)”.")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public func unmount(_ volume: DiskVolume) async throws {
        try await call(Self.filesystemInterface, "Unmount", on: volume.objectPath, action: "unmount “\(volume.name)”", name: volume.name)
    }

    /// Makes a volume safe to take away: unmounts it, then ejects its
    /// drive's media, powers the drive off, or detaches the disk image,
    /// whichever it can.
    public func eject(_ volume: DiskVolume) async throws {
        if volume.isMounted {
            try await unmount(volume)
        }
        let action = "eject “\(volume.name)”"
        if let drive = volume.drive {
            if drive.isEjectable {
                try await call(Self.driveInterface, "Eject", on: drive.objectPath, action: action, name: volume.name)
            } else if drive.canPowerOff {
                try await call(Self.driveInterface, "PowerOff", on: drive.objectPath, action: action, name: volume.name)
            }
        } else if volume.isLoop {
            try await call(Self.loopInterface, "Delete", on: volume.objectPath, action: action, name: volume.name)
        }
    }

    @discardableResult
    private func call(_ interface: DBusInterface, _ method: String, on path: String, action: String, name: String) async throws -> [DBusMessageArgument] {
        guard let objectPath = DBusObjectPath(rawValue: path) else {
            throw DiskVolumeError.failed("“\(name)” has no object at \(path).")
        }
        do {
            return try await connection.callMethod(
                destination: Self.busName,
                path: objectPath,
                interface: interface,
                method: DBusMember(rawValue: method)!,
                arguments: [Self.noOptions],
                // Polkit may wait on an agent asking for a password.
                timeout: .seconds(120)
            )
        } catch {
            throw Self.translate(error, action: action, name: name)
        }
    }

    // MARK: Changes

    /// Yields each time UDisks' objects change: a disk added or removed, a
    /// volume mounted or unmounted. Read `volumes()` again then.
    public func changes() async throws -> AsyncStream<Void> {
        let signals = try await connection.signals(matching: DBusMatchRule(type: .signal, pathNamespace: Self.rootPath))
        return AsyncStream { continuation in
            let task = Task {
                for await _ in signals {
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Arguments

    /// An empty `a{sv}`, the options every call here takes.
    static let noOptions = DBusMessageArgument.dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant)!)

    static func properties(_ argument: DBusMessageArgument) -> [String: DBusMessageArgument] {
        guard case let .dictionary(dictionary) = argument else { return [:] }
        var properties: [String: DBusMessageArgument] = [:]
        for entry in dictionary {
            guard case let .string(key) = entry.key else { continue }
            var value = entry.value
            while case let .variant(variant) = value { value = variant.element }
            properties[key] = value
        }
        return properties
    }

    static func string(_ argument: DBusMessageArgument?) -> String {
        if case let .string(value)? = argument { return value }
        return ""
    }

    static func bool(_ argument: DBusMessageArgument?) -> Bool {
        if case let .boolean(value)? = argument { return value }
        return false
    }

    static func uint64(_ argument: DBusMessageArgument?) -> UInt64 {
        if case let .uint64(value)? = argument { return value }
        return 0
    }

    /// A path from an `ay` ending in a NUL byte.
    static func bytes(_ argument: DBusMessageArgument?) -> String? {
        guard case let .array(array)? = argument else { return nil }
        var data = array.compactMap { element -> UInt8? in
            if case let .byte(byte) = element { return byte }
            return nil
        }
        while data.last == 0 { data.removeLast() }
        return data.isEmpty ? nil : String(decoding: data, as: UTF8.self)
    }

    /// UDisks' and the bus's errors, said for a person.
    static func translate(_ error: Error, action: String, name: String) -> DiskVolumeError {
        if let error = error as? DiskVolumeError { return error }
        guard let error = error as? DBusError else {
            return .failed("Couldn't \(action): \(error.localizedDescription)")
        }
        let errorName = error.name.rawValue
        if errorName.hasPrefix("org.freedesktop.UDisks2.Error.NotAuthorized") {
            return .notAuthorized(action: action)
        }
        if errorName == "org.freedesktop.UDisks2.Error.DeviceBusy" {
            return .busy(name: name)
        }
        if errorName == "org.freedesktop.DBus.Error.ServiceUnknown" || errorName == "org.freedesktop.DBus.Error.NameHasNoOwner" {
            return .unavailable
        }
        let message = error.message.isEmpty ? errorName : error.message
        return .failed("Couldn't \(action): \(message)")
    }
}

#endif
