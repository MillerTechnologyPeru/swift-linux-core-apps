//
//  UDisksTests.swift
//  CoreApps
//
//  The volumes UDisks lists, and the client mounting, unmounting and
//  ejecting through a fake UDisks2 on a bus of its own.
//

#if canImport(DBus)

import DBus
import Foundation
import Testing
@testable import FilesVolumes

/// UDisks' objects as `GetManagedObjects` answers them.
enum UDisksObjects {

    static func variant(_ value: DBusMessageArgument) -> DBusMessageArgument {
        .variant(DBusMessageArgument.Variant(value))
    }

    static func bytes(_ text: String) -> DBusMessageArgument {
        .array(DBusMessageArgument.Array(type: .byte, (Array(text.utf8) + [0]).map { .byte($0) })!)
    }

    static func properties(_ values: [String: DBusMessageArgument]) -> DBusMessageArgument {
        let entries = values.sorted { $0.key < $1.key }.map {
            DBusMessageArgument.Dictionary.Entry(key: .string($0.key), value: variant($0.value))
        }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, entries)!)
    }

    static let propertiesType = DBusSignature.ValueType.dictionary(DBusSignature.DictionaryType(key: .string, value: .variant)!)

    static let interfacesType = DBusSignature.ValueType.dictionary(DBusSignature.DictionaryType(key: .string, value: propertiesType)!)

    static func object(_ interfaces: [String: [String: DBusMessageArgument]]) -> DBusMessageArgument {
        let entries = interfaces.sorted { $0.key < $1.key }.map {
            DBusMessageArgument.Dictionary.Entry(key: .string($0.key), value: properties($0.value))
        }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: propertiesType, entries)!)
    }

    static func managedObjects(_ objects: [String: [String: [String: DBusMessageArgument]]]) -> DBusMessageArgument {
        let entries = objects.sorted { $0.key < $1.key }.map {
            DBusMessageArgument.Dictionary.Entry(key: .objectPath(DBusObjectPath(rawValue: $0.key)!), value: object($0.value))
        }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .objectPath, valueType: interfacesType, entries)!)
    }

    static func mountPoints(_ points: [String]) -> DBusMessageArgument {
        .array(DBusMessageArgument.Array(type: .array(.byte), points.map(bytes))!)
    }

    static let block = "org.freedesktop.UDisks2.Block"
    static let filesystem = "org.freedesktop.UDisks2.Filesystem"
    static let drive = "org.freedesktop.UDisks2.Drive"
    static let loop = "org.freedesktop.UDisks2.Loop"
    static let root = "/org/freedesktop/UDisks2/block_devices/"

    static func blockProperties(_ device: String, label: String = "", type: String = "ext4", usage: String = "filesystem", drive: String = "/", system: Bool = false, ignore: Bool = false, size: UInt64 = 0) -> [String: DBusMessageArgument] {
        [
            "Device": bytes(device), "PreferredDevice": bytes(device), "IdLabel": .string(label), "IdType": .string(type),
            "IdUsage": .string(usage), "Drive": .objectPath(DBusObjectPath(rawValue: drive)!), "HintSystem": .boolean(system),
            "HintIgnore": .boolean(ignore), "HintName": .string(""), "Size": .uint64(size),
        ]
    }

    /// A machine with a root partition, a USB stick (mounted), a disk
    /// image (not mounted), swap, and a partition UDisks says to ignore.
    static var machine: DBusMessageArgument {
        managedObjects([
            root + "vda2": [
                block: blockProperties("/dev/vda2", label: "root", drive: "/org/freedesktop/UDisks2/drives/disk", system: true),
                filesystem: ["MountPoints": mountPoints(["/"])],
            ],
            root + "sdb1": [
                block: blockProperties("/dev/sdb1", label: "STICK", type: "vfat", drive: "/org/freedesktop/UDisks2/drives/stick", system: false, size: 8_000_000_000),
                filesystem: ["MountPoints": mountPoints(["/media/someone/STICK"])],
            ],
            root + "loop0": [
                block: blockProperties("/dev/loop0", drive: "/", system: true, size: 16_777_216),
                filesystem: ["MountPoints": mountPoints([])],
                loop: ["BackingFile": bytes("/var/tmp/Pictures.img")],
            ],
            root + "vda3": [
                block: blockProperties("/dev/vda3", type: "swap", usage: "other", system: true),
            ],
            root + "vda4": [
                block: blockProperties("/dev/vda4", label: "hidden", system: false, ignore: true),
                filesystem: ["MountPoints": mountPoints([])],
            ],
            "/org/freedesktop/UDisks2/drives/disk": [
                drive: ["Vendor": .string("Virtio"), "Model": .string("Disk"), "Removable": .boolean(false), "MediaRemovable": .boolean(false), "Ejectable": .boolean(false), "CanPowerOff": .boolean(false)],
            ],
            "/org/freedesktop/UDisks2/drives/stick": [
                drive: ["Vendor": .string("Kingston"), "Model": .string("DataTraveler"), "Removable": .boolean(true), "MediaRemovable": .boolean(false), "Ejectable": .boolean(false), "CanPowerOff": .boolean(true)],
            ],
        ])
    }
}

@Suite struct DiskVolumeTests {

    let volumes = UDisksClient.volumes(managedObjects: UDisksObjects.machine)

    @Test func blockDevicesWithFileSystemsAreVolumes() {
        #expect(volumes.map(\.device).sorted() == ["/dev/loop0", "/dev/sdb1", "/dev/vda2", "/dev/vda4"])
    }

    @Test func aVolumeKnowsItsDriveAndWhereItIsMounted() throws {
        let stick = try #require(volumes.first { $0.device == "/dev/sdb1" })
        #expect(stick.name == "STICK")
        #expect(stick.fileSystem == "vfat")
        #expect(stick.isMounted)
        #expect(stick.mountURL?.path == "/media/someone/STICK")
        #expect(stick.drive?.name == "Kingston DataTraveler")
        #expect(stick.drive?.canPowerOff == true)
        #expect(stick.isRemovable)
    }

    @Test func aDiskImageIsNamedAfterItsFile() throws {
        let image = try #require(volumes.first { $0.device == "/dev/loop0" })
        #expect(image.isLoop)
        #expect(image.name == "Pictures.img")
        #expect(image.isMounted == false)
        #expect(image.isRemovable)
    }

    @Test func theSidebarLeavesOutTheSystemAndIgnoredOnes() {
        #expect(DiskVolume.shown(volumes).map(\.name) == ["Pictures.img", "STICK"])
    }

    @Test func aVolumeWithoutALabelIsNamedBySizeAndDrive() {
        let volume = DiskVolume(objectPath: "/x", device: "/dev/sdc1", size: 32_000_000_000, drive: .init(objectPath: "/d", vendor: "SanDisk", model: "Ultra"))
        #expect(volume.name == "32 GB Volume on SanDisk Ultra")
    }
}

@Suite(.enabled(if: PrivateBus.isAvailable, "Needs dbus-daemon"), .serialized)
struct UDisksClientTests {

    /// A fake UDisks2 serving the machine, whose methods record what they
    /// were asked and refuse what polkit would.
    func withUDisks(_ body: (UDisksClient, Calls) async throws -> Void) async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let service = try await DBusConnection.connect(to: bus.address)
        let calls = Calls()
        let manager = DBusInterfaceImplementation(
            name: DBusInterface(rawValue: "org.freedesktop.DBus.ObjectManager")!,
            methods: [
                .init(name: DBusMember(rawValue: "GetManagedObjects")!, outputSignature: DBusSignature(rawValue: "a{oa{sa{sv}}}")!) { _ in
                    [UDisksObjects.machine]
                }
            ]
        )
        await service.export(DBusExportedObject([manager]), at: UDisksClient.rootPath)
        func record(_ interface: String, _ method: String, at path: String, reply: @escaping @Sendable () throws -> [DBusMessageArgument] = { [] }) -> DBusInterfaceImplementation.Method {
            .init(name: DBusMember(rawValue: method)!, inputSignature: DBusSignature(rawValue: "a{sv}")!) { _ in
                await calls.add("\(method) \(path)")
                return try reply()
            }
        }
        let stick = UDisksObjects.root + "sdb1", image = UDisksObjects.root + "loop0", system = UDisksObjects.root + "vda2"
        await service.export(DBusExportedObject([
            DBusInterfaceImplementation(name: UDisksClient.filesystemInterface, methods: [
                record("fs", "Unmount", at: stick),
                record("fs", "Mount", at: stick) { [.string("/media/someone/STICK")] },
            ])
        ]), at: DBusObjectPath(rawValue: stick)!)
        await service.export(DBusExportedObject([
            DBusInterfaceImplementation(name: UDisksClient.filesystemInterface, methods: [
                record("fs", "Mount", at: image) { [.string("/media/someone/Pictures")] },
                record("fs", "Unmount", at: image),
            ]),
            DBusInterfaceImplementation(name: UDisksClient.loopInterface, methods: [record("loop", "Delete", at: image)]),
        ]), at: DBusObjectPath(rawValue: image)!)
        await service.export(DBusExportedObject([
            DBusInterfaceImplementation(name: UDisksClient.filesystemInterface, methods: [
                record("fs", "Unmount", at: system) {
                    throw DBusError(name: DBusError.Name(rawValue: "org.freedesktop.UDisks2.Error.NotAuthorizedCanObtain")!, message: "Not authorized to perform operation")
                },
                record("fs", "Mount", at: system) {
                    throw DBusError(name: DBusError.Name(rawValue: "org.freedesktop.UDisks2.Error.DeviceBusy")!, message: "Target is busy")
                },
            ])
        ]), at: DBusObjectPath(rawValue: system)!)
        await service.export(DBusExportedObject([
            DBusInterfaceImplementation(name: UDisksClient.driveInterface, methods: [record("drive", "PowerOff", at: "stick")])
        ]), at: DBusObjectPath(rawValue: "/org/freedesktop/UDisks2/drives/stick")!)
        _ = try await service.requestName(UDisksClient.busName)

        let client = UDisksClient(connection: try await DBusConnection.connect(to: bus.address))
        try await body(client, calls)
        await client.connection.close()
        await service.close()
    }

    @Test func listsTheVolumes() async throws {
        try await withUDisks { client, _ in
            let volumes = try await client.volumes()
            #expect(DiskVolume.shown(volumes).map(\.name) == ["Pictures.img", "STICK"])
        }
    }

    @Test func mountsAndSaysWhere() async throws {
        try await withUDisks { client, calls in
            let image = try #require(try await client.volumes().first { $0.isLoop })
            let url = try await client.mount(image)
            #expect(url.path == "/media/someone/Pictures")
            #expect(await calls.list == ["Mount " + UDisksObjects.root + "loop0"])
        }
    }

    @Test func ejectingAStickUnmountsItThenPowersItsDriveOff() async throws {
        try await withUDisks { client, calls in
            let stick = try #require(try await client.volumes().first { $0.device == "/dev/sdb1" })
            try await client.eject(stick)
            #expect(await calls.list == ["Unmount " + UDisksObjects.root + "sdb1", "PowerOff stick"])
        }
    }

    @Test func ejectingADiskImageDetachesIt() async throws {
        try await withUDisks { client, calls in
            let image = try #require(try await client.volumes().first { $0.isLoop })
            try await client.eject(image)
            #expect(await calls.list == ["Delete " + UDisksObjects.root + "loop0"])
        }
    }

    @Test func polkitsRefusalIsSaidPlainly() async throws {
        try await withUDisks { client, _ in
            let root = try #require(try await client.volumes().first { $0.device == "/dev/vda2" })
            await #expect(throws: DiskVolumeError.notAuthorized(action: "unmount “root”")) {
                try await client.unmount(root)
            }
            await #expect(throws: DiskVolumeError.busy(name: "root")) {
                try await client.mount(root)
            }
            #expect(DiskVolumeError.notAuthorized(action: "unmount “root”").localizedDescription.contains("no authentication agent"))
        }
    }

    @Test func noUDisksIsUnavailable() async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let client = UDisksClient(connection: try await DBusConnection.connect(to: bus.address))
        await #expect(throws: DiskVolumeError.unavailable) {
            _ = try await client.volumes()
        }
        await client.connection.close()
    }
}

/// The methods the fake UDisks was called with, in order.
actor Calls {

    private(set) var list: [String] = []

    func add(_ call: String) {
        list.append(call)
    }
}

#endif
