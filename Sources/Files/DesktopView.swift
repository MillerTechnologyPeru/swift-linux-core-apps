//
//  DesktopView.swift
//  CoreApps
//

// The desktop is a layer of the screen under the windows, which only
// Cacao's host has: on Apple's SwiftUI it isn't built.
#if Native

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// What the desktop shows: the items in the Desktop folder, where they
/// sit, and the wallpaper behind them.
@MainActor
final class DesktopModel: ObservableObject {

    /// The Desktop folder, as `xdg-user-dirs` names it. It may not exist.
    let folder: URL

    @Published private(set) var items: [FileItem] = []

    @Published private(set) var preferences: DesktopPreferences

    /// The wallpaper's picture, read once per file chosen.
    @Published private(set) var wallpaper: Image?

    @Published var selection: Set<URL> = []

    /// What went wrong with the last change, shown until dismissed.
    @Published var failure: String?

    private let preferencesFile: URL

    private let arguments: [String]

    /// The wallpaper file `wallpaper` was read from.
    private var wallpaperFile: URL?

    init(
        folder: URL = UserFolders().url(for: .desktop),
        preferencesFile: URL = DesktopPreferences.file(),
        arguments: [String] = CommandLine.arguments
    ) {
        self.folder = folder
        self.preferencesFile = preferencesFile
        self.arguments = arguments
        self.preferences = DesktopPreferences.load(from: preferencesFile)
        reload()
        loadWallpaper()
    }

    /// Reads the folder again. A folder that's missing or can't be read
    /// shows no icons, and the places of the icons are kept for when it's
    /// back.
    func reload() {
        guard let listed = try? DirectoryListing.load(folder, options: ListingOptions()) else {
            if !items.isEmpty { items = [] }
            return
        }
        if listed != items {
            items = listed
            selection.formIntersection(listed.map(\.url))
        }
    }

    /// Keeps the desktop up to date with the folder, until cancelled. The
    /// folder is read every two seconds: there's no file watching yet.
    func follow() async {
        while !Task.isCancelled {
            reload()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    // MARK: Places

    /// Where each icon goes on a screen of a size.
    func places(in layout: DesktopLayout) -> [String: DesktopSlot] {
        layout.arrange(items.map(\.name), saved: preferences.positions)
    }

    /// Puts an icon in another place, and remembers it.
    func move(_ item: FileItem, to slot: DesktopSlot, in layout: DesktopLayout) {
        let placed = DesktopLayout.move(item.name, to: slot, in: places(in: layout))
        // Every icon's place is kept once one moves, so the others stay
        // where they were seen rather than flowing around it.
        preferences.positions = placed
        preferences.forget(allBut: Set(items.map(\.name)))
        save()
    }

    // MARK: Wallpaper

    /// Pictures in the Pictures folder that can be a wallpaper.
    var wallpaperChoices: [URL] {
        let pictures = UserFolders().url(for: .pictures)
        let items = (try? DirectoryListing.load(pictures)) ?? []
        return items.map(\.url).filter { $0.pathExtension.lowercased() == "png" }.prefix(12).map { $0 }
    }

    var wallpaperPath: String? {
        wallpaperFile?.path
    }

    /// Draws a picture behind the icons, or the accent gradient for `nil`.
    func setWallpaper(_ file: URL?) {
        preferences.wallpaper = file?.path
        save()
        loadWallpaper(ignoringArguments: true)
    }

    private func loadWallpaper(ignoringArguments: Bool = false) {
        let file = preferences.wallpaper(arguments: ignoringArguments ? [] : arguments)
        guard file != wallpaperFile else { return }
        wallpaperFile = file
        wallpaper = file.flatMap { try? Data(contentsOf: $0) }.map { Image(pngData: $0) }
    }

    private func save() {
        do {
            try preferences.save(to: preferencesFile)
        } catch {
            failure = error.localizedDescription
        }
    }

    // MARK: Changes

    func open(_ item: FileItem, openWindow: OpenWindowAction) {
        if item.isFolder {
            openWindow(id: FilesApp.browserID, value: item.url)
        } else {
            attempt { try FileOpener.open(item.url) }
        }
    }

    func newFolder() {
        attempt {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let taken = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            let created = try FileOperations.createFolder(named: FileName.unique("New Folder", among: taken), in: folder)
            selection = [created]
        }
    }

    func trash(_ items: [URL]) {
        attempt { _ = try FileOperations.moveToTrash(items) }
    }

    private func attempt(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            failure = error.localizedDescription
        }
        reload()
    }
}

/// The desktop: the wallpaper, and the Desktop folder's items as icons
/// that open with a double click and move by dragging.
struct DesktopView: View {

    @StateObject private var model = DesktopModel()

    @Environment(\.openWindow) private var openWindow

    /// How far the icon being dragged has moved.
    @State private var drag: (name: String, offset: CGSize)?

    /// The icon clicked last, and when: a second click soon after opens it.
    @State private var lastClick: (url: URL, time: Date)?

    var body: some View {
        GeometryReader { geometry in
            let layout = DesktopLayout(size: (Double(geometry.size.width), Double(geometry.size.height)))
            let places = model.places(in: layout)
            ZStack(alignment: .topLeading) {
                background
                ForEach(model.items) { item in
                    if let slot = places[item.name] {
                        icon(for: item, at: slot, in: layout)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .task { await model.follow() }
        .alert("Couldn't Do That", isPresented: failureIsShown) {
            Button("OK") { model.failure = nil }
        } message: {
            Text(model.failure ?? "")
        }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })
    }

    // MARK: Background

    private var background: some View {
        Wallpaper(image: model.wallpaper)
            .contentShape(Rectangle())
            .onTapGesture { model.selection = [] }
            .contextMenu { desktopMenu }
    }

    @ViewBuilder
    private var desktopMenu: some View {
        Button("New Folder") { model.newFolder() }
        // Files has no clipboard shared between its windows yet.
        Button("Paste") { }
            .disabled(true)
        Divider()
        Menu("Change Wallpaper") {
            Button("Accent Gradient") { model.setWallpaper(nil) }
            let choices = model.wallpaperChoices
            if !choices.isEmpty {
                Divider()
                ForEach(choices, id: \.self) { file in
                    Button(file.lastPathComponent) { model.setWallpaper(file) }
                }
            }
        }
        Divider()
        Button("Open Desktop in Files") {
            openWindow(id: FilesApp.browserID, value: model.folder)
        }
    }

    // MARK: Icons

    private func icon(for item: FileItem, at slot: DesktopSlot, in layout: DesktopLayout) -> some View {
        let center = layout.center(of: slot)
        let offset = drag?.name == item.name ? drag!.offset : .zero
        return DesktopIcon(item: item, isSelected: model.selection.contains(item.url))
            .frame(width: CGFloat(layout.cellSize.width) - 8, height: CGFloat(layout.cellSize.height) - 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if moved(value.translation) {
                            drag = (item.name, value.translation)
                        }
                    }
                    .onEnded { value in
                        drag = nil
                        if moved(value.translation) {
                            let target = (center.x + Double(value.translation.width), center.y + Double(value.translation.height))
                            model.move(item, to: layout.slot(nearest: target), in: layout)
                            model.selection = [item.url]
                        } else {
                            click(item)
                        }
                    }
            )
            .contextMenu { actions(for: item) }
            .position(x: CGFloat(center.x) + offset.width, y: CGFloat(center.y) + offset.height)
    }

    /// Whether a press moved far enough to be a drag rather than a click.
    private func moved(_ translation: CGSize) -> Bool {
        abs(translation.width) > 4 || abs(translation.height) > 4
    }

    /// Selects an icon, or opens it on a second click.
    private func click(_ item: FileItem) {
        let now = Date()
        if let lastClick, lastClick.url == item.url, now.timeIntervalSince(lastClick.time) < 0.5 {
            self.lastClick = nil
            model.open(item, openWindow: openWindow)
        } else {
            lastClick = (item.url, now)
            model.selection = [item.url]
        }
    }

    @ViewBuilder
    private func actions(for item: FileItem) -> some View {
        Button("Open") { model.open(item, openWindow: openWindow) }
        if !item.isFolder {
            Button("Show in Files") { openWindow(id: FilesApp.browserID, value: model.folder) }
        }
        Divider()
        Button("Move to Trash", role: .destructive) {
            let items = model.selection.contains(item.url) ? Array(model.selection) : [item.url]
            model.trash(items)
        }
    }
}

/// An item on the desktop: a large symbol over its name, which stays
/// legible on any wallpaper.
struct DesktopIcon: View {

    let item: FileItem

    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 38))
                .foregroundStyle(item.isFolder ? Color.accentColor : Color.white)
                .frame(width: 56, height: 50)
                .background(isSelected ? Color.black.opacity(0.25) : Color.clear)
                .cornerRadius(8)
            Text(item.name)
                .font(.caption)
                .foregroundStyle(Color.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(isSelected ? Color.accentColor : Color.clear)
                .cornerRadius(4)
                .shadow(color: Color.black.opacity(isSelected ? 0 : 0.8), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(item.isHidden ? 0.5 : 1)
    }
}

/// What's behind the icons: a picture, or a gradient in the accent color
/// that follows light and dark, as the shell's stand-in desktop drew.
struct Wallpaper: View {

    let image: Image?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(gradient)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// The accent color fading into a neutral ground from the top left.
    private var gradient: LinearGradient {
        let isDark = colorScheme == .dark
        let ground = isDark ? Color(white: 0.11) : Color(white: 0.86)
        let tint = Color.accentColor.mix(with: ground, by: isDark ? 0.55 : 0.45)
        return LinearGradient(
            gradient: Gradient(colors: [tint, ground.mix(with: tint, by: 0.15), ground]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#endif
