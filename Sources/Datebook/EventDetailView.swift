//
//  EventDetailView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CalendarCore
import CoreAppsUI
import Foundation

/// An event: when, where, how it repeats, its calendar and alert.
struct EventDetailView: View {

    @EnvironmentObject private var store: CalendarStore

    @Environment(\.dismiss) private var dismiss

    let route: OccurrenceRoute

    @State private var isEditing = false

    @State private var isConfirmingDelete = false

    @State private var isExporting = false

    var body: some View {
        if let event = store.event(id: route.eventID) {
            details(event, occurrence: Occurrence(event: event, start: route.start, end: route.start.adding(minutes: event.duration)))
        } else {
            EmptyState("No Event", message: "The event was deleted.")
        }
    }

    private func details(_ event: Event, occurrence: Occurrence) -> some View {
        let calendar = store.calendar(id: event.calendarID)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.displayTitle)
                        .font(.title2)
                    if !event.location.isEmpty {
                        Text(event.location)
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach(CalendarText.fullSpan(occurrence, today: store.today, uses24Hour: store.uses24Hour), id: \.self) { line in
                        Text(line)
                    }
                    if let recurrence = event.recurrence {
                        Text(recurrence.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                HStack {
                    Text("Calendar")
                    Spacer()
                    Circle()
                        .fill(CalendarColors.color(calendar?.color ?? 0))
                        .frame(width: 10, height: 10)
                    Text(calendar?.name ?? "None")
                        .foregroundStyle(Color.secondary)
                }
                HStack {
                    Text("Alert")
                    Spacer()
                    Text(CalendarText.alert(event.alert))
                        .foregroundStyle(Color.secondary)
                }
            }
            if !event.notes.isEmpty {
                Section("Notes") {
                    Text(event.notes)
                }
            }
            Section {
                Button("Delete Event", role: .destructive) { isConfirmingDelete = true }
                    .foregroundStyle(Color.red)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export Event…") { isExporting = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EventEditor(event: event, isNew: false) { saved in
                isEditing = false
                if let saved { store.save(saved) }
            }
            .environmentObject(store)
        }
        .confirmationDialog(
            event.recurrence == nil ? "Delete this event?" : "This is a repeating event.",
            isPresented: $isConfirmingDelete
        ) {
            if event.recurrence != nil {
                Button("Delete This Event Only", role: .destructive) {
                    store.deleteOccurrence(of: event, on: occurrence.start.date)
                    dismiss()
                }
                Button("Delete All Future Events", role: .destructive) {
                    deleteFuture(event, from: occurrence.start.date)
                    dismiss()
                }
            } else {
                Button("Delete Event", role: .destructive) {
                    store.delete(event)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: ICalendarDocument(text: store.exportText([event])),
            contentType: .iCalendarFile,
            defaultFilename: "\(event.displayTitle).ics"
        ) { result in
            if case let .failure(error) = result { store.failure = error.localizedDescription }
        }
    }

    /// Ends a repeating event before a day, or deletes it if that's its
    /// first.
    private func deleteFuture(_ event: Event, from day: CivilDate) {
        guard day > event.start.date, var recurrence = event.recurrence else {
            store.delete(event)
            return
        }
        recurrence.count = nil
        recurrence.until = day.adding(days: -1)
        var ended = event
        ended.recurrence = recurrence
        store.save(ended)
    }
}

/// The calendars: which are shown, and adding and removing them.
struct CalendarsView: View {

    @EnvironmentObject private var store: CalendarStore

    let done: () -> Void

    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.calendars) { calendar in
                        Toggle(isOn: Binding(get: { calendar.isShown }, set: { store.setShown($0, calendar) })) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(CalendarColors.color(calendar.color))
                                    .frame(width: 12, height: 12)
                                Text(calendar.name)
                            }
                        }
                        .contextMenu {
                            if store.calendars.count > 1 {
                                Button("Delete Calendar and Its Events", role: .destructive) {
                                    store.deleteCalendar(calendar)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Hidden calendars' events aren't shown and don't alert.")
                }
                Section("Add a Calendar") {
                    HStack {
                        TextField("Name", text: $newName)
                        Button("Add") {
                            store.addCalendar(named: newName.trimmingCharacters(in: .whitespaces))
                            newName = ""
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Calendars")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }
}

#endif
