//
//  FolderView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// A folder's items: folders open in place, files show what's known of them.
/// Items are renamed and trashed from their menus, and folders made from the
/// toolbar's.
struct FolderView: View {

    let folder: URL

    let locations: [Location]

    @State private var showsHidden = false

    @State private var sort = FileSort.name

    @State private var inspected: FileItem?

    /// The item being renamed.
    @State private var renamed: FileItem?

    @State private var namesNewFolder = false

    /// What went wrong with the last change, shown until dismissed.
    @State private var failure: String?

    /// Counts the changes made here, so the listing is read again.
    @State private var changes = 0

    var body: some View {
        content
            .navigationTitle(Location.title(for: folder, among: locations))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            Text("Name").tag(FileSort.name)
                            Text("Date").tag(FileSort.modified)
                            Text("Size").tag(FileSort.size)
                        }
                        Toggle("Show Hidden Files", isOn: $showsHidden)
                        Button("New Folder") {
                            namesNewFolder = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(item: $inspected) { item in
                FileInfoView(item: item) { inspected = nil }
            }
            .sheet(item: $renamed) { item in
                NameView(title: "Rename", name: item.name, confirm: "Rename") { name in
                    renamed = nil
                    if let name {
                        change { try FileOperations.rename(item.url, to: name) }
                    }
                }
            }
            .sheet(isPresented: $namesNewFolder) {
                NameView(title: "New Folder", name: "New Folder", confirm: "Create") { name in
                    namesNewFolder = false
                    if let name {
                        change { try FileOperations.createFolder(named: name, in: folder) }
                    }
                }
            }
            .alert("Couldn't Do That", isPresented: failureIsShown) {
                Button("OK") { failure = nil }
            } message: {
                Text(failure ?? "")
            }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    /// Makes a change to the folder, showing why if it can't be made.
    private func change(_ body: () throws -> Void) {
        do {
            try body()
        } catch {
            failure = error.localizedDescription
        }
        changes += 1
    }

    /// What can be done with an item, from its menu.
    @ViewBuilder
    private func actions(for item: FileItem) -> some View {
        Button("Get Info") {
            inspected = item
        }
        Button("Rename") {
            renamed = item
        }
        Button("Move to Trash", role: .destructive) {
            change { try FileOperations.moveToTrash(item.url) }
        }
    }

    /// The listing, read each time the view is evaluated: a folder's
    /// contents change under it.
    @ViewBuilder
    private var content: some View {
        // Reading the count is what has a change evaluate the view again.
        let _ = changes
        switch Result(catching: { try DirectoryListing.load(folder, showsHidden: showsHidden, sort: sort) }) {
        case let .success(items) where items.isEmpty:
            EmptyState("Folder Is Empty", message: showsHidden ? nil : "Hidden files aren't shown.")
        case let .success(items):
            List {
                ForEach(items) { item in
                    if item.isFolder {
                        NavigationLink(value: item.url) {
                            FileRow(item: item)
                        }
                        .contextMenu { actions(for: item) }
                    } else {
                        Button {
                            inspected = item
                        } label: {
                            FileRow(item: item)
                        }
                        .plainButton()
                        .contextMenu { actions(for: item) }
                    }
                }
            }
        case let .failure(error):
            EmptyState("Can't Open Folder", message: error.localizedDescription)
        }
    }
}

/// A row for a file or folder: its symbol, its name, and for a file its
/// size and when it changed.
struct FileRow: View {

    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: Metrics.minimumTarget - 8)
        .opacity(item.isHidden ? 0.6 : 1)
    }

    private var detail: String? {
        var parts: [String] = []
        if let size = item.size {
            parts.append(ByteCount.format(size))
        }
        if let modified = item.modified {
            parts.append(modified.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Asks for a name: an item's new one, or a new folder's.
struct NameView: View {

    let title: String

    let confirm: String

    /// Called with the name, or `nil` if the user thought better of it.
    let done: (String?) -> Void

    @State private var name: String

    init(title: String, name: String, confirm: String, done: @escaping (String?) -> Void) {
        self.title = title
        self.confirm = confirm
        self.done = done
        self._name = State(initialValue: name)
    }

    /// Why the name can't be used yet.
    private var problem: FileName.Problem? {
        FileName.problem(with: FileName.cleaned(name))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onSubmit(submit)
                } footer: {
                    if let problem, problem != .empty {
                        Text(problem.localizedDescription)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirm, action: submit)
                        .disabled(problem != nil)
                }
            }
        }
    }

    private func submit() {
        guard problem == nil else { return }
        done(FileName.cleaned(name))
    }
}

/// What's known of a file, until there are apps to open it with.
struct FileInfoView: View {

    let item: FileItem

    let done: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("Name", item.name)
                    row("Kind", item.kind.rawValue.capitalized)
                    if let size = item.size {
                        row("Size", ByteCount.format(size))
                    }
                    if let modified = item.modified {
                        row("Modified", modified.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                Section("Where") {
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .navigationTitle("Info")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
    }
}

#endif
