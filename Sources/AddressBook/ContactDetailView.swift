//
//  ContactDetailView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ContactsCore
import CoreAppsUI
import Foundation

/// A contact: who they are, and the ways to reach them, each a tap away.
struct ContactDetailView: View {

    @EnvironmentObject private var store: ContactStore

    @Environment(\.openURL) private var openURL

    @Environment(\.dismiss) private var dismiss

    let id: String

    @State private var isEditing = false

    @State private var isConfirmingDelete = false

    @State private var isExporting = false

    var body: some View {
        if let contact = store.contact(id: id) {
            details(contact)
        } else {
            EmptyState("No Contact", message: "The contact was deleted.")
        }
    }

    private func details(_ contact: Contact) -> some View {
        List {
            Section {
                header(contact)
            }
            if !contact.phones.isEmpty {
                Section {
                    ForEach(contact.phones) { phone in
                        field(phone.label, phone.value, url: Self.url("tel:", phone.value.filter { !" ()-.".contains($0) }))
                    }
                }
            }
            if !contact.emails.isEmpty {
                Section {
                    ForEach(contact.emails) { email in
                        field(email.label, email.value, url: Self.url("mailto:", email.value))
                    }
                }
            }
            if !contact.urls.isEmpty {
                Section {
                    ForEach(contact.urls) { link in
                        field(link.label, link.value, url: Self.webURL(link.value))
                    }
                }
            }
            if !contact.addresses.isEmpty {
                Section {
                    ForEach(contact.addresses) { address in
                        field(address.label, address.lines.joined(separator: "\n"), url: Self.mapURL(address))
                    }
                }
            }
            if let birthday = contact.birthday {
                Section {
                    field("birthday", birthday.text, url: nil)
                }
            }
            if !contact.note.isEmpty {
                Section {
                    field("notes", contact.note, url: nil)
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(contact.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                        store.toggleFavorite(contact)
                    }
                    Button("Export vCard…") { isExporting = true }
                    Button("Delete Contact", role: .destructive) { isConfirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            ContactEditor(contact: contact, isNew: false) { saved in
                isEditing = false
                if let saved { store.save(saved) }
            }
            .environmentObject(store)
        }
        .confirmationDialog("Delete \(contact.displayName)?", isPresented: $isConfirmingDelete) {
            Button("Delete Contact", role: .destructive) {
                store.delete(contact)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The contact is removed from this device.")
        }
        .fileExporter(
            isPresented: $isExporting,
            document: VCardDocument(contacts: [contact]),
            contentType: .vCardFile,
            defaultFilename: "\(contact.displayName).vcf"
        ) { result in
            if case let .failure(error) = result { store.failure = error.localizedDescription }
        }
    }

    private func header(_ contact: Contact) -> some View {
        VStack(spacing: 8) {
            Avatar(contact: contact, size: 88)
            HStack(spacing: 6) {
                Text(contact.displayName)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                if contact.isFavorite {
                    Image(systemName: "star")
                        .foregroundStyle(Color.yellow)
                }
            }
            if !contact.nickname.isEmpty, !contact.isCompany {
                Text("“\(contact.nickname)”")
                    .foregroundStyle(Color.secondary)
            }
            if !contact.jobSummary.isEmpty {
                Text(contact.jobSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                action("Call", symbol: Symbols.call, url: contact.phones.first.flatMap { Self.url("tel:", $0.value.filter { !" ()-.".contains($0) }) })
                action("Message", symbol: Symbols.message, url: contact.phones.first.flatMap { Self.url("sms:", $0.value.filter { !" ()-.".contains($0) }) })
                action("Email", symbol: Symbols.email, url: contact.emails.first.flatMap { Self.url("mailto:", $0.value) })
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    /// A button for the first number or email, dimmed when there's none.
    private func action(_ title: String, symbol: String, url: URL?) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.12)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .disabled(url == nil)
        .opacity(url == nil ? 0.4 : 1)
    }

    /// A field: what it is, small, above its value, which a tap opens
    /// when it's a number, an address or a link.
    @ViewBuilder
    private func field(_ label: String, _ value: String, url: URL?) -> some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                fieldText(label, value, color: Color.accentColor)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            fieldText(label, value, color: Color.primary)
        }
    }

    private func fieldText(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Text(value)
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Addresses

    static func url(_ scheme: String, _ value: String) -> URL? {
        guard !value.isEmpty,
              let escaped = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        return URL(string: scheme + escaped)
    }

    /// A link as written, with `https://` before it if it has no scheme.
    static func webURL(_ value: String) -> URL? {
        let text = value.contains("://") ? value : "https://" + value
        return URL(string: text)
    }

    /// The address in the system's maps: Apple Maps on Apple's systems,
    /// and OpenStreetMap in the browser on Linux.
    static func mapURL(_ address: PostalAddress) -> URL? {
        guard let query = address.singleLine.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        #if Apple
        return URL(string: "https://maps.apple.com/?q=" + query)
        #else
        return URL(string: "https://www.openstreetmap.org/search?query=" + query)
        #endif
    }
}

/// The symbols the contacts use: SF Symbols on Apple's SwiftUI, and the
/// nearest Cacao has.
enum Symbols {
    #if Apple
    static let call = "phone.fill"
    static let message = "message.fill"
    static let email = "envelope.fill"
    static let remove = "minus.circle.fill"
    #else
    static let call = "bell"
    static let message = "paperplane"
    static let email = "envelope"
    static let remove = "minus"
    #endif
}

#endif
