//
//  PropertiesView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// What's known of a file or folder, and who may do what with it.
struct PropertiesView: View {

    let url: URL

    let done: () -> Void

    @EnvironmentObject private var model: FilesModel

    var body: some View {
        // Reading the count shows a change to the permissions.
        let _ = model.changes
        return NavigationStack {
            switch Result(catching: { try FileProperties.load(url) }) {
            case let .success(properties):
                form(properties)
            case let .failure(error):
                EmptyState("No Properties", message: error.localizedDescription)
            }
        }
    }

    private func form(_ properties: FileProperties) -> some View {
        Form {
            Section {
                row("Name", properties.name)
                row("Type", properties.linkTarget == nil ? properties.kind.rawValue.capitalized : "Link")
                if let target = properties.linkTarget {
                    row("Link Target", target)
                }
                if let size = properties.size {
                    row("Size", "\(ByteCount.format(size)) (\(size) bytes)")
                }
                if properties.isFolder {
                    if let count = properties.itemCount {
                        row("Contents", count == 1 ? "1 item" : "\(count) items")
                    }
                    let contents = FileProperties.contents(of: url, limit: 20_000)
                    row("Size of Contents", (contents.isComplete ? "" : "More than ") + ByteCount.format(contents.bytes))
                    if let free = properties.freeSpace {
                        row("Free Space", ByteCount.format(free))
                    }
                }
                row("Parent Folder", properties.parent)
            }
            Section {
                if let date = properties.modified { row("Modified", format(date)) }
                if let date = properties.created { row("Created", format(date)) }
                if let date = properties.accessed { row("Accessed", format(date)) }
            }
            Section {
                Toggle("Starred", isOn: Binding(
                    get: { model.starred.contains(url) },
                    set: { model.setStarred($0, for: url) }
                ))
            }
            if let permissions = properties.permissions {
                Section("Permissions") {
                    if let owner = properties.owner { row("Owner", owner) }
                    if let group = properties.group { row("Group", group) }
                    ForEach(Permissions.Who.allCases, id: \.self) { who in
                        Menu {
                            access(for: who, in: permissions, isFolder: properties.isFolder)
                        } label: {
                            HStack {
                                Text(who.name + " Access")
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text(permissions.summary(for: who, isFolder: properties.isFolder))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    if !properties.isFolder {
                        Toggle("Executable as Program", isOn: Binding(
                            get: { permissions.isExecutable },
                            set: { isOn in
                                var changed = permissions
                                changed.isExecutable = isOn
                                model.setPermissions(changed, of: url)
                            }
                        ))
                    }
                    row("As Letters", permissions.symbolic)
                    if properties.isFolder {
                        Button("Apply to Enclosed Files") {
                            model.setPermissions(permissions, of: url, recursively: true)
                        }
                    }
                }
            }
        }
        .navigationTitle("Properties")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: done)
            }
        }
    }

    /// The levels of access one group of people can be given.
    @ViewBuilder
    private func access(for who: Permissions.Who, in permissions: Permissions, isFolder: Bool) -> some View {
        // Read, write, and for a folder enter.
        let levels: [(String, Bool, Bool, Bool)] = isFolder
            ? [("None", false, false, false), ("List files only", true, false, false), ("Access files", true, false, true), ("Create and delete files", true, true, true)]
            : [("None", false, false, false), ("Read-only", true, false, false), ("Read and write", true, true, false)]
        ForEach(levels, id: \.0) { level in
            Button(level.0) {
                var changed = permissions
                changed.set(.read, for: who, to: level.1)
                changed.set(.write, for: who, to: level.2)
                if isFolder { changed.set(.execute, for: who, to: level.3) }
                model.setPermissions(changed, of: url)
            }
        }
    }

    private func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
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
