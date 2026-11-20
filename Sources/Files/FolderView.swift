//
//  FolderView.swift
//  CoreApps
//

#if Native

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// A folder's items: folders open in place, files show what's known of them.
struct FolderView: View {

    let folder: URL

    let locations: [Location]

    @State private var showsHidden = false

    @State private var sort = FileSort.name

    @State private var inspected: FileItem?

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
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(item: $inspected) { item in
                FileInfoView(item: item) { inspected = nil }
            }
    }

    /// The listing, read each time the view is evaluated: a folder's
    /// contents change under it.
    @ViewBuilder
    private var content: some View {
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
                    } else {
                        Button {
                            inspected = item
                        } label: {
                            FileRow(item: item)
                        }
                        .plainButton()
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
