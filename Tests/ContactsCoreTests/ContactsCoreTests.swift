//
//  ContactsCoreTests.swift
//  CoreApps
//

import Testing
@testable import ContactsCore

func person(_ given: String, _ family: String, id: String = Identifier.make()) -> Contact {
    var contact = Contact(id: id)
    contact.givenName = given
    contact.familyName = family
    return contact
}

@Suite struct ContactTests {

    @Test func writesTheNameGivenNameFirst() {
        var contact = person("Ada", "Lovelace")
        contact.namePrefix = "Lady"
        #expect(contact.displayName == "Lady Ada Lovelace")
        #expect(contact.initials == "AL")
    }

    @Test func fallsBackWhenThereIsNoName() {
        var contact = Contact()
        #expect(contact.displayName == "No Name")
        #expect(contact.initials == "")
        contact.emails = [LabeledValue(label: "work", value: "ada@example.com")]
        #expect(contact.displayName == "ada@example.com")
        contact.organization = "Analytical Engines"
        #expect(contact.displayName == "Analytical Engines")
        #expect(contact.isCompany)
        #expect(contact.initials == "A")
    }

    @Test func describesTheJob() {
        var contact = person("Ada", "Lovelace")
        contact.jobTitle = "Programmer"
        contact.organization = "Analytical Engines"
        #expect(contact.jobSummary == "Programmer, Analytical Engines")
    }

    @Test func sortsAndSectionsByEitherName() {
        let contact = person("Ada", "Lovelace")
        #expect(contact.sortKey(.givenName) == "ada lovelace")
        #expect(contact.sortKey(.familyName) == "lovelace ada")
        #expect(contact.sectionLetter(.familyName) == "L")
        #expect(person("", "").sectionLetter(.givenName) == "#")
        #expect(person("Émile", "Zola").sectionLetter(.givenName) == "E")
        #expect(person("Łukasz", "Ćwik").sortKey(.familyName) == "cwik lukasz")
        #expect("Zoë".withoutAccents == "Zoe")
        #expect("Zoe\u{308}".withoutAccents == "Zoe")
    }

    @Test func searchesNamesEmailsAndNumbers() {
        var contact = person("Ada", "Lovelace")
        contact.emails = [LabeledValue(label: "home", value: "ada@example.com")]
        contact.phones = [LabeledValue(label: "mobile", value: "+44 (20) 7946-0018")]
        #expect(contact.matches("ada love"))
        #expect(contact.matches("LOVELACE"))
        #expect(contact.matches("example.com"))
        #expect(contact.matches("7946 0018"))
        #expect(contact.matches("2079"))
        #expect(!contact.matches("babbage"))
        #expect(person("Émile", "Zola").matches("emile"))
        #expect(person("Emile", "Zola").matches("émile"))
        #expect(!contact.matches("12"))
        #expect(contact.matches(""))
    }

    @Test func tidiesBlankFields() {
        var contact = person("  Ada ", "Lovelace")
        contact.phones = [LabeledValue(label: "mobile", value: " "), LabeledValue(label: "work", value: " 555 ")]
        contact.addresses = [PostalAddress()]
        let tidied = contact.tidied
        #expect(tidied.givenName == "Ada")
        #expect(tidied.phones.map(\.value) == ["555"])
        #expect(tidied.addresses.isEmpty)
        #expect(Contact().isEmpty)
        #expect(!tidied.isEmpty)
    }

    @Test func picksTheSameColorEachTime() {
        let contact = person("Ada", "Lovelace", id: "fixed")
        #expect(contact.colorIndex(of: 8) == contact.colorIndex(of: 8))
        #expect((0..<8).contains(contact.colorIndex(of: 8)))
    }

    @Test func makesUUIDs() {
        let id = Identifier.make()
        #expect(id.count == 36)
        #expect(Array(id)[14] == "4")
        #expect(Identifier.make() != id)
    }

    @Test func writesAddressesOnLines() {
        let address = PostalAddress(street: "12 St James's Square", city: "London", region: "", postalCode: "SW1Y 4LB", country: "United Kingdom")
        #expect(address.lines == ["12 St James's Square", "London, SW1Y 4LB", "United Kingdom"])
        #expect(address.singleLine == "12 St James's Square, London, SW1Y 4LB, United Kingdom")
    }

    @Test func writesBirthdays() {
        #expect(Birthday(year: 1815, month: 12, day: 10).text == "December 10, 1815")
        #expect(Birthday(month: 3, day: 4).text == "March 4")
    }
}

@Suite struct VCardReadingTests {

    @Test func readsAVersion3Card() {
        let text = """
        BEGIN:VCARD\r
        VERSION:3.0\r
        UID:ada-1\r
        FN:Ada Lovelace\r
        N:Lovelace;Ada;Augusta;Lady;\r
        ORG:Analytical Engines;Research\r
        TITLE:Programmer\r
        TEL;TYPE=CELL,VOICE:+44 20 7946 0018\r
        TEL;TYPE=WORK;TYPE=FAX:+44 20 7946 0019\r
        EMAIL;TYPE=INTERNET;TYPE=HOME:ada@example.com\r
        ADR;TYPE=HOME:;;12 St James's Square;London;;SW1Y 4LB;United Kingdom\r
        BDAY:1815-12-10\r
        NOTE:Wrote the first program\\, for the engine.\\nPoet's daughter.\r
        CATEGORIES:Favorites,Mathematicians\r
        END:VCARD\r

        """
        let contacts = VCard.parse(text)
        #expect(contacts.count == 1)
        let ada = contacts[0]
        #expect(ada.id == "ada-1")
        #expect(ada.givenName == "Ada")
        #expect(ada.middleName == "Augusta")
        #expect(ada.familyName == "Lovelace")
        #expect(ada.namePrefix == "Lady")
        #expect(ada.organization == "Analytical Engines")
        #expect(ada.department == "Research")
        #expect(ada.jobTitle == "Programmer")
        #expect(ada.phones.map(\.label) == ["mobile", "work fax"])
        #expect(ada.emails.first?.label == "home")
        #expect(ada.addresses.first?.street == "12 St James's Square")
        #expect(ada.addresses.first?.postalCode == "SW1Y 4LB")
        #expect(ada.birthday == Birthday(year: 1815, month: 12, day: 10))
        #expect(ada.note == "Wrote the first program, for the engine.\nPoet's daughter.")
        #expect(ada.isFavorite)
        #expect(ada.otherLines == ["CATEGORIES:Mathematicians"])
    }

    @Test func readsAndroidsQuotedPrintable() {
        let text = """
        BEGIN:VCARD
        VERSION:2.1
        N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Zola;=C3=89mile;;;
        FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=C3=89mile Zola
        TEL;CELL;PREF:+33 1 23 45 67 89
        NOTE;ENCODING=QUOTED-PRINTABLE:J'accuse=0D=0A=
        L'Aurore
        END:VCARD
        """
        let contacts = VCard.parse(text)
        #expect(contacts.count == 1)
        #expect(contacts[0].givenName == "Émile")
        #expect(contacts[0].familyName == "Zola")
        #expect(contacts[0].phones.first?.label == "mobile")
        #expect(contacts[0].note == "J'accuse\r\nL'Aurore")
    }

    @Test func readsApplesLabelsAndOmittedYears() {
        let text = """
        BEGIN:VCARD
        VERSION:3.0
        N:Babbage;Charles;;;
        item1.TEL:+44 20 7946 0020
        item1.X-ABLabel:_$!<Mobile>!$_
        item2.TEL:+44 20 7946 0021
        item2.X-ABLabel:Workshop
        item3.URL:https://example.com/engine
        item3.X-ABLabel:_$!<HomePage>!$_
        BDAY;X-APPLE-OMIT-YEAR=1604:1604-12-26
        END:VCARD
        """
        let charles = VCard.parse(text)[0]
        #expect(charles.phones.map(\.label) == ["mobile", "Workshop"])
        #expect(charles.urls.first?.label == "homepage")
        #expect(charles.birthday == Birthday(month: 12, day: 26))
    }

    @Test func unfoldsLongLines() {
        let text = "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Lovelace;Ada;;;\r\nNOTE:The Analytical Engine weaves algebraic \r\n patterns just as the Jacquard loom weaves flowers.\r\nEND:VCARD\r\n"
        #expect(VCard.parse(text)[0].note == "The Analytical Engine weaves algebraic patterns just as the Jacquard loom weaves flowers.")
    }

    @Test func takesTheFormattedNameWhenThereIsNoOther() {
        let text = "BEGIN:VCARD\nVERSION:4.0\nFN:Grace Hopper\nTEL;VALUE=uri;TYPE=work:tel:+1-555-0100\nEND:VCARD\n"
        let grace = VCard.parse(text)[0]
        #expect(grace.givenName == "Grace Hopper")
        #expect(grace.phones.first?.value == "+1-555-0100")
        #expect(grace.phones.first?.label == "work")
    }

    @Test func readsACompany() {
        let text = "BEGIN:VCARD\nVERSION:3.0\nN:;;;;\nFN:Acme\nORG:Acme;\nX-ABShowAs:COMPANY\nEND:VCARD\n"
        let acme = VCard.parse(text)[0]
        #expect(acme.givenName.isEmpty)
        #expect(acme.isCompany)
        #expect(acme.displayName == "Acme")
    }

    @Test func keepsWhatItDoesNotRead() {
        let text = "BEGIN:VCARD\nVERSION:3.0\nN:Lovelace;Ada;;;\nPHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQ\nitem7.X-ABRELATEDNAMES:Byron\nEND:VCARD\n"
        let ada = VCard.parse(text)[0]
        #expect(ada.otherLines == ["PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQ", "item7.X-ABRELATEDNAMES:Byron"])
    }

    @Test func readsSeveralCardsAndSkipsEmptyOnes() {
        let text = """
        BEGIN:VCARD
        VERSION:3.0
        N:Lovelace;Ada;;;
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        N:;;;;
        END:VCARD
        BEGIN:VCARD
        VERSION:3.0
        N:Hopper;Grace;;;
        END:VCARD
        """
        #expect(VCard.parse(text).map(\.givenName) == ["Ada", "Grace"])
    }

    @Test func readsBirthdaysWrittenEveryWay() {
        #expect(VCard.birthday("19900304", omittedYear: nil) == Birthday(year: 1990, month: 3, day: 4))
        #expect(VCard.birthday("--0304", omittedYear: nil) == Birthday(month: 3, day: 4))
        #expect(VCard.birthday("1990-03-04T00:00:00Z", omittedYear: nil) == Birthday(year: 1990, month: 3, day: 4))
        #expect(VCard.birthday("1990-13-04", omittedYear: nil) == nil)
        #expect(VCard.birthday("soon", omittedYear: nil) == nil)
    }
}

@Suite struct VCardWritingTests {

    func ada() -> Contact {
        var ada = person("Ada", "Lovelace", id: "ada-1")
        ada.organization = "Analytical Engines"
        ada.phones = [
            LabeledValue(label: "mobile", value: "+44 20 7946 0018"),
            LabeledValue(label: "Workshop", value: "+44 20 7946 0019"),
        ]
        ada.emails = [LabeledValue(label: "home", value: "ada@example.com")]
        ada.urls = [LabeledValue(label: "homepage", value: "https://example.com")]
        ada.addresses = [PostalAddress(label: "home", street: "12 St James's Square", city: "London", postalCode: "SW1Y 4LB")]
        ada.birthday = Birthday(month: 12, day: 10)
        ada.note = "Notes; with, punctuation\nand a second line."
        ada.isFavorite = true
        ada.otherLines = ["PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQ", "item1.X-ABRELATEDNAMES:Byron"]
        return ada
    }

    @Test func writesVersion3() {
        let text = VCard.write(ada())
        #expect(text.hasPrefix("BEGIN:VCARD\r\nVERSION:3.0\r\n"))
        #expect(text.hasSuffix("END:VCARD\r\n"))
        #expect(text.contains("\r\nN:Lovelace;Ada;;;\r\n"))
        #expect(text.contains("\r\nTEL;TYPE=CELL:+44 20 7946 0018\r\n"))
        #expect(text.contains("\r\nEMAIL;TYPE=INTERNET;TYPE=HOME:ada@example.com\r\n"))
        #expect(text.contains("\r\nBDAY:--12-10\r\n"))
        #expect(text.contains("\r\nNOTE:Notes\\; with\\, punctuation\\nand a second line.\r\n"))
        #expect(text.contains("\r\nCATEGORIES:Favorites\r\n"))
    }

    @Test func givesOtherLabelsAGroupThatIsFree() {
        let text = VCard.write(ada())
        // item1 is taken by a kept line.
        #expect(text.contains("\r\nitem2.TEL:+44 20 7946 0019\r\nitem2.X-ABLabel:Workshop\r\n"))
    }

    @Test func readsBackWhatItWrites() {
        let original = ada()
        let read = VCard.parse(VCard.write(original))
        #expect(read.count == 1)
        let copy = read[0]
        #expect(copy.id == original.id)
        #expect(copy.displayName == original.displayName)
        #expect(copy.organization == original.organization)
        #expect(copy.phones.map(\.label) == original.phones.map(\.label))
        #expect(copy.phones.map(\.value) == original.phones.map(\.value))
        #expect(copy.emails.map(\.value) == original.emails.map(\.value))
        #expect(copy.urls.map(\.label) == ["homepage"])
        #expect(copy.addresses.first?.lines == original.addresses.first?.lines)
        #expect(copy.birthday == original.birthday)
        #expect(copy.note == original.note)
        #expect(copy.isFavorite)
        #expect(copy.otherLines == original.otherLines)
    }

    @Test func foldsLongLinesWithoutSplittingCharacters() {
        let line = "NOTE:" + String(repeating: "é", count: 60)
        let folded = VCard.fold(line)
        let lines = folded.split(separator: "\r\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.utf8.count <= 75 })
        #expect(VCard.unfold(folded) == [line])
    }
}

@Suite struct ContactListTests {

    @Test func sectionsByLetterWithOthersLast() {
        let contacts = [person("Grace", "Hopper"), person("Ada", "Lovelace"), person("", ""), person("Alan", "Turing")]
        let sections = ContactList.sections(contacts, by: .givenName)
        #expect(sections.map(\.letter) == ["A", "G", "#"])
        #expect(sections[0].contacts.map(\.givenName) == ["Ada", "Alan"])
        let byFamily = ContactList.sections(contacts, by: .familyName)
        #expect(byFamily.map(\.letter) == ["H", "L", "T", "#"])
    }

    @Test func mergesAnImportById() {
        let ada = person("Ada", "Lovelace", id: "ada")
        let grace = person("Grace", "Hopper", id: "grace")
        var newAda = ada
        newAda.jobTitle = "Programmer"
        let (merged, result) = ContactList.merging([newAda, person("Alan", "Turing", id: "alan")], into: [ada, grace])
        #expect(result == ImportResult(added: 1, updated: 1))
        #expect(merged.map(\.id) == ["ada", "grace", "alan"])
        #expect(merged[0].jobTitle == "Programmer")
    }
}
