//
//  ContactList.swift
//  CoreApps
//

/// A section of the list: the contacts whose names start with a letter.
public struct ContactSection: Identifiable, Equatable, Sendable {

    /// The letter, or `#` for names that start with no letter.
    public var letter: String

    public var contacts: [Contact]

    public var id: String { letter }
}

/// What an import changed.
public struct ImportResult: Equatable, Sendable {

    /// Contacts that weren't there before.
    public var added: Int

    /// Contacts already there, by id, which the import replaced.
    public var updated: Int
}

/// Sorting, sectioning and merging contacts.
public enum ContactList {

    /// The contacts in order of the name chosen, then of the other name.
    public static func sorted(_ contacts: [Contact], by order: NameOrder) -> [Contact] {
        contacts.sorted { lhs, rhs in
            let left = lhs.sortKey(order)
            let right = rhs.sortKey(order)
            // Names that start with no letter go last, as their section does.
            let leftLetter = left.first?.isLetter ?? false
            let rightLetter = right.first?.isLetter ?? false
            if leftLetter != rightLetter { return leftLetter }
            return left != right ? left < right : lhs.id < rhs.id
        }
    }

    /// The contacts in sections by letter, in order, with `#` last.
    public static func sections(_ contacts: [Contact], by order: NameOrder) -> [ContactSection] {
        var sections: [ContactSection] = []
        for contact in sorted(contacts, by: order) {
            let letter = contact.sectionLetter(order)
            if sections.last?.letter == letter {
                sections[sections.count - 1].contacts.append(contact)
            } else {
                sections.append(ContactSection(letter: letter, contacts: [contact]))
            }
        }
        return sections
    }

    /// The contacts with the imported ones in them: a contact with the same
    /// id as one there replaces it, and the rest are added.
    public static func merging(_ imported: [Contact], into contacts: [Contact]) -> (contacts: [Contact], result: ImportResult) {
        var merged = contacts
        var indices: [String: Int] = [:]
        for (index, contact) in merged.enumerated() {
            indices[contact.id] = index
        }
        var result = ImportResult(added: 0, updated: 0)
        for contact in imported {
            if let index = indices[contact.id] {
                merged[index] = contact
                result.updated += 1
            } else {
                indices[contact.id] = merged.count
                merged.append(contact)
                result.added += 1
            }
        }
        return (merged, result)
    }
}
