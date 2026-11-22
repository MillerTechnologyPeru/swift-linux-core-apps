//
//  Contact.swift
//  CoreApps
//

/// A person or a company, and the ways to reach them.
public struct Contact: Identifiable, Hashable, Codable, Sendable {

    /// The vCard's UID, kept across imports and exports.
    public var id: String

    public var namePrefix: String = ""

    public var givenName: String = ""

    public var middleName: String = ""

    public var familyName: String = ""

    public var nameSuffix: String = ""

    public var nickname: String = ""

    public var organization: String = ""

    public var department: String = ""

    public var jobTitle: String = ""

    public var phones: [LabeledValue] = []

    public var emails: [LabeledValue] = []

    public var urls: [LabeledValue] = []

    public var addresses: [PostalAddress] = []

    public var birthday: Birthday?

    public var note: String = ""

    public var isFavorite = false

    /// Lines of the vCard this app doesn't read, such as a photo, kept so
    /// that writing the card back loses nothing.
    public var otherLines: [String] = []

    public init(id: String = Identifier.make()) {
        self.id = id
    }

    /// The name as it's written: given name first, with the prefix and
    /// suffix. Falls back to the nickname, the organization, then an email
    /// or phone number.
    public var displayName: String {
        name ?? "No Name"
    }

    /// The name, or what stands for it; nil when there's nothing.
    private var name: String? {
        let name = [namePrefix, givenName, middleName, familyName, nameSuffix]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { return name }
        for fallback in [nickname, organization, emails.first?.value ?? "", phones.first?.value ?? ""] where !fallback.isEmpty {
            return fallback
        }
        return nil
    }

    /// Whether the contact names a company rather than a person.
    public var isCompany: Bool {
        givenName.isEmpty && familyName.isEmpty && middleName.isEmpty && !organization.isEmpty
    }

    /// The contact's job and company: `Engineer, Acme`.
    public var jobSummary: String {
        if isCompany { return jobTitle }
        return [jobTitle, organization].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Up to two letters for an avatar: the given and family names'
    /// initials, or the first of whatever names the contact.
    public var initials: String {
        let letters = [givenName, familyName].compactMap(\.first)
        if !letters.isEmpty {
            return String(letters).uppercased()
        }
        guard let first = name?.first, first.isLetter else { return "" }
        return String(first).uppercased()
    }

    /// The name the contact sorts by, in the order given.
    public func sortKey(_ order: NameOrder) -> String {
        let first = order == .givenName ? givenName : familyName
        let second = order == .givenName ? familyName : givenName
        let key = [first, second].filter { !$0.isEmpty }.joined(separator: " ")
        return (key.isEmpty ? name ?? "" : key).lowercased().withoutAccents
    }

    /// The letter of the list's section the contact is in, or `#` for a
    /// name that starts with no letter.
    public func sectionLetter(_ order: NameOrder) -> String {
        guard let first = sortKey(order).first, first.isLetter else { return "#" }
        return String(first).uppercased()
    }

    /// A color for the contact's avatar, from 0 to `count - 1`, the same
    /// each time.
    public func colorIndex(of count: Int) -> Int {
        var hash: UInt32 = 5381
        for byte in id.utf8 {
            hash = (hash &<< 5) &+ hash &+ UInt32(byte)
        }
        return Int(hash % UInt32(max(1, count)))
    }

    /// Whether the contact matches a search: by name, organization, email
    /// or note, ignoring case and accents, and by phone number, ignoring all but its
    /// digits.
    public func matches(_ query: String) -> Bool {
        let words = query.lowercased().withoutAccents.split(whereSeparator: { $0 == " " })
        guard !words.isEmpty else { return true }
        let text = ([displayName, nickname, organization, department, jobTitle, note] + emails.map(\.value))
            .joined(separator: " ")
            .lowercased()
            .withoutAccents
        let digits = phones.map { Self.digits($0.value) }
        return words.allSatisfy { word in
            if text.contains(word) { return true }
            let wordDigits = Self.digits(String(word))
            return wordDigits.count >= 3 && wordDigits.count == word.filter({ !"+-() .".contains($0) }).count
                && digits.contains { $0.contains(wordDigits) }
        }
    }

    /// Whether there's nothing in the contact worth keeping.
    public var isEmpty: Bool {
        [namePrefix, givenName, middleName, familyName, nameSuffix, nickname, organization, department, jobTitle, note]
            .allSatisfy { $0.trimmed.isEmpty }
            && phones.allSatisfy { $0.value.trimmed.isEmpty }
            && emails.allSatisfy { $0.value.trimmed.isEmpty }
            && urls.allSatisfy { $0.value.trimmed.isEmpty }
            && addresses.allSatisfy(\.isEmpty)
            && birthday == nil
    }

    /// The contact without blank phones, emails, links and addresses, and
    /// with its text trimmed.
    public var tidied: Contact {
        var contact = self
        for path in [\Contact.namePrefix, \.givenName, \.middleName, \.familyName, \.nameSuffix, \.nickname, \.organization, \.department, \.jobTitle] {
            contact[keyPath: path] = contact[keyPath: path].trimmed
        }
        contact.phones = phones.map { $0.trimmed }.filter { !$0.value.isEmpty }
        contact.emails = emails.map { $0.trimmed }.filter { !$0.value.isEmpty }
        contact.urls = urls.map { $0.trimmed }.filter { !$0.value.isEmpty }
        contact.addresses = addresses.filter { !$0.isEmpty }
        return contact
    }

    static func digits(_ text: String) -> String {
        String(text.filter(\.isNumber))
    }
}

/// Which name contacts sort by.
public enum NameOrder: String, Codable, CaseIterable, Sendable {
    case givenName
    case familyName

    public var title: String {
        switch self {
        case .givenName: "First Name"
        case .familyName: "Last Name"
        }
    }
}

/// A phone number, email or link, and what it's for: `mobile`, `work`.
public struct LabeledValue: Identifiable, Hashable, Codable, Sendable {

    public var id: String

    public var label: String

    public var value: String

    public init(id: String = Identifier.make(), label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }

    var trimmed: LabeledValue {
        LabeledValue(id: id, label: label, value: value.trimmed)
    }

    /// The labels offered for phone numbers.
    public static let phoneLabels = ["mobile", "home", "work", "main", "home fax", "work fax", "pager", "other"]

    /// The labels offered for emails.
    public static let emailLabels = ["home", "work", "other"]

    /// The labels offered for links.
    public static let urlLabels = ["homepage", "home", "work", "other"]
}

/// A postal address.
public struct PostalAddress: Identifiable, Hashable, Codable, Sendable {

    public var id: String

    public var label: String

    public var street: String = ""

    public var city: String = ""

    public var region: String = ""

    public var postalCode: String = ""

    public var country: String = ""

    public init(
        id: String = Identifier.make(), label: String = "home", street: String = "", city: String = "",
        region: String = "", postalCode: String = "", country: String = ""
    ) {
        self.id = id
        self.label = label
        self.street = street
        self.city = city
        self.region = region
        self.postalCode = postalCode
        self.country = country
    }

    public var isEmpty: Bool {
        [street, city, region, postalCode, country].allSatisfy { $0.trimmed.isEmpty }
    }

    /// The address on lines, as on an envelope: the street, then the city,
    /// region and postal code, then the country.
    public var lines: [String] {
        let town = [city, [region, postalCode].filter { !$0.isEmpty }.joined(separator: " ")]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return (street.split(separator: "\n").map(String.init) + [town, country]).filter { !$0.isEmpty }
    }

    /// The address on one line, for a map search.
    public var singleLine: String {
        lines.joined(separator: ", ")
    }

    /// The labels offered for addresses.
    public static let labels = ["home", "work", "other"]
}

/// A birthday, with or without the year.
public struct Birthday: Hashable, Codable, Sendable {

    public var year: Int?

    public var month: Int

    public var day: Int

    public init(year: Int? = nil, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    /// `March 4, 1990`, or `March 4`.
    public var text: String {
        let name = (1...12).contains(month) ? Self.months[month - 1] : "Month \(month)"
        if let year { return "\(name) \(day), \(year)" }
        return "\(name) \(day)"
    }
}

/// Makes the ids of new contacts: random, in the form of a UUID.
public enum Identifier {

    public static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        var bytes = (0..<16).map { _ in UInt8.random(in: 0...255, using: &generator) }
        bytes[6] = bytes[6] & 0x0F | 0x40
        bytes[8] = bytes[8] & 0x3F | 0x80
        let hex = Array("0123456789ABCDEF")
        var text = ""
        for (index, byte) in bytes.enumerated() {
            if [4, 6, 8, 10].contains(index) { text.append("-") }
            text.append(hex[Int(byte >> 4)])
            text.append(hex[Int(byte & 0xF)])
        }
        return text
    }
}

extension String {

    /// The string with accented Latin letters as their base letters,
    /// `é` as `e`, so that names sort and section as a phone's contacts do.
    var withoutAccents: String {
        // The base letters of U+00C0 to U+017F; `-` for those with none.
        let table = Array("AAAAAAACEEEEIIIIDNOOOOO-OUUUUY-saaaaaaaceeeeiiiidnooooo-ouuuuy-yAaAaAaCcCcCcCcDdDdEeEeEeEeEeGgGgGgGgHhHhIiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnnNnOoOoOoOoRrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZzs")
        var result = String.UnicodeScalarView()
        for scalar in unicodeScalars {
            let value = Int(scalar.value)
            if (0xC0...0x17F).contains(value), table[value - 0xC0] != "-",
               let base = table[value - 0xC0].unicodeScalars.first {
                result.append(base)
            } else if (0x300...0x36F).contains(value) {
                // A combining accent, after its letter.
                continue
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }

    /// The string without spaces and newlines at either end.
    var trimmed: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
