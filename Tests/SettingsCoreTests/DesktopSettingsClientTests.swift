//
//  DesktopSettingsClientTests.swift
//  CoreApps
//
//  The client on a bus of its own, with a fake desktop serving the
//  settings portal, the settings service's backend and its Set, as
//  xdg-desktop-portal and swift-linux-shell's CacaoSettings do.
//

#if canImport(DBus)

import DBus
import Foundation
import Testing
@testable import SettingsCore

@Suite(.enabled(if: PrivateBus.isAvailable, "Needs dbus-daemon"), .serialized)
struct DesktopSettingsClientTests {

    @Test func readsThroughThePortal() async throws {
        try await withDesktop(.init(portal: true, backend: true, service: true)) { client, _ in
            let (appearance, source) = await client.read()
            #expect(source == .portal)
            #expect(appearance == DesktopAppearance(values: served))
            #expect(await client.serviceIsRunning())
        }
    }

    @Test func readsTheServiceWhenNoPortalAnswers() async throws {
        try await withDesktop(.init(portal: false, backend: true, service: true)) { client, _ in
            let (appearance, source) = await client.read()
            #expect(source == .settingsService)
            #expect(appearance.colorScheme == .dark)
            #expect(appearance.buttonLayout?.preset == .left)
        }
    }

    @Test func readsNothingWhenNothingAnswers() async throws {
        try await withDesktop(.init(portal: false, backend: false, service: false)) { client, _ in
            let (appearance, source) = await client.read()
            #expect(source == nil)
            #expect(appearance == DesktopAppearance())
            #expect(await client.serviceIsRunning() == false)
            await #expect(throws: DBusError.self) {
                try await client.set(.colorScheme, to: .uint32(1))
            }
        }
    }

    @Test func setChangesTheSettingAndIsHeard() async throws {
        try await withDesktop(.init(portal: true, backend: true, service: true)) { client, desktop in
            let changes = try await client.changes()
            try await client.set(.colorScheme, to: .uint32(2))
            let change = await first(changes)
            #expect(change?.namespace == "org.freedesktop.appearance")
            #expect(change?.key == "color-scheme")
            #expect(change?.value == .uint32(2))
            #expect(await desktop.store.values["org.freedesktop.appearance"]?["color-scheme"] == .uint32(2))

            try await client.set(.accentColor, to: .color(red: 0.6, green: 0.2, blue: 0.8))
            try await client.set(.buttonLayout, to: .string("appmenu:close"))
            try await client.set(.cursorSize, to: .int32(48))
            let (appearance, _) = await client.read()
            #expect(appearance.colorScheme == .light)
            #expect(appearance.accentColor == AccentColor(red: 0.6, green: 0.2, blue: 0.8))
            #expect(appearance.buttonLayout?.preset == .gnome)
            #expect(appearance.cursorSize == 48)
        }
    }

    @Test func hearsChangesWithNoPortal() async throws {
        try await withDesktop(.init(portal: false, backend: true, service: true)) { client, _ in
            let changes = try await client.changes()
            try await client.set(.contrast, to: .uint32(1))
            let change = await first(changes)
            #expect(change?.key == "contrast")
            #expect(change?.value == .uint32(1))
        }
    }

    @Test func hearsTheServiceStartAndStop() async throws {
        try await withDesktop(.init(portal: true, backend: false, service: false)) { client, desktop in
            #expect(await client.serviceIsRunning() == false)
            let services = try await client.serviceChanges()
            try await desktop.connection.requestName(DesktopBus.settingsName)
            #expect(await first(services) == true)
            #expect(await client.serviceIsRunning())
            _ = try await desktop.connection.releaseName(DesktopBus.settingsName)
            #expect(await first(services) == false)
        }
    }

    @Test func failsWithNoBus() async {
        await #expect(throws: DesktopSettingsClient.Failure.noBus) {
            _ = try await DesktopSettingsClient.connect(address: "unix:path=/tmp/settings-no-such-bus")
        }
    }

    // MARK: The fake desktop

    struct Parts {
        /// xdg-desktop-portal's name and interface.
        var portal: Bool
        /// The backend's name and interface, as the settings service has them.
        var backend: Bool
        /// The settings service's own name and `Set`.
        var service: Bool
    }

    /// The settings a fake desktop holds.
    actor Store {

        var values = served

        func values(matching patterns: [String]) -> [String: [String: SettingValue]] {
            let patterns = patterns.filter { !$0.isEmpty }
            guard !patterns.isEmpty else { return values }
            return values.filter { namespace, _ in
                patterns.contains { $0.hasSuffix("*") ? namespace.hasPrefix($0.dropLast()) : namespace == $0 }
            }
        }

        /// Keeps a value of a key the store has, of the type it has.
        func set(_ namespace: String, _ key: String, _ value: SettingValue) -> Bool {
            guard let key = SettingKey(namespace: namespace, name: key), key.accepts(value) else {
                return false
            }
            values[key.namespace, default: [:]][key.name] = value
            return true
        }
    }

    struct Desktop {
        let connection: DBusConnection
        let store: Store
    }

    /// Runs `body` with a fake desktop of the parts given on a private bus,
    /// and a client connected to it.
    private func withDesktop(
        _ parts: Parts,
        _ body: (_ client: DesktopSettingsClient, _ desktop: Desktop) async throws -> Void
    ) async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let connection = try await DBusConnection.connect(to: bus.address)
        let desktop = Desktop(connection: connection, store: Store())

        // The signal comes from the portal when there is one, as it passes
        // the backend's on, or else from the backend.
        let changedInterface = parts.portal ? DesktopBus.portalInterface : DesktopBus.backendInterface
        var settings: [DBusInterfaceImplementation] = []
        if parts.portal {
            settings.append(Self.reader(DesktopBus.portalInterface, store: desktop.store))
        }
        if parts.backend {
            settings.append(Self.reader(DesktopBus.backendInterface, store: desktop.store))
        }
        await connection.export(DBusExportedObject(settings), at: DesktopBus.portalPath)
        if parts.service {
            await connection.export(DBusExportedObject([Self.setter(desktop, signalInterface: changedInterface)]), at: DesktopBus.settingsPath)
        }
        var names: [DBusBusName] = []
        if parts.portal { names.append(DesktopBus.portalName) }
        if parts.backend { names.append(DesktopBus.backendName) }
        if parts.service { names.append(DesktopBus.settingsName) }
        for name in names {
            try await connection.requestName(name)
        }

        let client = try await DesktopSettingsClient.connect(address: bus.address, timeout: .seconds(3))
        do {
            try await body(client, desktop)
        } catch {
            await client.close()
            await connection.close()
            throw error
        }
        await client.close()
        await connection.close()
    }

    /// `ReadAll` and `ReadOne` on an interface.
    private static func reader(_ interface: DBusInterface, store: Store) -> DBusInterfaceImplementation {
        DBusInterfaceImplementation(
            name: interface,
            methods: [
                .init(
                    name: DBusMember(rawValue: "ReadAll")!,
                    inputSignature: DBusSignature(rawValue: "as")!,
                    outputSignature: DBusSignature(rawValue: "a{sa{sv}}")!
                ) { call in
                    var patterns: [String] = []
                    if case let .array(array)? = call.arguments.first {
                        patterns = array.compactMap(\.stringValue)
                    }
                    return [try readAllArgument(await store.values(matching: patterns))]
                },
                .init(
                    name: DBusMember(rawValue: "ReadOne")!,
                    inputSignature: DBusSignature(rawValue: "ss")!,
                    outputSignature: DBusSignature(rawValue: "v")!
                ) { call in
                    guard call.arguments.count == 2,
                          case let .string(namespace) = call.arguments[0],
                          case let .string(key) = call.arguments[1],
                          let value = await store.values[namespace]?[key]
                    else {
                        throw DBusError(name: DBusError.Name(rawValue: "org.freedesktop.portal.Error.NotFound")!, message: "Not found")
                    }
                    return [value.variant]
                },
            ]
        )
    }

    /// The settings service's `Set`, which announces what it changes.
    private static func setter(_ desktop: Desktop, signalInterface: DBusInterface) -> DBusInterfaceImplementation {
        let signal = DBusMessage.Signal(path: DesktopBus.portalPath, interface: signalInterface, name: DesktopBus.settingChanged)
        return DBusInterfaceImplementation(
            name: DesktopBus.settingsInterface,
            methods: [
                .init(name: DesktopBus.set, inputSignature: DBusSignature(rawValue: "ssv")!) { call in
                    guard call.arguments.count == 3,
                          case let .string(namespace) = call.arguments[0],
                          case let .string(key) = call.arguments[1],
                          let value = SettingValue(call.arguments[2])
                    else {
                        throw DBusError(name: .invalidArguments, message: "Set takes a namespace, a key and a variant")
                    }
                    if await desktop.store.set(namespace, key, value) {
                        try await desktop.connection.emit(signal, arguments: [.string(namespace), .string(key), value.variant])
                    }
                    return []
                },
            ]
        )
    }

    /// Namespaces to keys to values, as `ReadAll` returns them.
    private static func readAllArgument(_ values: [String: [String: SettingValue]]) throws -> DBusMessageArgument {
        let innerType = DBusSignature.DictionaryType(key: .string, value: .variant)!
        let namespaces = values.sorted { $0.key < $1.key }.map { namespace, keys in
            let entries = keys.sorted { $0.key < $1.key }.map { key, value in
                DBusMessageArgument.Dictionary.Entry(key: .string(key), value: value.variant)
            }
            let inner = DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, entries)!
            return DBusMessageArgument.Dictionary.Entry(key: .string(namespace), value: .dictionary(inner))
        }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: .dictionary(innerType), namespaces)!)
    }
}

// MARK: - Arguments

@Test func readsAReadAllReply() throws {
    let inner = DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, [
        .init(key: .string("color-scheme"), value: .variant(.init(.uint32(1)))),
        .init(key: .string("accent-color"), value: SettingValue.color(red: 0.1, green: 0.2, blue: 0.3).variant),
        // Read wraps a value in two variants.
        .init(key: .string("contrast"), value: .variant(.init(.variant(.init(.uint32(1)))))),
        // A type no setting has is left out.
        .init(key: .string("reduced-motion"), value: .variant(.init(.double(1)))),
    ])!
    let reply = DBusMessageArgument.dictionary(DBusMessageArgument.Dictionary(
        keyType: .string,
        valueType: .dictionary(DBusSignature.DictionaryType(key: .string, value: .variant)!),
        [.init(key: .string("org.freedesktop.appearance"), value: .dictionary(inner))]
    )!)
    let values = PortalArguments.readAll(reply)
    #expect(values == ["org.freedesktop.appearance": [
        "color-scheme": .uint32(1),
        "accent-color": .color(red: 0.1, green: 0.2, blue: 0.3),
        "contrast": .uint32(1),
    ]])
    #expect(PortalArguments.readAll(.string("no")) == [:])
}

@Test func readsChangeSignals() {
    let change = PortalArguments.settingChanged([.string("org.freedesktop.appearance"), .string("color-scheme"), .variant(.init(.uint32(2)))])
    #expect(change?.namespace == "org.freedesktop.appearance")
    #expect(change?.key == "color-scheme")
    #expect(change?.value == .uint32(2))
    #expect(PortalArguments.settingChanged([.string("org.freedesktop.appearance")]) == nil)
}

@Test func valuesBecomeArguments() {
    #expect(SettingValue.uint32(1).argument == .uint32(1))
    #expect(SettingValue.int32(24).argument == .int32(24))
    #expect(SettingValue.string("Inter 10").variant == .variant(.init(.string("Inter 10"))))
    let color = SettingValue.color(red: 0.6, green: 0.2, blue: 0.8)
    #expect(SettingValue(color.variant) == color)
    #expect(SettingValue(.struct(.init([.double(1), .double(0)])!)) == nil)
    #expect(SettingValue(.struct(.init([.double(1), .double(0), .string("x")])!)) == nil)
}

/// The first value a stream gives within a time, or `nil`.
func first<T: Sendable>(_ stream: AsyncStream<T>, within timeout: Duration = .seconds(5)) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            for await value in stream {
                return value
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return nil
        }
        let result = await group.next() ?? nil
        group.cancelAll()
        return result
    }
}

#endif
