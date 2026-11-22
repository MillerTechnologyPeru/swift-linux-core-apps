//
//  EventEditor.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CalendarCore
import Foundation

/// A form for a new event or a change to one: it gives back the event when
/// done, and nil when cancelled. A change to a repeating event changes
/// every occurrence.
struct EventEditor: View {

    @EnvironmentObject private var store: CalendarStore

    @State private var event: Event

    private let isNew: Bool

    private let done: (Event?) -> Void

    init(event: Event, isNew: Bool, done: @escaping (Event?) -> Void) {
        _event = State(initialValue: event)
        self.isNew = isNew
        self.done = done
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $event.title)
                    TextField("Location", text: $event.location)
                }
                Section {
                    Toggle("All-day", isOn: allDay)
                    DatePicker("Starts", selection: start, displayedComponents: event.isAllDay ? [.date] : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: end, displayedComponents: event.isAllDay ? [.date] : [.date, .hourAndMinute])
                    if event.end < event.start {
                        Text("The event ends before it starts.")
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    }
                }
                repeats
                Section {
                    Picker("Calendar", selection: $event.calendarID) {
                        ForEach(store.calendars) { calendar in
                            Text(calendar.name).tag(calendar.id)
                        }
                    }
                    Picker("Alert", selection: $event.alert) {
                        Text(CalendarText.alert(nil)).tag(Int?.none)
                        ForEach(CalendarText.alertChoices, id: \.self) { minutes in
                            Text(CalendarText.alert(minutes)).tag(Int?.some(minutes))
                        }
                    }
                } footer: {
                    Text("Alerts come only while Calendar is open.")
                }
                Section("Notes") {
                    TextEditor(text: $event.notes)
                        .frame(minHeight: 88)
                }
            }
            .navigationTitle(isNew ? "New Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") {
                        var saved = event
                        saved.title = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        done(saved)
                    }
                    .disabled(event.isEmpty || event.end < event.start)
                }
            }
        }
    }

    // MARK: Repeating

    @ViewBuilder
    private var repeats: some View {
        let preset = event.recurrence.map { $0.preset(startingOn: event.start.date) } ?? .never
        Section {
            Picker("Repeat", selection: Binding(
                get: { preset ?? .never },
                set: { newPreset in
                    let ending = (event.recurrence?.until, event.recurrence?.count)
                    event.recurrence = newPreset.recurrence(startingOn: event.start.date)
                    event.recurrence?.until = ending.0
                    event.recurrence?.count = ending.1
                }
            )) {
                ForEach(Recurrence.Preset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            if let recurrence = event.recurrence {
                if preset == nil {
                    // A rule from another calendar the presets don't cover.
                    Text(recurrence.summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Toggle("End Repeat", isOn: Binding(
                    get: { recurrence.until != nil || recurrence.count != nil },
                    set: { ends in
                        event.recurrence?.count = nil
                        event.recurrence?.until = ends ? event.start.date.adding(months: 1) : nil
                    }
                ))
                if let until = recurrence.until {
                    DatePicker("On", selection: Binding(
                        get: { CalendarStore.date(DateTime(date: until, hour: 12, minute: 0)) },
                        set: { event.recurrence?.until = CalendarStore.dateTime($0).date }
                    ), displayedComponents: [.date])
                } else if let count = recurrence.count {
                    Text(count == 1 ? "After 1 time" : "After \(count) times")
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    // MARK: Times

    private var allDay: Binding<Bool> {
        Binding(
            get: { event.isAllDay },
            set: { isAllDay in
                event.isAllDay = isAllDay
                if isAllDay {
                    // Midnight to the midnight after the last day.
                    let last = max(event.start.date, event.end.minute == 0 && event.end.date > event.start.date ? event.end.date.adding(days: -1) : event.end.date)
                    event.start = DateTime(date: event.start.date)
                    event.end = DateTime(date: last.adding(days: 1))
                } else {
                    event.start = DateTime(date: event.start.date, hour: 9, minute: 0)
                    event.end = event.start.adding(minutes: 60)
                }
            }
        )
    }

    private var start: Binding<Date> {
        Binding(
            get: { CalendarStore.date(event.isAllDay ? DateTime(date: event.start.date, hour: 12, minute: 0) : event.start) },
            set: { date in
                // Moving the start keeps the length.
                let length = event.duration
                let time = CalendarStore.dateTime(date)
                event.start = event.isAllDay ? DateTime(date: time.date) : time
                event.end = event.start.adding(minutes: length)
            }
        )
    }

    /// The end, which for an all-day event the form shows as its last day.
    private var end: Binding<Date> {
        Binding(
            get: {
                let shown = event.isAllDay ? DateTime(date: event.end.date.adding(days: -1), hour: 12, minute: 0) : event.end
                return CalendarStore.date(shown)
            },
            set: { date in
                let time = CalendarStore.dateTime(date)
                event.end = event.isAllDay ? DateTime(date: time.date.adding(days: 1)) : time
            }
        )
    }
}

#endif
