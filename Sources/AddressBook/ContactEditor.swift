//
//  ContactEditor.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ContactsCore
import Foundation

/// A form for a new contact or a change to one. It gives back the contact
/// when done, and nil when cancelled.
struct ContactEditor: View {

    @State private var contact: Contact

    @State private var showsMoreNames: Bool

    private let isNew: Bool

    private let done: (Contact?) -> Void

    init(contact: Contact, isNew: Bool, done: @escaping (Contact?) -> Void) {
        _contact = State(initialValue: contact)
        _showsMoreNames = State(initialValue: !(contact.namePrefix + contact.middleName + contact.nameSuffix + contact.nickname + contact.department).isEmpty)
        self.isNew = isNew
        self.done = done
    }

    var body: some View {
        NavigationStack {
            Form {
                names
                labeled("Phone", values: $contact.phones, labels: LabeledValue.phoneLabels, defaultLabel: "mobile")
                labeled("Email", values: $contact.emails, labels: LabeledValue.emailLabels, defaultLabel: "home")
                labeled("URL", values: $contact.urls, labels: LabeledValue.urlLabels, defaultLabel: "homepage")
                addresses
                birthday
                Section("Notes") {
                    TextEditor(text: $contact.note)
                        .frame(minHeight: 88)
                }
            }
            .navigationTitle(isNew ? "New Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { done(contact) }
                        .disabled(contact.tidied.isEmpty)
                }
            }
        }
    }

    // MARK: Names

    private var names: some View {
        Section {
            if showsMoreNames {
                TextField("Prefix", text: $contact.namePrefix)
            }
            TextField("First name", text: $contact.givenName)
            if showsMoreNames {
                TextField("Middle name", text: $contact.middleName)
            }
            TextField("Last name", text: $contact.familyName)
            if showsMoreNames {
                TextField("Suffix", text: $contact.nameSuffix)
                TextField("Nickname", text: $contact.nickname)
            }
            TextField("Company", text: $contact.organization)
            if showsMoreNames {
                TextField("Department", text: $contact.department)
            }
            TextField("Job title", text: $contact.jobTitle)
            if !showsMoreNames {
                Button("More Name Fields") { showsMoreNames = true }
            }
        }
    }

    // MARK: Phones, emails, links

    private func labeled(_ title: String, values: Binding<[LabeledValue]>, labels: [String], defaultLabel: String) -> some View {
        Section {
            ForEach(values.wrappedValue) { item in
                HStack(spacing: 8) {
                    labelMenu(item.label, labels: labels) { label in
                        update(values, item.id) { $0.label = label }
                    }
                    TextField(title, text: Binding(
                        get: { values.wrappedValue.first { $0.id == item.id }?.value ?? "" },
                        set: { value in update(values, item.id) { $0.value = value } }
                    ))
                    removeButton {
                        values.wrappedValue.removeAll { $0.id == item.id }
                    }
                }
            }
            Button("Add \(title)") {
                // The next label not already used, as phones fill up
                // mobile, home, work.
                let used = Set(values.wrappedValue.map(\.label))
                let label = ([defaultLabel] + labels).first { !used.contains($0) } ?? defaultLabel
                values.wrappedValue.append(LabeledValue(label: label, value: ""))
            }
        }
    }

    private func update(_ values: Binding<[LabeledValue]>, _ id: String, _ change: (inout LabeledValue) -> Void) {
        guard let index = values.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
        change(&values.wrappedValue[index])
    }

    /// A menu of labels, showing the one chosen. A label from another app
    /// that isn't in the list stays on offer.
    private func labelMenu(_ current: String, labels: [String], choose: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(labels.contains(current) ? labels : [current] + labels, id: \.self) { label in
                Button(label) { choose(label) }
            }
        } label: {
            HStack(spacing: 2) {
                Text(current)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .frame(width: 92, alignment: .leading)
        }
    }

    private func removeButton(_ remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            Image(systemName: Symbols.remove)
                .foregroundStyle(Color.red)
        }
        .buttonStyle(.plain)
    }

    // MARK: Addresses

    private var addresses: some View {
        Section {
            ForEach(contact.addresses) { address in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        labelMenu(address.label, labels: PostalAddress.labels) { label in
                            updateAddress(address.id) { $0.label = label }
                        }
                        Spacer()
                        removeButton {
                            contact.addresses.removeAll { $0.id == address.id }
                        }
                    }
                    TextField("Street", text: addressBinding(address.id, \.street))
                    TextField("City", text: addressBinding(address.id, \.city))
                    HStack {
                        TextField("State", text: addressBinding(address.id, \.region))
                        TextField("Postal code", text: addressBinding(address.id, \.postalCode))
                    }
                    TextField("Country", text: addressBinding(address.id, \.country))
                }
            }
            Button("Add Address") {
                let used = Set(contact.addresses.map(\.label))
                contact.addresses.append(PostalAddress(label: PostalAddress.labels.first { !used.contains($0) } ?? "other"))
            }
        }
    }

    private func updateAddress(_ id: String, _ change: (inout PostalAddress) -> Void) {
        guard let index = contact.addresses.firstIndex(where: { $0.id == id }) else { return }
        change(&contact.addresses[index])
    }

    private func addressBinding(_ id: String, _ path: WritableKeyPath<PostalAddress, String>) -> Binding<String> {
        Binding(
            get: { contact.addresses.first { $0.id == id }?[keyPath: path] ?? "" },
            set: { value in updateAddress(id) { $0[keyPath: path] = value } }
        )
    }

    // MARK: Birthday

    private var birthday: some View {
        Section {
            Toggle("Birthday", isOn: Binding(
                get: { contact.birthday != nil },
                set: { contact.birthday = $0 ? Self.birthday(from: Date(), withYear: true) : nil }
            ))
            if let current = contact.birthday {
                DatePicker("Date", selection: Binding(
                    get: { Self.date(from: current) },
                    set: { contact.birthday = Self.birthday(from: $0, withYear: current.year != nil) }
                ), displayedComponents: [.date])
                Toggle("Year Known", isOn: Binding(
                    get: { current.year != nil },
                    set: { known in
                        contact.birthday?.year = known ? Calendar.current.component(.year, from: Self.date(from: current)) : nil
                    }
                ))
            }
        }
    }

    /// The birthday as a date, in 2000 (a leap year) when the year isn't
    /// known.
    static func date(from birthday: Birthday) -> Date {
        let parts = DateComponents(year: birthday.year ?? 2000, month: birthday.month, day: birthday.day, hour: 12)
        return Calendar.current.date(from: parts) ?? Date()
    }

    static func birthday(from date: Date, withYear: Bool) -> Birthday {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Birthday(year: withYear ? parts.year : nil, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

#endif
