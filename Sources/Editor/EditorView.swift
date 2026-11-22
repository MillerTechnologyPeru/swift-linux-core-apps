//
//  EditorView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation
import TextCore

/// A document's text, with what's done to it in a menu. Leaving the
/// screen saves the document, as apps on a phone do.
struct EditorView: View {

    @ObservedObject var document: Document

    /// What a sheet is showing.
    enum Sheet: String, Identifiable {
        case find
        case saveAs
        case details

        var id: String { rawValue }
    }

    @State private var sheet: Sheet?

    @State private var isReverting = false

    @State private var wrapsLines = true

    @State private var fontSize = 15.0

    var body: some View {
        editor
            .navigationTitle((document.isModified ? "• " : "") + document.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        menu
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .find:
                    FindView(document: document) { self.sheet = nil }
                case .saveAs:
                    SaveAsView(name: document.name) { name in
                        self.sheet = nil
                        if let name { document.save(as: name) }
                    }
                case .details:
                    DetailsView(document: document) { self.sheet = nil }
                }
            }
            .confirmationDialog("Discard the changes to “\(document.name)”?", isPresented: $isReverting, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { document.revert() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The document goes back to how it was last saved.")
            }
            .alert("Couldn't Save", isPresented: failureIsShown) {
                Button("OK") { document.failure = nil }
            } message: {
                Text(document.failure ?? "")
            }
            .onDisappear {
                if document.isModified { document.save() }
            }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { document.failure != nil }, set: { if !$0 { document.failure = nil } })
    }

    @ViewBuilder
    private var editor: some View {
        if wrapsLines {
            TextEditor(text: $document.text)
                .font(.system(size: CGFloat(fontSize)).monospaced())
                .autocorrectionDisabled()
        } else {
            // Lines as long as they are, scrolled sideways.
            ScrollView(.horizontal) {
                TextEditor(text: $document.text)
                    .font(.system(size: CGFloat(fontSize)).monospaced())
                    .autocorrectionDisabled()
                    .frame(width: 2000)
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Button("Save") { document.save() }
            .disabled(!document.isModified)
        Button("Save As…") { sheet = .saveAs }
        Button("Discard Changes…", role: .destructive) { isReverting = true }
            .disabled(!document.isModified)
        Divider()
        Button("Undo") { document.undo() }
            .disabled(!document.history.canUndo)
        Button("Redo") { document.redo() }
            .disabled(!document.history.canRedo)
        Button("Find and Replace…") { sheet = .find }
        Divider()
        Toggle("Wrap Lines", isOn: $wrapsLines)
        Button("Larger Text") { fontSize = min(40, fontSize + 2) }
        Button("Smaller Text") { fontSize = max(9, fontSize - 2) }
        Divider()
        Button("Document Details") { sheet = .details }
    }
}

/// Finds text in a document and replaces it.
struct FindView: View {

    @ObservedObject var document: Document

    let done: () -> Void

    @State private var pattern = ""

    @State private var replacement = ""

    @State private var isCaseSensitive = false

    @State private var matchesWholeWords = false

    /// What the last replacing did, said under the fields.
    @State private var report: String?

    private var search: TextSearch {
        TextSearch(pattern, isCaseSensitive: isCaseSensitive, matchesWholeWords: matchesWholeWords)
    }

    var body: some View {
        let matches = search.matches(in: document.text, limit: 200)
        let total = matches.count < 200 ? matches.count : search.count(in: document.text)
        return NavigationStack {
            Form {
                Section {
                    TextField("Find", text: $pattern)
                        .autocorrectionDisabled()
                    TextField("Replace With", text: $replacement)
                        .autocorrectionDisabled()
                    Toggle("Match Case", isOn: $isCaseSensitive)
                    Toggle("Whole Words", isOn: $matchesWholeWords)
                } footer: {
                    Text(report ?? summary(total))
                }
                if !matches.isEmpty {
                    Section {
                        Button("Replace All \(total)") {
                            let count = document.replaceAll(search, with: replacement)
                            report = count == 1 ? "Replaced 1 match." : "Replaced \(count) matches."
                        }
                    }
                    Section(total > matches.count ? "First \(matches.count) Matches" : "Matches") {
                        ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                            Button {
                                document.replace(match, of: search, with: replacement)
                                report = nil
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.lineText.trimmingCharacters(in: .whitespaces))
                                        .font(.footnote.monospaced())
                                        .lineLimit(2)
                                        .foregroundStyle(Color.primary)
                                    Text("Line \(match.line), column \(match.column) · tap to replace")
                                        .font(.caption2)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                            .plainButton()
                        }
                    }
                }
            }
            .navigationTitle("Find and Replace")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }

    private func summary(_ total: Int) -> String {
        if pattern.isEmpty { return "" }
        return total == 0 ? "No matches." : (total == 1 ? "1 match." : "\(total) matches.")
    }
}

/// Asks for the name to save a document under.
struct SaveAsView: View {

    /// Called with the name, or `nil` if the user thought better of it.
    let done: (String?) -> Void

    @State private var name: String

    init(name: String, done: @escaping (String?) -> Void) {
        self.done = done
        _name = State(initialValue: name)
    }

    private var cleaned: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let problem = DocumentName.problem(with: cleaned)
        return NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                } footer: {
                    Text(cleaned.isEmpty ? "" : (problem ?? "Saved in the folder the document is in."))
                }
            }
            .navigationTitle("Save As")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { done(cleaned) }
                        .disabled(problem != nil)
                }
            }
        }
    }
}

/// What a document amounts to, and how it's kept on disk.
struct DetailsView: View {

    @ObservedObject var document: Document

    let done: () -> Void

    var body: some View {
        let statistics = TextStatistics(document.text)
        return NavigationStack {
            Form {
                Section {
                    row("Lines", "\(statistics.lines)")
                    row("Words", "\(statistics.words)")
                    row("Characters", "\(statistics.characters)")
                    row("Without Spaces", "\(statistics.charactersWithoutSpaces)")
                    row("Size", ByteCount.format(Int64(statistics.bytes)))
                }
                Section {
                    row("Encoding", document.file.encoding.name)
                    Picker("Line Endings", selection: Binding(
                        get: { document.file.lineEnding },
                        set: { document.setLineEnding($0) }
                    )) {
                        ForEach(LineEnding.allCases, id: \.self) { ending in
                            Text(ending.name).tag(ending)
                        }
                    }
                } footer: {
                    Text("Line endings change when the document is next saved.")
                }
                Section("Where") {
                    Text(document.url.deletingLastPathComponent().path)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .navigationTitle("Document Details")
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
