//
//  ContactsApp.swift
//  CoreApps
//

// The contacts keep their cards in a file of their own and use the
// system's file dialogs, which a guest has no contract for yet: a program
// for now, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import ContactsCore
import CoreAppsUI
import Foundation
#if Apple
import UniformTypeIdentifiers
#endif

/// The contacts.
public struct ContactsApp: App {

    /// A vCard file to import at launch: `contacts cards.vcf`.
    private let importing: URL?

    public init() {
        UTType.declareVCard()
        // Only Cacao's program reads its arguments: Apple's systems pass
        // their own to an app.
        #if Native
        importing = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
        #else
        importing = nil
        #endif
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Contacts") {
            ContactsView(importing: importing)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            ContactsView(importing: importing)
        }
        #endif
    }
}

/// The contacts' list, by letter, with the favorites first.
public struct ContactsView: View {

    @StateObject private var store = ContactStore()

    @State private var path: [String] = []

    @State private var query = ""

    @State private var isCreating = false

    @State private var isImporting = false

    @State private var isExporting = false

    @State private var message: String?

    private let importing: URL?

    public init(importing: URL? = nil) {
        self.importing = importing
    }

    public var body: some View {
        NavigationStack(path: $path) {
            list
                .navigationTitle("Contacts")
                .searchable(text: $query, prompt: Text("Search"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isCreating = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Import vCard…") { isImporting = true }
                            Button("Export All…") { isExporting = true }
                                .disabled(store.contacts.isEmpty)
                            Picker("Sort By", selection: $store.nameOrder) {
                                ForEach(NameOrder.allCases, id: \.self) { order in
                                    Text(order.title).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
                .navigationDestination(for: String.self) { id in
                    ContactDetailView(id: id)
                }
        }
        .environmentObject(store)
        .sheet(isPresented: $isCreating) {
            ContactEditor(contact: Contact(), isNew: true) { saved in
                isCreating = false
                if let saved {
                    store.save(saved)
                    path.append(saved.id)
                }
            }
            .environmentObject(store)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.vCardFile]) { result in
            switch result {
            case let .success(url): message = store.importCards(from: url)
            case let .failure(error): message = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $isExporting, document: VCardDocument(contacts: store.contacts), contentType: .vCardFile, defaultFilename: "Contacts.vcf") { result in
            switch result {
            case let .success(url): message = "Exported \(store.contacts.count) contacts to “\(url.lastPathComponent)”."
            case let .failure(error): message = error.localizedDescription
            }
        }
        .alert("Contacts", isPresented: messageIsShown) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
        .alert("Can't Keep Contacts", isPresented: failureIsShown) {
            Button("OK") { store.failure = nil }
        } message: {
            Text(store.failure ?? "")
        }
        .task {
            if let importing {
                message = await store.importCards(from: importing)
            }
        }
    }

    private var messageIsShown: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var list: some View {
        let matching = store.contacts.filter { $0.matches(trimmedQuery) }
        if store.contacts.isEmpty {
            VStack(spacing: 12) {
                EmptyState("No Contacts", message: "Add a contact, or import a vCard file from another phone or app.")
                    .frame(maxHeight: 160)
                Button("Import vCard…") { isImporting = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if matching.isEmpty {
            EmptyState("No Results", message: "No contact matches “\(trimmedQuery)”.")
        } else {
            List {
                if trimmedQuery.isEmpty, !store.favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(store.favorites) { contact in
                            row(contact)
                        }
                    }
                }
                ForEach(ContactList.sections(matching, by: store.nameOrder)) { section in
                    Section(section.letter) {
                        ForEach(section.contacts) { contact in
                            row(contact)
                        }
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text(matching.count == 1 ? "1 Contact" : "\(matching.count) Contacts")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func row(_ contact: Contact) -> some View {
        Button {
            path.append(contact.id)
        } label: {
            HStack(spacing: 12) {
                Avatar(contact: contact, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.displayName)
                        .lineLimit(1)
                    if contact.isCompany == false, !contact.organization.isEmpty {
                        Text(contact.organization)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(contact.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(contact)
            }
            Button("Delete", role: .destructive) { store.delete(contact) }
        }
    }
}

#endif
