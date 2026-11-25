//
//  FileChooserTests.swift
//  CoreApps
//
//  The file chooser's requests and answers as D-Bus arguments, and the
//  backend on a bus of its own, called as xdg-desktop-portal calls it.
//

#if canImport(DBus)

import DBus
import FilesCore
import Foundation
import Testing
@testable import FilesPortal

/// Arguments as the portal sends them.
enum Arguments {

    static func variant(_ value: DBusMessageArgument) -> DBusMessageArgument {
        .variant(DBusMessageArgument.Variant(value))
    }

    static func bytes(_ path: String) -> DBusMessageArgument {
        .array(DBusMessageArgument.Array(type: .byte, (Array(path.utf8) + [0]).map { .byte($0) })!)
    }

    static func options(_ values: [String: DBusMessageArgument]) -> DBusMessageArgument {
        let entries = values.sorted { $0.key < $1.key }.map {
            DBusMessageArgument.Dictionary.Entry(key: .string($0.key), value: variant($0.value))
        }
        return .dictionary(DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, entries)!)
    }

    static func structure(_ elements: [DBusMessageArgument]) -> DBusMessageArgument {
        .struct(DBusMessageArgument.Structure(elements)!)
    }

    static func array(_ elements: [DBusMessageArgument], of type: DBusSignature.ValueType) -> DBusMessageArgument {
        .array(DBusMessageArgument.Array(type: type, elements)!)
    }

    static let ruleType = DBusSignature.ValueType.struct(DBusSignature.StructureType([.uint32, .string])!)

    static func filter(_ name: String, _ rules: [(UInt32, String)]) -> DBusMessageArgument {
        structure([.string(name), array(rules.map { structure([.uint32($0.0), .string($0.1)]) }, of: ruleType)])
    }

    static var filterType: DBusSignature.ValueType {
        .struct(DBusSignature.StructureType([.string, .array(ruleType)])!)
    }

    static func call(_ handle: String, title: String = "", options: [String: DBusMessageArgument]) -> [DBusMessageArgument] {
        [.objectPath(DBusObjectPath(rawValue: handle)!), .string("org.example.App"), .string("wayland:abc"), .string(title), self.options(options)]
    }
}

@Suite struct FileChooserArgumentTests {

    @Test func anOpenRequestKeepsItsOptions() throws {
        let images = Arguments.filter("Images", [(1, "image/*"), (0, "*.svg")])
        let text = Arguments.filter("Text", [(0, "*.txt")])
        let choiceType = DBusSignature.ValueType.struct(DBusSignature.StructureType([.string, .string, .array(.struct(DBusSignature.StructureType([.string, .string])!)), .string])!)
        let pairType = DBusSignature.ValueType.struct(DBusSignature.StructureType([.string, .string])!)
        let encoding = Arguments.structure([
            .string("encoding"), .string("Encoding"),
            Arguments.array([
                Arguments.structure([.string("utf8"), .string("UTF-8")]),
                Arguments.structure([.string("latin1"), .string("Latin-1")]),
            ], of: pairType),
            .string("utf8"),
        ])
        let readOnly = Arguments.structure([.string("ro"), .string("Read only"), Arguments.array([], of: pairType), .string("false")])
        let arguments = Arguments.call("/org/freedesktop/portal/desktop/request/1_5/t1", title: "Pick a Picture", options: [
            "accept_label": .string("_Import"),
            "modal": .boolean(false),
            "multiple": .boolean(true),
            "filters": Arguments.array([images, text], of: Arguments.filterType),
            "current_filter": text,
            "choices": Arguments.array([encoding, readOnly], of: choiceType),
            "current_folder": Arguments.bytes("/home/someone/Pictures"),
            "handle_token": .string("t1"),
        ])
        let request = try #require(FileChooserRequest(kind: .open, arguments: arguments))
        #expect(request.handle == "/org/freedesktop/portal/desktop/request/1_5/t1")
        #expect(request.appID == "org.example.App")
        #expect(request.parentWindow == "wayland:abc")
        #expect(request.title == "Pick a Picture")
        #expect(request.acceptLabel == "_Import")
        #expect(request.isModal == false)
        #expect(request.allowsMultiple)
        #expect(request.choosesFolders == false)
        #expect(request.filters == [
            FileFilter(name: "Images", rules: [.mimeType("image/*"), .glob("*.svg")]),
            FileFilter(name: "Text", rules: [.glob("*.txt")]),
        ])
        #expect(request.currentFilter == FileFilter(name: "Text", rules: [.glob("*.txt")]))
        #expect(request.choices.count == 2)
        #expect(request.choices[0].options.map(\.id) == ["utf8", "latin1"])
        #expect(request.choices[0].initial == "utf8")
        #expect(request.choices[1].isCheckbox)
        #expect(request.currentFolder?.path == "/home/someone/Pictures")
    }

    @Test func aSaveRequestOffersAName() throws {
        let arguments = Arguments.call("/r/1", options: [
            "current_name": .string("Untitled.txt"),
            "current_file": Arguments.bytes("/home/someone/Notes/Old.txt"),
        ])
        let request = try #require(FileChooserRequest(kind: .save, arguments: arguments))
        #expect(request.currentName == "Untitled.txt")
        #expect(request.currentFile?.path == "/home/someone/Notes/Old.txt")
        #expect(request.suggestedName == "Untitled.txt")
        #expect(request.displayTitle == "Save File")
        #expect(request.defaultAcceptLabel == "Save")
    }

    @Test func aSaveFilesRequestListsItsNames() throws {
        let files = Arguments.array([Arguments.bytes("a.txt"), Arguments.bytes("b.txt")], of: .array(.byte))
        let request = try #require(FileChooserRequest(kind: .saveFiles, arguments: Arguments.call("/r/2", options: ["files": files])))
        #expect(request.files == ["a.txt", "b.txt"])
    }

    @Test func wrongArgumentsAreNoRequest() {
        #expect(FileChooserRequest(kind: .open, arguments: [.string("no")]) == nil)
    }

    @Test func aFolderThatIsGoneStartsAtHome() {
        var request = FileChooserRequest(kind: .open, handle: "/r/3")
        request.currentFolder = URL(fileURLWithPath: "/no/such/folder", isDirectory: true)
        let home = URL(fileURLWithPath: "/home/someone", isDirectory: true)
        #expect(request.startFolder(home: home) == home)
        request.currentFolder = URL(fileURLWithPath: "/", isDirectory: true)
        #expect(request.startFolder(home: home).path == "/")
    }

    @Test func anAnswerBecomesTheReplyAndBack() throws {
        let filter = FileFilter(name: "Text", rules: [.glob("*.txt"), .mimeType("text/plain")])
        let response = FileChooserResponse(
            code: .success,
            uris: [URL(fileURLWithPath: "/home/someone/My Notes.txt")],
            choices: [("encoding", "latin1")],
            currentFilter: filter
        )
        let arguments = response.arguments
        #expect(arguments.first == .uint32(0))
        let uris = FileChooserRequest.options(arguments[1])["uris"]
        #expect(uris == .array(DBusMessageArgument.Array(type: .string, [.string("file:///home/someone/My%20Notes.txt")])!))
        #expect(FileChooserResponse(arguments: arguments) == response)
    }

    @Test func aCancelledAnswerHasNoFiles() {
        let arguments = FileChooserResponse.cancelled.arguments
        #expect(arguments.first == .uint32(1))
        #expect(FileChooserRequest.options(arguments[1]).isEmpty)
    }
}

@Suite(.enabled(if: PrivateBus.isAvailable, "Needs dbus-daemon"), .serialized)
struct FileChooserBackendTests {

    /// A backend on a bus of its own, with a presenter, and a connection to
    /// call it from as the portal does.
    func withBackend(
        _ presenter: @escaping FileChooserBackend.Presenter,
        _ body: (DBusConnection, FileChooserBackend) async throws -> Void
    ) async throws {
        let bus = try await PrivateBus.start()
        defer { bus.stop() }
        let service = try await DBusConnection.connect(to: bus.address)
        let backend = FileChooserBackend(connection: service, presenter: presenter)
        await backend.export()
        let owns = try await backend.requestName()
        #expect(owns)
        let portal = try await DBusConnection.connect(to: bus.address)
        try await body(portal, backend)
        await portal.close()
        await service.close()
    }

    func call(_ method: String, _ arguments: [DBusMessageArgument], on portal: DBusConnection) async throws -> FileChooserResponse? {
        let reply = try await portal.callMethod(
            destination: FileChooserBackend.busName,
            path: FileChooserBackend.path,
            interface: FileChooserBackend.interface,
            method: DBusMember(rawValue: method)!,
            arguments: arguments
        )
        return FileChooserResponse(arguments: reply)
    }

    @Test func openFileAnswersWithThePresentersFiles() async throws {
        let seen = Seen()
        try await withBackend({ request in
            await seen.add(request)
            return FileChooserResponse(code: .success, uris: [URL(fileURLWithPath: "/tmp/a.txt")])
        }) { portal, backend in
            let response = try await call("OpenFile", Arguments.call("/org/freedesktop/portal/desktop/request/1_1/a", options: ["multiple": .boolean(true)]), on: portal)
            #expect(response?.code == .success)
            #expect(response?.uris == [URL(string: "file:///tmp/a.txt")!])
            let requests = await seen.requests
            #expect(requests.map(\.kind) == [.open])
            #expect(requests.first?.allowsMultiple == true)
            #expect(await backend.requestsInProgress == 0)
        }
    }

    @Test func saveFileAndSaveFilesReachThePresenterAsSuch() async throws {
        let seen = Seen()
        try await withBackend({ request in
            await seen.add(request)
            return .cancelled
        }) { portal, _ in
            let saved = try await call("SaveFile", Arguments.call("/r/s1", options: ["current_name": .string("x.txt")]), on: portal)
            let savedSeveral = try await call("SaveFiles", Arguments.call("/r/s2", options: [:]), on: portal)
            #expect(saved?.code == .cancelled)
            #expect(savedSeveral?.code == .cancelled)
            #expect(await seen.requests.map(\.kind) == [.save, .saveFiles])
        }
    }

    @Test func closingTheRequestEndsItWithResponseTwo() async throws {
        try await withBackend({ _ in
            // A dialog the user never answers, until the request is closed.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
            }
            return .other
        }) { portal, backend in
            let handle = "/org/freedesktop/portal/desktop/request/1_1/closed"
            async let answer = call("OpenFile", Arguments.call(handle, options: [:]), on: portal)
            // The request object appears while the dialog is up.
            var closed = false
            for _ in 0 ..< 50 where !closed {
                do {
                    try await portal.callMethod(
                        destination: FileChooserBackend.busName,
                        path: DBusObjectPath(rawValue: handle)!,
                        interface: FileChooserBackend.requestInterface,
                        method: DBusMember(rawValue: "Close")!
                    )
                    closed = true
                } catch {
                    try await Task.sleep(for: .milliseconds(50))
                }
            }
            #expect(closed)
            let response = try await answer
            #expect(response?.code == .other)
            #expect(await backend.requestsInProgress == 0)
        }
    }

    @Test func wrongArgumentsAreRefused() async throws {
        try await withBackend({ _ in .cancelled }) { portal, _ in
            await #expect(throws: DBusError.self) {
                _ = try await call("OpenFile", [.string("no")], on: portal)
            }
        }
    }
}

/// The requests a presenter was given.
actor Seen {

    private(set) var requests: [FileChooserRequest] = []

    func add(_ request: FileChooserRequest) {
        requests.append(request)
    }
}

#endif
