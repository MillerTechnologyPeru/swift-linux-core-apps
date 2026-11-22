//
//  VCard.swift
//  CoreApps
//

/// Reads and writes contacts as vCards (RFC 2426 and 6350), the format
/// every contacts app exports.
///
/// It reads versions 2.1, 3.0 and 4.0, with 2.1's quoted-printable text
/// (as Android writes it) and the labels Apple's Contacts gives in
/// `X-ABLabel`. It writes 3.0. Lines it doesn't read, such as photos, are
/// kept and written back as they were.
public enum VCard {

    // MARK: Reading

    /// The contacts in vCard text. Cards without a name or any way to
    /// reach someone are left out.
    public static func parse(_ text: String) -> [Contact] {
        var contacts: [Contact] = []
        var card: [Property]?
        for line in unfold(text) {
            guard let property = Property(line: line) else { continue }
            switch property.name {
            case "BEGIN" where property.value.uppercased() == "VCARD":
                card = []
            case "END" where property.value.uppercased() == "VCARD":
                if let properties = card {
                    let contact = makeContact(properties)
                    if !contact.isEmpty { contacts.append(contact) }
                }
                card = nil
            default:
                card?.append(property)
            }
        }
        return contacts
    }

    /// The text's lines, with folded lines joined, and with
    /// quoted-printable soft line breaks joined too.
    static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        let physical = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })
        for piece in physical {
            let line = String(piece)
            if let last = lines.last {
                if let first = line.first, first == " " || first == "\t" {
                    lines[lines.count - 1] = last + line.dropFirst()
                    continue
                }
                if last.hasSuffix("="), isQuotedPrintable(last) {
                    lines[lines.count - 1] = String(last.dropLast()) + line
                    continue
                }
            }
            if line.isEmpty { continue }
            lines.append(line)
        }
        return lines
    }

    private static func isQuotedPrintable(_ line: String) -> Bool {
        guard let colon = line.firstIndex(of: ":") else { return false }
        return line[..<colon].uppercased().contains("QUOTED-PRINTABLE")
    }

    /// One line of a card: `item1.TEL;TYPE=CELL:+1 555 0100`.
    struct Property {
        var group: String?
        /// In capitals.
        var name: String
        /// Parameter names in capitals, with their values.
        var parameters: [(name: String, values: [String])]
        /// As written, still escaped.
        var value: String
        /// The whole line, unfolded.
        var line: String

        init?(line: String) {
            guard let colon = Self.unquotedIndex(of: ":", in: line) else { return nil }
            self.line = line
            value = String(line[line.index(after: colon)...])
            let head = Self.splitUnquoted(String(line[..<colon]), on: ";")
            guard let fullName = head.first, !fullName.isEmpty else { return nil }
            if let dot = fullName.lastIndex(of: ".") {
                group = String(fullName[..<dot])
                name = String(fullName[fullName.index(after: dot)...]).uppercased()
            } else {
                group = nil
                name = fullName.uppercased()
            }
            parameters = head.dropFirst().map { parameter in
                if let equals = parameter.firstIndex(of: "=") {
                    let values = Self.splitUnquoted(String(parameter[parameter.index(after: equals)...]), on: ",")
                        .map { $0.replacingAll("\"", with: "") }
                    return (String(parameter[..<equals]).uppercased(), values)
                }
                // vCard 2.1 gives types bare: `TEL;CELL;VOICE:`.
                return ("TYPE", [parameter])
            }
            // vCard 2.1's quoted-printable values have no backslash
            // escapes, and keep their `;` between parts.
            if parameter("ENCODING").contains(where: { $0.uppercased() == "QUOTED-PRINTABLE" }) {
                value = VCard.decodeQuotedPrintable(value)
            }
        }

        /// A parameter's values, all of them where it's given more than once.
        func parameter(_ name: String) -> [String] {
            parameters.filter { $0.name == name }.flatMap(\.values)
        }

        /// The `TYPE` values, in lower case, less those that say nothing of
        /// what a number or address is for.
        var types: Set<String> {
            Set(parameter("TYPE").flatMap { $0.split(separator: ",") }.map { $0.lowercased() })
                .subtracting(["pref", "voice", "internet", "x400", "dom", "intl", "postal", "parcel"])
        }

        /// The value unescaped, as text.
        var text: String { VCard.unescape(value) }

        /// The value split at `;` into unescaped parts.
        var components: [String] {
            VCard.splitEscaped(value, on: ";").map(VCard.unescape)
        }

        static func unquotedIndex(of character: Character, in text: String) -> String.Index? {
            var quoted = false
            for index in text.indices {
                if text[index] == "\"" { quoted.toggle() }
                if text[index] == character, !quoted { return index }
            }
            return nil
        }

        static func splitUnquoted(_ text: String, on separator: Character) -> [String] {
            var parts: [String] = []
            var current = ""
            var quoted = false
            for character in text {
                if character == "\"" { quoted.toggle() }
                if character == separator, !quoted {
                    parts.append(current)
                    current = ""
                } else {
                    current.append(character)
                }
            }
            parts.append(current)
            return parts
        }
    }

    private static func makeContact(_ properties: [Property]) -> Contact {
        // Apple's labels: `item1.X-ABLabel:_$!<Mobile>!$_` names the
        // label of the other `item1` line.
        var groupLabels: [String: String] = [:]
        for property in properties where property.name == "X-ABLABEL" {
            if let group = property.group { groupLabels[group] = appleLabel(property.text) }
        }
        var contact = Contact()
        var formattedName = ""
        var hasName = false
        var showsCompany = false
        for property in properties {
            let customLabel = property.group.flatMap { groupLabels[$0] }
            switch property.name {
            case "UID":
                if !property.text.isEmpty { contact.id = property.text }
            case "FN":
                formattedName = property.text
            case "N":
                let parts = property.components.map { $0.replacingAll(",", with: " ").trimmed }
                func part(_ index: Int) -> String { index < parts.count ? parts[index] : "" }
                contact.familyName = part(0)
                contact.givenName = part(1)
                contact.middleName = part(2)
                contact.namePrefix = part(3)
                contact.nameSuffix = part(4)
                hasName = parts.contains { !$0.isEmpty }
            case "NICKNAME":
                contact.nickname = property.text
            case "ORG":
                let parts = property.components
                contact.organization = parts.first ?? ""
                contact.department = parts.dropFirst().filter { !$0.isEmpty }.joined(separator: ", ")
            case "TITLE":
                contact.jobTitle = property.text
            case "TEL":
                contact.phones.append(LabeledValue(label: customLabel ?? phoneLabel(property.types), value: telephone(property.text)))
            case "EMAIL":
                contact.emails.append(LabeledValue(label: customLabel ?? plainLabel(property.types, otherwise: "other"), value: property.text))
            case "URL":
                contact.urls.append(LabeledValue(label: customLabel ?? plainLabel(property.types, otherwise: "homepage"), value: property.text))
            case "ADR":
                let parts = property.components
                func part(_ index: Int) -> String { index < parts.count ? parts[index] : "" }
                let street = [part(0), part(1), part(2)].filter { !$0.isEmpty }.joined(separator: "\n")
                contact.addresses.append(PostalAddress(
                    label: customLabel ?? plainLabel(property.types, otherwise: "other"),
                    street: street, city: part(3), region: part(4), postalCode: part(5), country: part(6)
                ))
            case "BDAY":
                contact.birthday = birthday(property.text, omittedYear: property.parameter("X-APPLE-OMIT-YEAR").first)
            case "NOTE":
                contact.note = property.text
            case "CATEGORIES":
                let categories = splitEscaped(property.value, on: ",").map(unescape)
                if categories.contains(where: { $0.lowercased() == "favorites" }) { contact.isFavorite = true }
                let others = categories.filter { $0.lowercased() != "favorites" && !$0.isEmpty }
                if !others.isEmpty {
                    contact.otherLines.append("CATEGORIES:" + others.map(escape).joined(separator: ","))
                }
            case "X-ABSHOWAS":
                showsCompany = property.text.uppercased() == "COMPANY"
            case "X-ABLABEL", "VERSION", "PRODID", "REV":
                break
            default:
                contact.otherLines.append(property.line)
            }
        }
        // A card with only a formatted name: take it for the given name,
        // unless it names the company.
        if !hasName, !formattedName.isEmpty, !showsCompany, formattedName != contact.organization {
            contact.givenName = formattedName
        }
        return contact
    }

    /// Apple's label, without its `_$!<…>!$_` wrapping, in the app's words.
    static func appleLabel(_ text: String) -> String {
        var label = text
        if label.hasPrefix("_$!<"), label.hasSuffix(">!$_") {
            label = String(label.dropFirst(4).dropLast(4))
        }
        switch label.lowercased() {
        case "mobile", "iphone", "cell": return "mobile"
        case "home", "work", "main", "pager", "other", "homepage": return label.lowercased()
        case "homefax": return "home fax"
        case "workfax": return "work fax"
        default: return label
        }
    }

    static func phoneLabel(_ types: Set<String>) -> String {
        if types.contains("fax") {
            if types.contains("work") { return "work fax" }
            if types.contains("home") { return "home fax" }
            return "fax"
        }
        if types.contains("cell") || types.contains("mobile") || types.contains("iphone") { return "mobile" }
        if types.contains("pager") { return "pager" }
        if types.contains("main") || types.contains("main-number") { return "main" }
        return plainLabel(types, otherwise: "other")
    }

    static func plainLabel(_ types: Set<String>, otherwise: String) -> String {
        if types.contains("work") { return "work" }
        if types.contains("home") { return "home" }
        if types.contains("other") { return "other" }
        return otherwise
    }

    /// A phone number without the `tel:` that vCard 4 puts before it.
    static func telephone(_ text: String) -> String {
        text.lowercased().hasPrefix("tel:") ? String(text.dropFirst(4)) : text
    }

    /// Reads `1990-03-04`, `19900304`, `--03-04`, `--0304` and Apple's
    /// placeholder year.
    static func birthday(_ text: String, omittedYear: String?) -> Birthday? {
        var digits = text.prefix { $0 != "T" }.filter(\.isNumber)
        var year: Int?
        if text.hasPrefix("--") {
            guard digits.count == 4 else { return nil }
        } else {
            guard digits.count == 8 else { return nil }
            year = Int(digits.prefix(4))
            digits = String(digits.dropFirst(4))
            if let omittedYear, Int(omittedYear) == year { year = nil }
        }
        guard let month = Int(digits.prefix(2)), let day = Int(digits.suffix(2)),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        return Birthday(year: year, month: month, day: day)
    }

    // MARK: Writing

    /// The contacts as vCard 3.0 text, with lines ending in CRLF.
    public static func write(_ contacts: [Contact]) -> String {
        contacts.map(write).joined()
    }

    /// One contact as a vCard 3.0 card.
    public static func write(_ contact: Contact) -> String {
        var lines = ["BEGIN:VCARD", "VERSION:3.0", "PRODID:-//Swift Linux//Contacts//EN"]
        lines.append("UID:" + escape(contact.id))
        lines.append("FN:" + escape(contact.isCompany ? contact.organization : contact.displayName))
        lines.append("N:" + [contact.familyName, contact.givenName, contact.middleName, contact.namePrefix, contact.nameSuffix].map(escape).joined(separator: ";"))
        if !contact.nickname.isEmpty { lines.append("NICKNAME:" + escape(contact.nickname)) }
        if !contact.organization.isEmpty || !contact.department.isEmpty {
            let parts = contact.department.isEmpty ? [contact.organization] : [contact.organization, contact.department]
            lines.append("ORG:" + parts.map(escape).joined(separator: ";"))
        }
        if !contact.jobTitle.isEmpty { lines.append("TITLE:" + escape(contact.jobTitle)) }
        if contact.isCompany { lines.append("X-ABShowAs:COMPANY") }

        // Labels vCard has no type for go in an Apple label, by group.
        let used = contact.otherLines.compactMap { line -> Int? in
            guard line.lowercased().hasPrefix("item"), let dot = line.firstIndex(of: ".") else { return nil }
            return Int(line[line.index(line.startIndex, offsetBy: 4)..<dot])
        }
        var nextGroup = (used.max() ?? 0) + 1
        func labeled(_ name: String, types: [String]?, label: String, value: String) {
            if let types {
                let parameters = types.map { ";TYPE=" + $0 }.joined()
                lines.append(name + parameters + ":" + value)
            } else {
                let group = "item\(nextGroup)"
                nextGroup += 1
                lines.append(group + "." + name + ":" + value)
                lines.append(group + ".X-ABLabel:" + escape(label))
            }
        }
        for phone in contact.phones {
            labeled("TEL", types: phoneTypes(phone.label), label: phone.label, value: escape(phone.value))
        }
        for email in contact.emails {
            labeled("EMAIL", types: plainTypes(email.label).map { ["INTERNET"] + $0 }, label: email.label, value: escape(email.value))
        }
        for address in contact.addresses {
            let parts = ["", "", address.street, address.city, address.region, address.postalCode, address.country]
            labeled("ADR", types: plainTypes(address.label), label: address.label, value: parts.map(escape).joined(separator: ";"))
        }
        for url in contact.urls {
            let types: [String]? = url.label == "homepage" ? [] : plainTypes(url.label)
            labeled("URL", types: types, label: url.label, value: escape(url.value))
        }
        if let birthday = contact.birthday {
            let month = pad(birthday.month)
            let day = pad(birthday.day)
            if let year = birthday.year {
                lines.append("BDAY:\(pad(year, 4))-\(month)-\(day)")
            } else {
                lines.append("BDAY:--\(month)-\(day)")
            }
        }
        if !contact.note.isEmpty { lines.append("NOTE:" + escape(contact.note)) }
        if contact.isFavorite { lines.append("CATEGORIES:Favorites") }
        lines += contact.otherLines
        lines.append("END:VCARD")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    static func phoneTypes(_ label: String) -> [String]? {
        switch label {
        case "mobile": ["CELL"]
        case "home": ["HOME"]
        case "work": ["WORK"]
        case "main": ["MAIN"]
        case "home fax": ["HOME", "FAX"]
        case "work fax": ["WORK", "FAX"]
        case "fax": ["FAX"]
        case "pager": ["PAGER"]
        case "other": ["OTHER"]
        default: nil
        }
    }

    static func plainTypes(_ label: String) -> [String]? {
        switch label {
        case "home": ["HOME"]
        case "work": ["WORK"]
        case "other": ["OTHER"]
        default: nil
        }
    }

    // MARK: Text

    /// Escapes text for a value: backslashes, newlines, commas and
    /// semicolons.
    static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "\\": result += "\\\\"
            case "\n", "\r\n": result += "\\n"
            case ",": result += "\\,"
            case ";": result += "\\;"
            default: result.append(character)
            }
        }
        return result
    }

    static func unescape(_ text: String) -> String {
        var result = ""
        var escaped = false
        for character in text {
            if escaped {
                switch character {
                case "n", "N": result.append("\n")
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Splits at separators no backslash escapes, leaving the parts
    /// escaped.
    static func splitEscaped(_ text: String, on separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false
        for character in text {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                current.append(character)
                escaped = true
            } else if character == separator {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts
    }

    /// Folds a line longer than 75 bytes onto lines that start with a
    /// space, without splitting a character.
    static func fold(_ line: String) -> String {
        guard line.utf8.count > 75 else { return line }
        var result = ""
        var count = 0
        for character in line {
            let size = character.utf8.count
            if count + size > 75 {
                result += "\r\n "
                count = 1
            }
            result.append(character)
            count += size
        }
        return result
    }

    /// Quoted-printable to text: `=C3=A9` to `é`, read as UTF-8, or as
    /// Latin-1 if it isn't UTF-8.
    static func decodeQuotedPrintable(_ text: String) -> String {
        var bytes: [UInt8] = []
        let utf8 = Array(text.utf8)
        var index = 0
        while index < utf8.count {
            let byte = utf8[index]
            if byte == UInt8(ascii: "="), index + 2 < utf8.count,
               let high = hexValue(utf8[index + 1]), let low = hexValue(utf8[index + 2]) {
                bytes.append(high << 4 | low)
                index += 3
            } else {
                bytes.append(byte)
                index += 1
            }
        }
        if let text = String(validatingUTF8Bytes: bytes) { return text }
        return String(bytes.map { Character(Unicode.Scalar($0)) })
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
        default: nil
        }
    }

    private static func pad(_ value: Int, _ width: Int = 2) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}

extension String {

    /// Text from UTF-8 bytes, or nil if they aren't valid UTF-8.
    init?(validatingUTF8Bytes bytes: [UInt8]) {
        var text = ""
        var iterator = bytes.makeIterator()
        var decoder = UTF8()
        loop: while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar): text.unicodeScalars.append(scalar)
            case .emptyInput: break loop
            case .error: return nil
            }
        }
        self = text
    }

    /// The string with every `target` replaced.
    func replacingAll(_ target: Character, with replacement: String) -> String {
        var result = ""
        for character in self {
            if character == target { result += replacement } else { result.append(character) }
        }
        return result
    }
}
