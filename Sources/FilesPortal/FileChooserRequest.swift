//
//  FileChooserRequest.swift
//  CoreApps
//

import FilesCore
import Foundation

/// An app's request for files, as the desktop's portal hands it to the
/// file chooser: what to show, what to offer, where to start.
public struct FileChooserRequest: Hashable, Sendable {

    /// What the app asked for.
    public enum Kind: String, Hashable, Sendable {

        /// Files or folders to read: `OpenFile`.
        case open

        /// Where to write one file: `SaveFile`.
        case save

        /// A folder to write several named files into: `SaveFiles`.
        case saveFiles
    }

    /// A question the app adds to the dialog, such as an encoding.
    public struct Choice: Hashable, Sendable {

        public struct Option: Hashable, Sendable {

            public var id: String

            public var label: String

            public init(id: String, label: String) {
                self.id = id
                self.label = label
            }
        }

        public var id: String

        public var label: String

        /// The answers to pick from. None makes the choice a checkbox,
        /// answered `"true"` or `"false"`.
        public var options: [Option]

        /// The answer picked at first.
        public var initial: String

        public init(id: String, label: String, options: [Option] = [], initial: String = "") {
            self.id = id
            self.label = label
            self.options = options
            self.initial = initial
        }

        public var isCheckbox: Bool {
            options.isEmpty
        }
    }

    public var kind: Kind

    /// The object path of the request, which the portal closes it through;
    /// unique while the request lasts.
    public var handle: String

    /// The app asking, such as `org.gnome.TextEditor`; empty for an app
    /// that isn't sandboxed.
    public var appID: String

    /// The app's window, as `wayland:handle` or `x11:id`; empty if none.
    public var parentWindow: String

    /// The dialog's title.
    public var title: String

    /// The label of the button that chooses, such as “Import”.
    public var acceptLabel: String?

    /// Whether the dialog should keep the app's window from being used.
    public var isModal = true

    /// Whether several files may be chosen.
    public var allowsMultiple = false

    /// Whether folders are chosen rather than files.
    public var choosesFolders = false

    public var filters: [FileFilter] = []

    /// The filter shown at first.
    public var currentFilter: FileFilter?

    public var choices: [Choice] = []

    /// The name a saved file is offered.
    public var currentName: String?

    /// The folder to start in.
    public var currentFolder: URL?

    /// The file being saved over, when saving an existing file.
    public var currentFile: URL?

    /// The names of the files saved into the folder chosen, for
    /// `saveFiles`.
    public var files: [String] = []

    public init(kind: Kind, handle: String, appID: String = "", parentWindow: String = "", title: String = "") {
        self.kind = kind
        self.handle = handle
        self.appID = appID
        self.parentWindow = parentWindow
        self.title = title
    }

    /// The label of the button that chooses, when the app gave none.
    public var defaultAcceptLabel: String {
        switch kind {
        case .open: choosesFolders ? "Choose" : "Open"
        case .save, .saveFiles: "Save"
        }
    }

    /// The dialog's title, when the app gave none.
    public var displayTitle: String {
        guard title.isEmpty else { return title }
        switch kind {
        case .open: return choosesFolders ? "Choose a Folder" : (allowsMultiple ? "Open Files" : "Open File")
        case .save: return "Save File"
        case .saveFiles: return "Save Files"
        }
    }

    /// The folder the dialog opens at: the app's, the folder of the file
    /// being saved over, or the home folder.
    public func startFolder(home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)) -> URL {
        let candidates = [currentFolder, currentFile?.deletingLastPathComponent()].compactMap { $0 }
        for candidate in candidates {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }
        return home
    }

    /// The name offered for a saved file: the app's, else the name of the
    /// file being saved over.
    public var suggestedName: String {
        currentName ?? currentFile?.lastPathComponent ?? ""
    }
}

/// What the file chooser answers an app with.
public struct FileChooserResponse: Hashable, Sendable {

    /// How the request ended, as the portal numbers it.
    public enum Code: UInt32, Hashable, Sendable {
        case success = 0
        case cancelled = 1
        /// Ended some other way, as when the app closed the request.
        case other = 2
    }

    public var code: Code

    /// The files or folders chosen, or where to save.
    public var uris: [URL]

    /// The answers to the app's choices, by choice.
    public var choices: [(id: String, value: String)]

    /// The filter showing when the user chose.
    public var currentFilter: FileFilter?

    public init(code: Code, uris: [URL] = [], choices: [(id: String, value: String)] = [], currentFilter: FileFilter? = nil) {
        self.code = code
        self.uris = uris
        self.choices = choices
        self.currentFilter = currentFilter
    }

    public static let cancelled = FileChooserResponse(code: .cancelled)

    public static let other = FileChooserResponse(code: .other)

    public static func == (lhs: FileChooserResponse, rhs: FileChooserResponse) -> Bool {
        lhs.code == rhs.code && lhs.uris == rhs.uris && lhs.currentFilter == rhs.currentFilter
            && lhs.choices.map(\.id) == rhs.choices.map(\.id) && lhs.choices.map(\.value) == rhs.choices.map(\.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
        hasher.combine(uris)
    }
}
