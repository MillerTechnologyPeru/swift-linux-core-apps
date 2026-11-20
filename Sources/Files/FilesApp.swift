//
//  FilesApp.swift
//  CoreApps
//

// The file manager sees the whole file system, which a guest can't: it is
// a native app only.
#if Native

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// The file manager.
public struct FilesApp: App {

    public init() { }

    /// A folder named on the command line, which the app opens at: how
    /// another program shows a folder in the file manager.
    private static var folderArgument: URL? {
        guard let argument = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) else {
            return nil
        }
        let url = URL(fileURLWithPath: argument, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }

    public var body: some Scene {
        WindowGroup("Files") {
            BrowserView(opening: Self.folderArgument)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
    }
}

/// The places to browse from, and the folders opened from them, one over
/// the other as on a phone.
public struct BrowserView: View {

    @State private var path: [URL]

    private let locations: [Location]

    /// - Parameter folder: A folder to show at first, over the locations.
    public init(opening folder: URL? = nil, locations: [Location] = Location.standard()) {
        self.locations = locations
        self._path = State(initialValue: folder.map { [$0] } ?? [])
    }

    public var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Locations") {
                    ForEach(locations) { location in
                        NavigationLink(value: location.url) {
                            HStack(spacing: 12) {
                                Image(systemName: location.symbolName)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 24)
                                Text(location.name)
                            }
                            .frame(minHeight: Metrics.minimumTarget - 16)
                        }
                    }
                }
            }
            .navigationTitle("Files")
            .navigationDestination(for: URL.self) { folder in
                FolderView(folder: folder, locations: locations)
            }
        }
    }
}

#endif
