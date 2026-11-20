//
//  TrashView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// What's in the trash: each item can go back where it was, or for good.
struct TrashView: View {

    @EnvironmentObject private var model: FilesModel

    @State private var isEmptying = false

    private let trash = Trash.home()

    var body: some View {
        let _ = model.changes
        let items = trash.items()
        return content(items)
            .navigationTitle("Trash")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Restore All") {
                            model.perform { .restored(try items.map { try trash.restore($0) }, trash) }
                        }
                        Button("Empty Trash…", role: .destructive) { isEmptying = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .disabled(items.isEmpty)
                }
            }
            .confirmationDialog("Empty the trash?", isPresented: $isEmptying, titleVisibility: .visible) {
                Button("Empty Trash", role: .destructive) {
                    model.attempt { try trash.empty() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Everything in it is deleted for good.")
            }
    }

    @ViewBuilder
    private func content(_ items: [Trash.Item]) -> some View {
        if items.isEmpty {
            EmptyState("Trash Is Empty", message: nil)
        } else {
            List {
                ForEach(items, id: \.url) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "doc")
                            .foregroundStyle(Color.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.originalURL.lastPathComponent)
                                .lineLimit(1)
                            Text(item.originalURL.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Button("Restore") {
                            model.perform { .restored([try trash.restore(item)], trash) }
                        }
                    }
                    .frame(minHeight: Metrics.minimumTarget - 8)
                    .contextMenu {
                        Button("Restore From Trash") {
                            model.perform { .restored([try trash.restore(item)], trash) }
                        }
                        Button("Delete Permanently", role: .destructive) {
                            model.attempt { try trash.delete(item) }
                        }
                    }
                }
            }
        }
    }
}

/// The items the user starred, wherever they are.
struct StarredView: View {

    @Binding var path: [Place]

    @EnvironmentObject private var model: FilesModel

    var body: some View {
        let _ = model.changes
        let items = model.starred.items()
        return Group {
            if items.isEmpty {
                EmptyState("No Starred Items", message: "Star an item from its menu to keep it here.")
            } else {
                List {
                    ForEach(items) { item in
                        Button {
                            if item.isFolder {
                                path.append(.folder(item.url))
                            } else if FileOpener.canOpen {
                                model.open(item.url)
                            }
                        } label: {
                            FileRow(item: item, location: item.url.deletingLastPathComponent().path)
                        }
                        .plainButton()
                        .contextMenu {
                            Button("Open Item Location") {
                                path.append(.folder(item.url.deletingLastPathComponent()))
                            }
                            Button("Unstar") { model.setStarred(false, for: item.url) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Starred")
    }
}

#endif
