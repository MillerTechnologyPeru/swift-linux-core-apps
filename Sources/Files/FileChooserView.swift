//
//  FileChooserView.swift
//  CoreApps
//

#if Native

import AppUI
import CoreAppsUI
import FilesCore
import FilesPortal
import Foundation

/// A window of the file chooser: the request it was opened for, or the
/// oldest one waiting when it's the first window and opened with none.
struct FileChooserWindow: View {

    @Binding var handle: String?

    @ObservedObject private var host = FileChooserHost.shared

    @Environment(\.openWindow) private var openWindow

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Group {
            if let handle, let dialog = host.dialogs[handle] {
                FileChooserView(request: dialog.request) { response in
                    host.complete(handle, with: response)
                    dismissWindow()
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            // The first window takes its request before it opens windows
            // for the others.
            if handle == nil, let dialog = host.claimNext() {
                handle = dialog.request.handle
            }
            host.register(openWindow)
            host.keepRunningBetweenDialogs()
        }
        .task { @MainActor in
            // Take a request, then close once it's over: answered here, or
            // closed by the app.
            while !Task.isCancelled {
                if let handle {
                    if host.dialog(for: handle) == nil {
                        dismissWindow()
                        return
                    }
                } else if let dialog = host.claimNext() {
                    handle = dialog.request.handle
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .onDisappear {
            // Closed by the window's own button: the app hears it cancelled.
            if let handle {
                host.complete(handle, with: .cancelled)
            }
        }
    }
}

/// Files' browsing as a dialog for another app: the places, a folder's
/// items as a list or grid, a search, and what the app asked for, which
/// are files or folders to open, or a name to save as.
struct FileChooserView: View {

    let request: FileChooserRequest

    /// Called once, with the answer.
    let done: (FileChooserResponse) -> Void

    @State private var folder: URL

    /// The folders visited before this one, for going back.
    @State private var history: [URL] = []

    @State private var selection: Set<URL> = []

    @State private var searchText = ""

    @State private var showsGrid = false

    /// The filter showing, as an index into the request's filters.
    @State private var filterIndex: Int

    @State private var name: String

    /// The answers to the app's choices, by choice.
    @State private var choices: [String: String]

    /// Files the user is asked about replacing, before saving over them.
    @State private var replacing: [URL] = []

    /// The item clicked last, and when: a second click soon after opens it.
    @State private var lastClick: (url: URL, time: Date)?

    private let places: [Location]

    init(request: FileChooserRequest, done: @escaping (FileChooserResponse) -> Void) {
        self.request = request
        self.done = done
        self._folder = State(initialValue: request.startFolder())
        self._name = State(initialValue: request.suggestedName)
        let current = request.currentFilter.flatMap { request.filters.firstIndex(of: $0) } ?? 0
        self._filterIndex = State(initialValue: request.filters.isEmpty ? -1 : current)
        var answers: [String: String] = [:]
        for choice in request.choices {
            answers[choice.id] = choice.initial.isEmpty ? (choice.isCheckbox ? "false" : choice.options.first?.id ?? "") : choice.initial
        }
        self._choices = State(initialValue: answers)
        var places = Location.standard()
        let desktop = UserFolders().url(for: .desktop)
        if FileManager.default.fileExists(atPath: desktop.path) {
            places.insert(Location(name: "Desktop", symbolName: UserFolder.desktop.symbolName, url: desktop), at: 1)
        }
        self.places = places
    }

    private var filter: FileFilter? {
        request.filters.indices.contains(filterIndex) ? request.filters[filterIndex] : nil
    }

    private var isSaving: Bool {
        request.kind == .save
    }

    var body: some View {
        let items = visibleItems()
        return VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 190)
                Divider()
                content(items)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer(items)
        }
        .frame(minWidth: 560, minHeight: 380)
        .confirmationDialog(
            replacing.count == 1 ? "Replace “\(replacing[0].lastPathComponent)”?" : "Replace \(replacing.count) files?",
            isPresented: isReplacing,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                let urls = replacing
                replacing = []
                finish(with: urls)
            }
            Button("Cancel", role: .cancel) { replacing = [] }
        } message: {
            Text("A file with that name already exists in “\(folder.lastPathComponent)”. Replacing it overwrites its contents.")
        }
    }

    private var isReplacing: Binding<Bool> {
        Binding(get: { !replacing.isEmpty }, set: { if !$0 { replacing = [] } })
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(request.displayTitle)
                .font(.headline)
                .lineLimit(1)
                .padding(.trailing, 4)
            Button {
                go(back: true)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(history.isEmpty)
            Button {
                let parent = folder.deletingLastPathComponent()
                if parent.path != folder.path { go(to: parent) }
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(folder.path == "/")
            pathBar
            Spacer(minLength: 8)
            TextField("Search", text: $searchText)
                .frame(width: 180)
            Picker("View", selection: $showsGrid) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "square.grid.2x2").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 84)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }

    /// The folders from the root down to this one, each a way up. In a
    /// deep folder the middle ones fold into “…”, which goes to the last
    /// of them.
    private var pathBar: some View {
        let ancestors = Location.ancestors(of: folder)
        let shown: [(url: URL, title: String)] = ancestors.count > 5
            ? [(ancestors[0], "Computer"), (ancestors[ancestors.count - 4], "…")] + ancestors.suffix(3).map { ($0, $0.lastPathComponent) }
            : ancestors.map { ($0, $0.path == "/" ? "Computer" : $0.lastPathComponent) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                    Button(step.title) {
                        go(to: step.url)
                    }
                    .plainButton()
                    .font(.footnote)
                    .foregroundStyle(index == shown.count - 1 ? Color.primary : Color.secondary)
                }
            }
        }
        // A scroll view takes all the height it's offered otherwise.
        .frame(height: 28)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        let bookmarks = Bookmarks.user().load()
        let volumes = Volume.mounted()
        return ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sectionTitle("Places")
                ForEach(places) { place in
                    placeRow(place.name, symbolName: place.symbolName, url: place.url)
                }
                if !bookmarks.isEmpty {
                    sectionTitle("Bookmarks")
                    ForEach(bookmarks) { bookmark in
                        placeRow(bookmark.name, symbolName: "bookmark", url: bookmark.url)
                    }
                }
                if !volumes.isEmpty {
                    sectionTitle("Volumes")
                    ForEach(volumes) { volume in
                        placeRow(volume.name, symbolName: "tray", url: volume.url)
                    }
                }
            }
            .padding(8)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(Color.secondary)
            .padding(.top, 8)
            .padding(.horizontal, 8)
    }

    private func placeRow(_ title: String, symbolName: String, url: URL) -> some View {
        let isCurrent = url.standardizedFileURL.path == folder.standardizedFileURL.path
        return Button {
            go(to: url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isCurrent ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .plainButton()
    }

    // MARK: Content

    /// The folder's items, or what a search of it finds, as the filter has
    /// them: folders always, to go into, and files of the kind showing.
    private func visibleItems() -> [FileItem] {
        let options = ListingOptions()
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let items: [FileItem]
        if query.isEmpty {
            items = (try? DirectoryListing.load(folder, options: options)) ?? []
        } else {
            let found = FileSearch.find(FileQuery(text: query), in: folder, limit: 200)
            items = DirectoryListing.sorted(found, by: .name)
        }
        guard let filter, !request.choosesFolders else { return items }
        return items.filter { $0.isFolder || filter.matches($0.name) }
    }

    /// Whether an item can be what's chosen: a folder when choosing
    /// folders, else a file.
    private func isChoosable(_ item: FileItem) -> Bool {
        request.choosesFolders ? item.isFolder : !item.isFolder
    }

    @ViewBuilder
    private func content(_ items: [FileItem]) -> some View {
        if items.isEmpty {
            EmptyState(searchText.isEmpty ? "Folder Is Empty" : "No Results", message: filter.map { "Showing \($0.name)." })
        } else if showsGrid {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 12) {
                    ForEach(items) { item in
                        cell(for: item) {
                            FileTile(item: item)
                        }
                    }
                }
                .padding(12)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        cell(for: item) {
                            FileRow(item: item, location: searchText.isEmpty ? nil : item.url.deletingLastPathComponent().path)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func cell<Label: View>(for item: FileItem, @ViewBuilder label: () -> Label) -> some View {
        let isSelected = selection.contains(item.url)
        return Button {
            click(item)
        } label: {
            label()
                .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                .cornerRadius(6)
                .contentShape(Rectangle())
        }
        .plainButton()
        .opacity(isChoosable(item) || item.isFolder ? 1 : 0.45)
    }

    /// Selects an item, or on a second click goes into a folder or chooses
    /// a file.
    private func click(_ item: FileItem) {
        let now = Date()
        if let lastClick, lastClick.url == item.url, now.timeIntervalSince(lastClick.time) < 0.5 {
            self.lastClick = nil
            if item.isFolder {
                go(to: item.url)
            } else if isChoosable(item) {
                selection = [item.url]
                if isSaving { name = item.name }
                accept()
            }
            return
        }
        lastClick = (item.url, now)
        if !isChoosable(item) && !item.isFolder { return }
        if request.allowsMultiple, isChoosable(item) {
            if selection.remove(item.url) == nil { selection.insert(item.url) }
        } else {
            selection = [item.url]
        }
        if isSaving, !item.isFolder { name = item.name }
    }

    private func go(to url: URL) {
        guard url.standardizedFileURL.path != folder.standardizedFileURL.path else { return }
        history.append(folder)
        folder = url
        selection = []
        searchText = ""
    }

    private func go(back: Bool) {
        guard let previous = history.popLast() else { return }
        folder = previous
        selection = []
        searchText = ""
    }

    // MARK: Footer

    private func footer(_ items: [FileItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSaving {
                HStack(spacing: 8) {
                    Text("Name")
                    TextField("Name", text: $name)
                        .onSubmit(accept)
                }
                if let problem = nameProblem, problem != .empty {
                    Text(problem.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            HStack(spacing: 12) {
                ForEach(request.choices, id: \.id) { choice in
                    choiceControl(choice)
                }
                if !request.filters.isEmpty, !request.choosesFolders {
                    Picker("Show", selection: $filterIndex) {
                        ForEach(Array(request.filters.enumerated()), id: \.offset) { index, filter in
                            Text(filter.name).tag(index)
                        }
                    }
                    .frame(maxWidth: 220)
                }
                Spacer(minLength: 0)
                Button("Cancel") { done(.cancelled) }
                    .keyboardShortcut(.cancelAction)
                Button(acceptLabel) { accept() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAccept(items))
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func choiceControl(_ choice: FileChooserRequest.Choice) -> some View {
        let answer = Binding(
            get: { choices[choice.id] ?? "" },
            set: { choices[choice.id] = $0 }
        )
        if choice.isCheckbox {
            Toggle(choice.label, isOn: Binding(get: { answer.wrappedValue == "true" }, set: { answer.wrappedValue = $0 ? "true" : "false" }))
        } else {
            Picker(choice.label, selection: answer) {
                ForEach(choice.options, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .frame(maxWidth: 220)
        }
    }

    /// The app's label for the button, without its mnemonic's underscore.
    private var acceptLabel: String {
        guard let label = request.acceptLabel else { return request.defaultAcceptLabel }
        return label.replacingOccurrences(of: "__", with: "\u{0}").replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "\u{0}", with: "_")
    }

    private var nameProblem: FileName.Problem? {
        FileName.problem(with: FileName.cleaned(name))
    }

    private func canAccept(_ items: [FileItem]) -> Bool {
        switch request.kind {
        case .save:
            return nameProblem == nil
        case .saveFiles:
            return !request.files.isEmpty
        case .open:
            if request.choosesFolders { return true }
            return !selection.isEmpty
        }
    }

    /// Chooses what's selected, or goes into a selected folder.
    private func accept() {
        switch request.kind {
        case .open:
            if request.choosesFolders {
                let folders = selection.isEmpty ? [folder] : Array(selection).sorted { $0.path < $1.path }
                finish(with: folders)
                return
            }
            let chosen = Array(selection).sorted { $0.path < $1.path }
            if chosen.count == 1, isFolder(chosen[0]) {
                go(to: chosen[0])
                return
            }
            let files = chosen.filter { !isFolder($0) }
            guard !files.isEmpty else { return }
            finish(with: files)
        case .save:
            guard nameProblem == nil else { return }
            let target = folder.appendingPathComponent(FileName.cleaned(name))
            if isFolder(target) {
                go(to: target)
            } else if FileManager.default.fileExists(atPath: target.path) {
                replacing = [target]
            } else {
                finish(with: [target])
            }
        case .saveFiles:
            let destination = selection.count == 1 && isFolder(selection.first!) ? selection.first! : folder
            let targets = request.files.map { destination.appendingPathComponent($0) }
            let existing = targets.filter { FileManager.default.fileExists(atPath: $0.path) }
            if existing.isEmpty {
                finish(with: targets)
            } else {
                replacing = existing
                // Saving goes ahead with every file once the user agrees.
                pendingTargets = targets
            }
        }
    }

    /// Where `saveFiles` writes, once the user agrees to replacing.
    @State private var pendingTargets: [URL] = []

    private func finish(with urls: [URL]) {
        let urls = request.kind == .saveFiles && !pendingTargets.isEmpty ? pendingTargets : urls
        let answers = request.choices.map { (id: $0.id, value: choices[$0.id] ?? "") }
        done(FileChooserResponse(code: .success, uris: urls.map(\.standardizedFileURL), choices: answers, currentFilter: filter))
    }

    private func isFolder(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

#endif
