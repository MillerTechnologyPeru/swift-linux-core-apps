//
//  FileChooserBackend.swift
//  CoreApps
//

#if canImport(DBus)

import DBus
import FilesCore
import Foundation

/// The file manager as xdg-desktop-portal's file chooser: it serves
/// `org.freedesktop.impl.portal.FileChooser` under a bus name of its own,
/// and asks a presenter, which shows the dialog, for each request.
///
/// Each request also gets an `org.freedesktop.impl.portal.Request` object
/// at its handle while it lasts, whose `Close` cancels the presenter's
/// task: the presenter then closes its dialog, and the request ends with
/// response 2.
public final class FileChooserBackend: Sendable {

    /// The bus name the backend owns, which `cacao-files.portal` names.
    public static let busName = DBusBusName(rawValue: "org.freedesktop.impl.portal.desktop.cacao.files")!

    /// The path every portal backend serves.
    public static let path = DBusObjectPath(rawValue: "/org/freedesktop/portal/desktop")!

    public static let interface = DBusInterface(rawValue: "org.freedesktop.impl.portal.FileChooser")!

    public static let requestInterface = DBusInterface(rawValue: "org.freedesktop.impl.portal.Request")!

    /// Shows a request and answers it: with `.other` once its task is
    /// cancelled.
    public typealias Presenter = @Sendable (FileChooserRequest) async -> FileChooserResponse

    public let connection: DBusConnection

    private let presenter: Presenter

    private let activity = Activity()

    public init(connection: DBusConnection, presenter: @escaping Presenter) {
        self.connection = connection
        self.presenter = presenter
    }

    /// Connects to the session bus, serves the interface, and asks for the
    /// bus name.
    ///
    /// - Returns: The backend, and whether it owns the name: another
    ///   program may already be the file chooser.
    public static func start(presenter: @escaping Presenter) async throws -> (backend: FileChooserBackend, ownsName: Bool) {
        let connection = try await DBusConnection.connect(to: .session)
        let backend = FileChooserBackend(connection: connection, presenter: presenter)
        await backend.export()
        let owns = try await backend.requestName()
        return (backend, owns)
    }

    /// Serves the interface on the connection. The bus name is asked for
    /// separately, by `requestName()`.
    public func export() async {
        await connection.export(DBusExportedObject([implementation()]), at: Self.path)
    }

    /// Asks for the backend's bus name, without waiting in line behind an
    /// owner. Returns whether this connection owns it now.
    @discardableResult
    public func requestName() async throws -> Bool {
        let result = try await connection.requestName(Self.busName, flags: .doNotQueue)
        return result == .primaryOwner || result == .alreadyOwner
    }

    /// How many requests are being answered: the program waits for none
    /// before it quits, so no app is left without its answer.
    public var requestsInProgress: Int {
        get async { await activity.count }
    }

    private func implementation() -> DBusInterfaceImplementation {
        let method = { (name: String, kind: FileChooserRequest.Kind) in
            DBusInterfaceImplementation.Method(
                name: DBusMember(rawValue: name)!,
                inputSignature: DBusSignature(rawValue: "osssa{sv}")!,
                outputSignature: DBusSignature(rawValue: "ua{sv}")!,
                inputNames: ["handle", "app_id", "parent_window", "title", "options"],
                outputNames: ["response", "results"]
            ) { [self] call in
                guard let request = FileChooserRequest(kind: kind, arguments: call.arguments) else {
                    throw DBusError(name: .invalidArguments, message: "\(name) takes a handle, an app, a window, a title and options")
                }
                return await answer(request).arguments
            }
        }
        return DBusInterfaceImplementation(
            name: Self.interface,
            methods: [
                method("OpenFile", .open),
                method("SaveFile", .save),
                method("SaveFiles", .saveFiles),
            ],
            properties: [
                .init(name: "version", type: .uint32) { .uint32(4) }
            ]
        )
    }

    /// Shows a request until it's answered or closed.
    private func answer(_ request: FileChooserRequest) async -> FileChooserResponse {
        await activity.begin()
        let presenter = self.presenter
        let task = Task { await presenter(request) }
        let handle = DBusObjectPath(rawValue: request.handle)
        if let handle {
            let close = DBusInterfaceImplementation(
                name: Self.requestInterface,
                methods: [
                    .init(name: DBusMember(rawValue: "Close")!) { _ in
                        task.cancel()
                        return []
                    }
                ]
            )
            await connection.export(DBusExportedObject([close]), at: handle)
        }
        let response = await task.value
        if let handle {
            await connection.unexport(at: handle)
        }
        await activity.end()
        return response
    }
}

/// Counts the requests being answered.
private actor Activity {

    private(set) var count = 0

    func begin() { count += 1 }

    func end() { count -= 1 }
}

#endif
