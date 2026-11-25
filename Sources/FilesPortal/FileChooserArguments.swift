//
//  FileChooserArguments.swift
//  CoreApps
//

// The file chooser's requests and answers as the portal's D-Bus arguments.
// Off the platforms with a D-Bus package, which are Linux and macOS, there
// is no portal to serve.
#if canImport(DBus)

import DBus
import FilesCore
import Foundation

extension FileChooserRequest {

    /// A request from the arguments of `OpenFile`, `SaveFile` or
    /// `SaveFiles`: `(o handle, s app_id, s parent_window, s title,
    /// a{sv} options)`. Options of the wrong type are ignored.
    public init?(kind: Kind, arguments: [DBusMessageArgument]) {
        guard arguments.count == 5,
              case let .objectPath(handle) = arguments[0],
              case let .string(appID) = arguments[1],
              case let .string(parentWindow) = arguments[2],
              case let .string(title) = arguments[3] else {
            return nil
        }
        self.init(kind: kind, handle: handle.rawValue, appID: appID, parentWindow: parentWindow, title: title)
        let options = Self.options(arguments[4])
        if case let .string(label)? = options["accept_label"], !label.isEmpty { acceptLabel = label }
        if case let .boolean(modal)? = options["modal"] { isModal = modal }
        if case let .boolean(multiple)? = options["multiple"] { allowsMultiple = multiple }
        if case let .boolean(directory)? = options["directory"] { choosesFolders = directory }
        if case let .array(filters)? = options["filters"] {
            self.filters = filters.compactMap(Self.filter)
        }
        if let filter = options["current_filter"].flatMap(Self.filter) { currentFilter = filter }
        if case let .array(choices)? = options["choices"] {
            self.choices = choices.compactMap(Self.choice)
        }
        if case let .string(name)? = options["current_name"] { currentName = name }
        if let path = options["current_folder"].flatMap(Self.path) { currentFolder = URL(fileURLWithPath: path, isDirectory: true) }
        if let path = options["current_file"].flatMap(Self.path) { currentFile = URL(fileURLWithPath: path) }
        if case let .array(files)? = options["files"] {
            self.files = files.compactMap(Self.path).map { ($0 as NSString).lastPathComponent }
        }
    }

    /// An `a{sv}`'s values by key, out of their variants.
    static func options(_ argument: DBusMessageArgument) -> [String: DBusMessageArgument] {
        guard case let .dictionary(dictionary) = argument else { return [:] }
        var options: [String: DBusMessageArgument] = [:]
        for entry in dictionary {
            guard case let .string(key) = entry.key else { continue }
            var value = entry.value
            while case let .variant(variant) = value { value = variant.element }
            options[key] = value
        }
        return options
    }

    /// A filter from a `(sa(us))`: its name, and rules that are globs (0)
    /// or MIME types (1).
    static func filter(_ argument: DBusMessageArgument) -> FileFilter? {
        guard case let .struct(structure) = argument, structure.count == 2,
              case let .string(name) = structure[0],
              case let .array(rules) = structure[1] else {
            return nil
        }
        let parsed = rules.compactMap { rule -> FileFilter.Rule? in
            guard case let .struct(pair) = rule, pair.count == 2,
                  case let .uint32(kind) = pair[0], case let .string(value) = pair[1] else {
                return nil
            }
            switch kind {
            case 0: return .glob(value)
            case 1: return .mimeType(value)
            default: return nil
            }
        }
        return FileFilter(name: name, rules: parsed)
    }

    /// A choice from an `(ssa(ss)s)`: id, label, options and the initial
    /// answer.
    static func choice(_ argument: DBusMessageArgument) -> Choice? {
        guard case let .struct(structure) = argument, structure.count == 4,
              case let .string(id) = structure[0],
              case let .string(label) = structure[1],
              case let .array(options) = structure[2],
              case let .string(initial) = structure[3] else {
            return nil
        }
        let parsed = options.compactMap { option -> Choice.Option? in
            guard case let .struct(pair) = option, pair.count == 2,
                  case let .string(id) = pair[0], case let .string(label) = pair[1] else {
                return nil
            }
            return Choice.Option(id: id, label: label)
        }
        return Choice(id: id, label: label, options: parsed, initial: initial)
    }

    /// A path from an `ay`, which ends in a NUL byte.
    static func path(_ argument: DBusMessageArgument) -> String? {
        guard case let .array(bytes) = argument else { return nil }
        var data = bytes.compactMap { element -> UInt8? in
            if case let .byte(byte) = element { return byte }
            return nil
        }
        while data.last == 0 { data.removeLast() }
        guard !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

extension FileFilter {

    /// The filter as a `(sa(us))`.
    var argument: DBusMessageArgument {
        let rules = rules.map { rule -> DBusMessageArgument in
            switch rule {
            case let .glob(pattern):
                .struct(DBusMessageArgument.Structure([.uint32(0), .string(pattern)])!)
            case let .mimeType(type):
                .struct(DBusMessageArgument.Structure([.uint32(1), .string(type)])!)
            }
        }
        let ruleType = DBusSignature.ValueType.struct(DBusSignature.StructureType([.uint32, .string])!)
        return .struct(DBusMessageArgument.Structure([
            .string(name),
            .array(DBusMessageArgument.Array(type: ruleType, rules)!),
        ])!)
    }
}

extension FileChooserResponse {

    /// The reply's arguments: `(u response, a{sv} results)`, with `uris`,
    /// and `choices` and `current_filter` when there are some.
    public var arguments: [DBusMessageArgument] {
        var results: [DBusMessageArgument.Dictionary.Entry] = []
        func add(_ key: String, _ value: DBusMessageArgument) {
            results.append(.init(key: .string(key), value: .variant(DBusMessageArgument.Variant(value))))
        }
        if code == .success {
            add("uris", .array(DBusMessageArgument.Array(type: .string, uris.map { .string($0.absoluteString) })!))
            if !choices.isEmpty {
                let pairs = choices.map { DBusMessageArgument.struct(DBusMessageArgument.Structure([.string($0.id), .string($0.value)])!) }
                let pairType = DBusSignature.ValueType.struct(DBusSignature.StructureType([.string, .string])!)
                add("choices", .array(DBusMessageArgument.Array(type: pairType, pairs)!))
            }
            if let currentFilter {
                add("current_filter", currentFilter.argument)
            }
        }
        let dictionary = DBusMessageArgument.Dictionary(keyType: .string, valueType: .variant, results)!
        return [.uint32(code.rawValue), .dictionary(dictionary)]
    }

    /// A response from a reply's arguments: how a test, or an app, reads
    /// one.
    public init?(arguments: [DBusMessageArgument]) {
        guard arguments.count == 2, case let .uint32(raw) = arguments[0], let code = Code(rawValue: raw) else {
            return nil
        }
        let results = FileChooserRequest.options(arguments[1])
        var uris: [URL] = []
        if case let .array(strings)? = results["uris"] {
            uris = strings.compactMap { $0.stringValue.flatMap(URL.init(string:)) }
        }
        var choices: [(id: String, value: String)] = []
        if case let .array(pairs)? = results["choices"] {
            for pair in pairs {
                if case let .struct(structure) = pair, structure.count == 2,
                   case let .string(id) = structure[0], case let .string(value) = structure[1] {
                    choices.append((id, value))
                }
            }
        }
        let filter = results["current_filter"].flatMap(FileChooserRequest.filter)
        self.init(code: code, uris: uris, choices: choices, currentFilter: filter)
    }
}

#endif
