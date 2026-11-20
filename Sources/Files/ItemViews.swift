//
//  ItemViews.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation

/// The circle beside an item while selecting: filled when it's picked.
struct SelectionMark: View {

    let isPicked: Bool

    var body: some View {
        Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isPicked ? Color.accentColor : Color.secondary)
            .frame(width: 24)
    }
}

/// A row for a file or folder: its symbol, its name, and for a file its
/// size and when it changed.
struct FileRow: View {

    let item: FileItem

    /// The folder the item is in, shown for an item a search found.
    var location: String?

    /// Whether the item is picked, while selecting.
    var mark: Bool?

    /// Whether the item was cut, and waits to be pasted elsewhere.
    var isCut = false

    var body: some View {
        HStack(spacing: 12) {
            if let mark {
                SelectionMark(isPicked: mark)
            }
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
            if item.isFolder, mark == nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(minHeight: Metrics.minimumTarget - 8)
        .opacity(item.isHidden || isCut ? 0.5 : 1)
    }

    private var detail: String? {
        if let location { return location }
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

/// A file or folder in a grid: a large symbol over its name.
struct FileTile: View {

    let item: FileItem

    var mark: Bool?

    var isCut = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 40))
                .foregroundStyle(item.isFolder ? Color.accentColor : Color.secondary)
                .frame(height: 52)
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let mark {
                SelectionMark(isPicked: mark)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
        .opacity(item.isHidden || isCut ? 0.5 : 1)
    }
}

/// Asks for a name: an item's new one, a new folder's, or other text.
struct NameView: View {

    let title: String

    let confirm: String

    /// Whether any text will do, rather than only what a file can be named.
    let allowsAnyText: Bool

    /// Words under the field.
    let footer: String?

    /// Called with the text, or `nil` if the user thought better of it.
    let done: (String?) -> Void

    @State private var name: String

    init(title: String, name: String, confirm: String, allowsAnyText: Bool = false, footer: String? = nil, done: @escaping (String?) -> Void) {
        self.title = title
        self.confirm = confirm
        self.allowsAnyText = allowsAnyText
        self.footer = footer
        self.done = done
        self._name = State(initialValue: name)
    }

    /// Why the name can't be used yet.
    private var problem: FileName.Problem? {
        allowsAnyText ? nil : FileName.problem(with: FileName.cleaned(name))
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
                    } else if let footer {
                        Text(footer)
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

/// Asks how several items are to be renamed, showing what they'd become.
struct BatchRenameView: View {

    let items: [URL]

    /// Called with the rule, or `nil` if the user thought better of it.
    let done: (BatchRename?) -> Void

    @State private var usesTemplate = true

    @State private var template = "[Original] [1]"

    @State private var existing = ""

    @State private var replacement = ""

    private var rule: BatchRename {
        usesTemplate ? .template(template) : .replace(existing, with: replacement)
    }

    var body: some View {
        let names = items.map(\.lastPathComponent)
        let renamed = rule.names(for: names)
        let others = Set((try? FileManager.default.contentsOfDirectory(atPath: items[0].deletingLastPathComponent().path)) ?? []).subtracting(names)
        let problem = rule.problem(for: names, among: others)
        return NavigationStack {
            Form {
                Section {
                    Picker("Rename", selection: $usesTemplate) {
                        Text("Using a Template").tag(true)
                        Text("Find and Replace").tag(false)
                    }
                    if usesTemplate {
                        TextField("Template", text: $template)
                    } else {
                        TextField("Existing Text", text: $existing)
                        TextField("Replace With", text: $replacement)
                    }
                } footer: {
                    if let problem {
                        Text(problem)
                    } else if usesTemplate {
                        Text("[Original] is the item's name; [1], [01] and [001] number the items.")
                    }
                }
                Section("Preview") {
                    ForEach(Array(zip(names, renamed).prefix(50).enumerated()), id: \.offset) { _, pair in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.1)
                                .lineLimit(1)
                            Text(pair.0)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Rename \(items.count) Items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Rename") { done(rule) }
                        .disabled(problem != nil || renamed == names)
                }
            }
        }
    }
}

#endif
