//
//  DesktopSettingsClient.swift
//  CoreApps
//

#if canImport(DBus)
import DBus
#endif

/// The desktop's settings over the session bus: read through the settings
/// portal, followed as they change, and changed through swift-linux-shell's
/// settings service.
///
/// ```swift
/// let client = try await DesktopSettingsClient.connect()
/// let (appearance, source) = await client.read()
/// try await client.set(.colorScheme, to: .uint32(1))
/// ```
///
/// Apps read settings through the portal; only the Settings app and the
/// shell change them, with the service's `Set`.
public final class DesktopSettingsClient: Sendable {

    /// Where the settings were read from.
    public enum Source: Hashable, Sendable {

        /// xdg-desktop-portal, as every app reads them.
        case portal

        /// The settings service itself, as the portal's backend, when no
        /// portal answered.
        case settingsService
    }

    public enum Failure: Error, Hashable, Sendable {

        /// There's no session bus: none was found, or this platform has
        /// no D-Bus.
        case noBus
    }

    #if canImport(DBus)

    private let connection: DBusConnection

    /// How long to wait for a reply. A portal that isn't running yet is
    /// started by the bus, which takes a moment.
    private let timeout: Duration

    private init(connection: DBusConnection, timeout: Duration) {
        self.connection = connection
        self.timeout = timeout
    }

    /// Connects to the session bus, or to the bus at `address`, such as
    /// `unix:path=/run/user/1000/bus`.
    public static func connect(address: String? = nil, timeout: Duration = .seconds(5)) async throws -> DesktopSettingsClient {
        let connection: DBusConnection
        do {
            if let address {
                connection = try await DBusConnection.connect(to: address)
            } else {
                connection = try await DBusConnection.connect(to: .session)
            }
        } catch {
            throw Failure.noBus
        }
        return DesktopSettingsClient(connection: connection, timeout: timeout)
    }

    public func close() async {
        await connection.close()
    }

    // MARK: Reading

    /// The settings now, from the portal, or else from the settings
    /// service's backend directly. The source is `nil` when neither
    /// answered, and the appearance then has nothing set.
    public func read() async -> (appearance: DesktopAppearance, source: Source?) {
        if let values = try? await readAll(destination: DesktopBus.portalName, interface: DesktopBus.portalInterface) {
            return (DesktopAppearance(values: values), .portal)
        }
        if let values = try? await readAll(destination: DesktopBus.backendName, interface: DesktopBus.backendInterface) {
            return (DesktopAppearance(values: values), .settingsService)
        }
        return (DesktopAppearance(), nil)
    }

    private func readAll(destination: DBusBusName, interface: DBusInterface) async throws -> [String: [String: SettingValue]] {
        let namespaces = DBusMessageArgument.array(
            DBusMessageArgument.Array(type: .string, SettingKey.namespaces.map { .string($0) })!
        )
        let reply = try await connection.callMethod(
            destination: destination,
            path: DesktopBus.portalPath,
            interface: interface,
            method: DesktopBus.readAll,
            arguments: [namespaces],
            timeout: timeout
        )
        guard let first = reply.first else {
            return [:]
        }
        return PortalArguments.readAll(first)
    }

    /// The settings that change from now on, as the portal and the
    /// settings service announce them with `SettingChanged`. Both are
    /// heard, so changes come with no portal running too; a change heard
    /// twice applies the same value twice.
    public func changes() async throws -> AsyncStream<(namespace: String, key: String, value: SettingValue)> {
        let rule = DBusMatchRule.signal(member: DesktopBus.settingChanged, path: DesktopBus.portalPath)
        let signals = try await connection.signals(matching: rule)
        return AsyncStream { continuation in
            let task = Task {
                for await signal in signals {
                    if let change = PortalArguments.settingChanged(signal.arguments) {
                        continuation.yield(change)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: The settings service

    /// Whether the settings service is on the bus, to take changes.
    public func serviceIsRunning() async -> Bool {
        (try? await connection.nameHasOwner(DesktopBus.settingsName)) ?? false
    }

    /// Whether the settings service is on the bus, each time it starts or
    /// stops from now on.
    public func serviceChanges() async throws -> AsyncStream<Bool> {
        let signals = try await connection.signals(matching: .nameOwnerChanged(name: DesktopBus.settingsName))
        return AsyncStream { continuation in
            let task = Task {
                for await signal in signals {
                    // NameOwnerChanged(s name, s old owner, s new owner)
                    if signal.arguments.count == 3, case let .string(owner) = signal.arguments[2] {
                        continuation.yield(!owner.isEmpty)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Changes a setting through the settings service, which keeps it and
    /// announces it to apps. Throws the service's error, or the bus's when
    /// the service isn't running.
    public func set(_ key: SettingKey, to value: SettingValue) async throws {
        try await connection.callMethod(
            destination: DesktopBus.settingsName,
            path: DesktopBus.settingsPath,
            interface: DesktopBus.settingsInterface,
            method: DesktopBus.set,
            arguments: [.string(key.namespace), .string(key.name), value.variant],
            timeout: timeout
        )
    }

    #else

    /// This platform has no D-Bus, so there's no desktop to ask.
    public static func connect(address: String? = nil, timeout: Duration = .seconds(5)) async throws -> DesktopSettingsClient {
        throw Failure.noBus
    }

    public func close() async { }

    public func read() async -> (appearance: DesktopAppearance, source: Source?) {
        (DesktopAppearance(), nil)
    }

    public func changes() async throws -> AsyncStream<(namespace: String, key: String, value: SettingValue)> {
        AsyncStream { $0.finish() }
    }

    public func serviceIsRunning() async -> Bool {
        false
    }

    public func serviceChanges() async throws -> AsyncStream<Bool> {
        AsyncStream { $0.finish() }
    }

    public func set(_ key: SettingKey, to value: SettingValue) async throws {
        throw Failure.noBus
    }

    #endif
}
