//
//  EditorApp.swift
//  CoreApps
//

// The text editor finds and writes its files itself, which a guest can't
// yet: it is a program for now, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation
import TextCore

/// Somewhere the editor shows.
enum EditorRoute: Hashable {
    case folder(URL)
    case document(URL)
}

/// The text editor.
public struct EditorApp: App {

    public init() { }

    /// The file or folder named on the command line: how the file manager
    /// opens a text file here.
    private static var argument: URL? {
        guard let argument = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            return nil
        }
        let url = URL(fileURLWithPath: argument).standardizedFileURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Text Editor") {
            DocumentsView(opening: Self.argument)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            DocumentsView(opening: Self.argument)
        }
        #endif
    }
}

/// A folder's text files, and the folders and documents opened from it.
public struct DocumentsView: View {

    @State private var path: [EditorRoute]

    private let root: URL

    /// - Parameter url: A file to edit at first, or a folder to start in;
    ///   the user's documents when there's neither.
    public init(opening url: URL? = nil) {
        var isDirectory: ObjCBool = false
        if let url, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                root = url
                _path = State(initialValue: [])
            } else {
                root = url.deletingLastPathComponent()
                _path = State(initialValue: [.document(url)])
            }
        } else {
            let documents = UserFolders().url(for: .documents)
            let exists = FileManager.default.fileExists(atPath: documents.path)
            root = exists ? documents : URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            _path = State(initialValue: [])
        }
    }

    public var body: some View {
        NavigationStack(path: $path) {
            DocumentList(folder: root, title: "Text Editor", path: $path)
                .navigationDestination(for: EditorRoute.self) { route in
                    switch route {
                    case let .folder(folder):
                        DocumentList(folder: folder, title: folder.lastPathComponent, path: $path)
                    case let .document(url):
                        EditorScreen(url: url)
                    }
                }
        }
    }
}

/// A folder: its folders, and its text files to open.
struct DocumentList: View {

    let folder: URL

    let title: String

    @Binding var path: [EditorRoute]

    @State private var failure: String?

    /// Counts the documents made here, so the listing is read again.
    @State private var changes = 0

    var body: some View {
        let _ = changes
        let items = (try? DirectoryListing.load(folder)) ?? []
        let shown = items.filter { $0.isFolder || $0.kind == .text }
        return Group {
            if shown.isEmpty {
                EmptyState("No Documents", message: "There are no text files in “\(folder.lastPathComponent)”.")
            } else {
                List {
                    ForEach(shown) { item in
                        Button {
                            path.append(item.isFolder ? .folder(item.url) : .document(item.url))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.isFolder ? "folder" : "doc")
                                    .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .lineLimit(1)
                                    if let detail = detail(of: item) {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                                if item.isFolder {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .frame(minHeight: Metrics.minimumTarget - 8)
                        }
                        .plainButton()
                    }
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    do {
                        let url = try Document.create(in: folder)
                        changes += 1
                        path.append(.document(url))
                    } catch {
                        failure = error.localizedDescription
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Couldn't Make a Document", isPresented: failureIsShown) {
            Button("OK") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    private func detail(of item: FileItem) -> String? {
        var parts: [String] = []
        if let size = item.size { parts.append(ByteCount.format(size)) }
        if let modified = item.modified { parts.append(modified.formatted(date: .abbreviated, time: .omitted)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// A document, or why it isn't open.
struct EditorScreen: View {

    let url: URL

    /// The document, read once when the screen is made.
    @State private var opened: Result<Document, DocumentFailure>

    init(url: URL) {
        self.url = url
        let result: Result<Document, DocumentFailure>
        do {
            result = .success(try Document(url: url))
        } catch let failure as DocumentFailure {
            result = .failure(failure)
        } catch {
            result = .failure(.system(error.localizedDescription))
        }
        _opened = State(initialValue: result)
    }

    var body: some View {
        switch opened {
        case let .success(document):
            EditorView(document: document)
        case let .failure(failure):
            EmptyState("Can't Open Document", message: failure.message)
                .navigationTitle(url.lastPathComponent)
        }
    }
}

#endif
