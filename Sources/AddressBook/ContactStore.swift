//
//  ContactStore.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ContactsCore
import Foundation
#if Apple
import UniformTypeIdentifiers
#endif

/// What the contacts keep besides the cards.
private struct Settings: Codable {
    var nameOrder: NameOrder
}

/// The contacts, kept as one vCard file that any contacts app can read.
@MainActor
final class ContactStore: ObservableObject {

    @Published private(set) var contacts: [Contact] = []

    @Published var nameOrder: NameOrder { didSet { saveSettings() } }

    /// Why the cards couldn't be read or written.
    @Published var failure: String?

    /// The vCard file: `contacts.vcf` in the data folder.
    let file: URL

    private let settingsFile: URL

    init() {
        let folder = Self.folder()
        file = folder.appendingPathComponent("contacts.vcf")
        settingsFile = folder.appendingPathComponent("settings.json")
        let settings = (try? Data(contentsOf: settingsFile)).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
        nameOrder = settings?.nameOrder ?? .givenName
        load()
    }

    /// The data folder: XDG's on Linux, Application Support on Apple's
    /// systems.
    private static func folder() -> URL {
        #if canImport(Darwin)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        var base = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
        if let path = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], path.hasPrefix("/") {
            base = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        return base.appendingPathComponent("contacts", isDirectory: true)
    }

    // MARK: Keeping

    private func load() {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let data = try Data(contentsOf: file)
            contacts = VCard.parse(Self.text(data))
        } catch {
            failure = "The contacts couldn't be read: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(VCard.write(contacts).utf8).write(to: file, options: .atomic)
        } catch {
            failure = "The contacts couldn't be saved: \(error.localizedDescription)"
        }
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(Settings(nameOrder: nameOrder)) else { return }
        try? FileManager.default.createDirectory(at: settingsFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: settingsFile, options: .atomic)
    }

    /// A file's text, as UTF-8, or Latin-1 when it isn't.
    nonisolated static func text(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }

    // MARK: Contacts

    func contact(id: String) -> Contact? {
        contacts.first { $0.id == id }
    }

    var favorites: [Contact] {
        ContactList.sorted(contacts.filter(\.isFavorite), by: nameOrder)
    }

    /// Adds a contact, or replaces the one with its id.
    func save(_ contact: Contact) {
        let tidied = contact.tidied
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index] = tidied
        } else {
            contacts.append(tidied)
        }
        save()
    }

    func delete(_ contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        save()
    }

    func toggleFavorite(_ contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index].isFavorite.toggle()
        save()
    }

    // MARK: Importing and exporting

    /// Imports the cards in a vCard file, and says what changed.
    func importCards(from url: URL) -> String {
        #if canImport(Darwin)
        // A file picked on iOS is outside the app's sandbox until asked for.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        #endif
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return "“\(url.lastPathComponent)” couldn't be read: \(error.localizedDescription)"
        }
        let imported = VCard.parse(Self.text(data))
        guard !imported.isEmpty else {
            return "“\(url.lastPathComponent)” has no contacts in it."
        }
        let (merged, result) = ContactList.merging(imported, into: contacts)
        contacts = merged
        save()
        var parts: [String] = []
        if result.added > 0 { parts.append(result.added == 1 ? "Added 1 contact" : "Added \(result.added) contacts") }
        if result.updated > 0 { parts.append(result.updated == 1 ? "updated 1 already here" : "updated \(result.updated) already here") }
        let sentence = parts.joined(separator: " and ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }
}

/// Contacts as a vCard file, for exporting.
struct VCardDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.vCardFile] }

    var contacts: [Contact]

    init(contacts: [Contact]) {
        self.contacts = contacts
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        contacts = VCard.parse(ContactStore.text(data))
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(VCard.write(contacts).utf8))
    }
}

extension UTType {

    /// vCard files, `.vcf`.
    static var vCardFile: UTType {
        #if Apple
        .vCard
        #else
        UTType(exportedAs: "public.vcard")
        #endif
    }

    /// Tells Cacao's file dialogs what vCard files are called.
    static func declareVCard() {
        // Only Cacao's own UTType, on Linux, is told: on a Mac, Cacao's is
        // Apple's, which knows the extension already.
        #if Native && !canImport(UniformTypeIdentifiers)
        UTType.declareFilenameExtension("vcf", for: .vCardFile)
        #endif
    }
}

#endif
