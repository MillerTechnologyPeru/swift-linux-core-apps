//
//  ImagesApp.swift
//  CoreApps
//

// The image viewer reads files from anywhere, which a guest can't yet: it
// is a program for now, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation
import ImagesCore

/// Somewhere the viewer shows.
enum Route: Hashable {
    case folder(URL)
    case image(URL)
}

/// The image viewer.
public struct ImagesApp: App {

    public init() { }

    /// The image or folder named on the command line: how the file manager
    /// opens an image here.
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
        WindowGroup("Images") {
            LibraryView(opening: Self.argument)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            LibraryView(opening: Self.argument)
        }
        #endif
    }
}

/// A folder's images, and the folders and images opened from it.
public struct LibraryView: View {

    @State private var path: [Route]

    @StateObject private var store = ImageStore()

    private let root: URL

    /// - Parameter url: An image to show at first, or a folder to start
    ///   in; the user's pictures when there's neither.
    public init(opening url: URL? = nil) {
        var isDirectory: ObjCBool = false
        if let url, FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                root = url
                _path = State(initialValue: [])
            } else {
                root = url.deletingLastPathComponent()
                _path = State(initialValue: [.image(url)])
            }
        } else {
            let pictures = UserFolders().url(for: .pictures)
            let exists = FileManager.default.fileExists(atPath: pictures.path)
            root = exists ? pictures : URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            _path = State(initialValue: [])
        }
    }

    public var body: some View {
        NavigationStack(path: $path) {
            FolderGrid(folder: root, title: "Images", path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .folder(folder):
                        FolderGrid(folder: folder, title: folder.lastPathComponent, path: $path)
                    case let .image(image):
                        ViewerView(opening: image)
                    }
                }
        }
        .environmentObject(store)
    }
}

/// A folder: the folders in it as rows, and its images as a grid.
struct FolderGrid: View {

    let folder: URL

    let title: String

    /// The places open. Folders and images are opened by adding to it,
    /// with buttons: a link would draw an arrow of its own on each.
    @Binding var path: [Route]

    @EnvironmentObject private var store: ImageStore

    var body: some View {
        let contents = ImageStore.contents(of: folder)
        return Group {
            if contents.folders.isEmpty && contents.images.isEmpty {
                EmptyState("No Images", message: "There are no images in “\(folder.lastPathComponent)”.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(contents.folders) { item in
                            Button {
                                path.append(.folder(item.url))
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 24)
                                    Text(item.name)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                .frame(minHeight: Metrics.minimumTarget)
                                .padding(.horizontal, 16)
                            }
                            .plainButton()
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                            ForEach(contents.images) { item in
                                Button {
                                    path.append(.image(item.url))
                                } label: {
                                    Thumbnail(url: item.url, name: item.name)
                                }
                                .plainButton()
                            }
                        }
                        .padding(4)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

/// An image small, filling a square; its name if it can't be drawn.
struct Thumbnail: View {

    let url: URL

    let name: String

    @EnvironmentObject private var store: ImageStore

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            switch store.image(at: url) {
            case let .success(loaded):
                loaded.image
                    .resizable()
                    .scaledToFill()
            case .failure:
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.secondary)
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(4)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 100)
        .clipped()
    }
}

#endif
