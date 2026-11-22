//
//  CalendarApp.swift
//  CoreApps
//

// The calendar reminds only while it's open, and imports and exports
// through the system's file dialogs: a program for now, on Cacao or on
// Apple's SwiftUI.
#if Native || Apple

import AppUI
import CalendarCore
import CoreAppsUI
import Foundation
#if Apple
import UniformTypeIdentifiers
#endif

/// The calendar.
public struct CalendarApp: App {

    /// An iCalendar file to import at launch: `calendar invite.ics`.
    private let importing: URL?

    public init() {
        UTType.declareICalendar()
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
        WindowGroup("Calendar") {
            CalendarView(importing: importing)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            CalendarView(importing: importing)
        }
        #endif
    }
}

/// An occurrence to open: its event, and when it starts.
struct OccurrenceRoute: Hashable {
    var eventID: String
    var start: DateTime
}

/// The colors calendars are drawn in.
enum CalendarColors {

    static let all: [Color] = [
        Color(red: 0.2, green: 0.47, blue: 0.96),
        Color(red: 0.94, green: 0.33, blue: 0.31),
        Color(red: 0.3, green: 0.72, blue: 0.38),
        Color(red: 0.98, green: 0.6, blue: 0.13),
        Color(red: 0.6, green: 0.38, blue: 0.86),
        Color(red: 0.13, green: 0.68, blue: 0.75),
        Color(red: 0.9, green: 0.38, blue: 0.64),
        Color(red: 0.55, green: 0.47, blue: 0.36),
    ]

    static func color(_ index: Int) -> Color {
        all[((index % all.count) + all.count) % all.count]
    }
}

/// A month's grid, and the day picked in it with its events below.
public struct CalendarView: View {

    @StateObject private var store = CalendarStore()

    @State private var path: [OccurrenceRoute] = []

    @State private var month: CivilDate

    @State private var selected: CivilDate

    @State private var isCreating = false

    @State private var isImporting = false

    @State private var isExporting = false

    @State private var showsCalendars = false

    @State private var message: String?

    private let importing: URL?

    public init(importing: URL? = nil) {
        let today = CalendarStore.dateTime(Date()).date
        _month = State(initialValue: today.startOfMonth)
        _selected = State(initialValue: today)
        self.importing = importing
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                MonthGrid(month: $month, selected: $selected)
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: 1)
                DayList(day: selected) { occurrence in
                    path.append(OccurrenceRoute(eventID: occurrence.event.id, start: occurrence.start))
                }
            }
            // Cacao's bar is too narrow for a title beside three buttons;
            // the month says where you are.
            .navigationTitle(Self.title)
            #if Apple && os(iOS)
            // The month says where you are; a large title would push it down.
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") {
                        selected = store.today
                        month = store.today.startOfMonth
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Calendars…") { showsCalendars = true }
                        Button("Import Events…") { isImporting = true }
                        Button("Export All…") { isExporting = true }
                            .disabled(store.events.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .navigationDestination(for: OccurrenceRoute.self) { route in
                EventDetailView(route: route)
            }
        }
        .environmentObject(store)
        .sheet(isPresented: $isCreating) {
            EventEditor(event: newEvent(), isNew: true) { saved in
                isCreating = false
                if let saved {
                    store.save(saved)
                    selected = saved.start.date
                    month = saved.start.date.startOfMonth
                }
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showsCalendars) {
            CalendarsView { showsCalendars = false }
                .environmentObject(store)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.iCalendarFile]) { result in
            switch result {
            case let .success(url): message = store.importEvents(from: url, into: store.calendars[0].id)
            case let .failure(error): message = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $isExporting, document: ICalendarDocument(text: store.exportText()), contentType: .iCalendarFile, defaultFilename: "Calendar.ics") { result in
            switch result {
            case let .success(url): message = "Exported \(store.events.count) events to “\(url.lastPathComponent)”."
            case let .failure(error): message = error.localizedDescription
            }
        }
        .alert("Calendar", isPresented: messageIsShown) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
        .alert(store.dueAlerts.first?.event.displayTitle ?? "", isPresented: alertIsShown) {
            Button("OK") { store.dueAlerts.removeFirst() }
        } message: {
            Text(store.dueAlerts.first.map { CalendarText.reminder($0, now: store.now, uses24Hour: store.uses24Hour) } ?? "")
        }
        .alert("Can't Keep the Calendar", isPresented: failureIsShown) {
            Button("OK") { store.failure = nil }
        } message: {
            Text(store.failure ?? "")
        }
        .task {
            if let importing {
                message = await store.importEvents(from: importing, into: store.calendars[0].id)
            }
            await store.poll()
        }
    }

    #if Native
    private static let title = ""
    #else
    private static let title = "Calendar"
    #endif

    /// An hour-long event at the next hour of the day picked.
    private func newEvent() -> Event {
        let now = store.now
        let hour = selected == now.date ? min(23, now.hour + 1) : 9
        let start = DateTime(date: selected, hour: hour, minute: 0)
        let calendar = store.calendars.first(where: \.isShown) ?? store.calendars[0]
        return Event(title: "", calendarID: calendar.id, start: start, end: start.adding(minutes: 60))
    }

    private var messageIsShown: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }

    private var alertIsShown: Binding<Bool> {
        Binding(get: { !store.dueAlerts.isEmpty }, set: { if !$0, !store.dueAlerts.isEmpty { store.dueAlerts.removeFirst() } })
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { store.failure != nil }, set: { if !$0 { store.failure = nil } })
    }
}

/// A month, a week to a row, with a dot under days that have events.
struct MonthGrid: View {

    @EnvironmentObject private var store: CalendarStore

    @Binding var month: CivilDate

    @Binding var selected: CivilDate

    var body: some View {
        let weeks = Agenda.weeks(of: month, firstWeekday: store.firstWeekday)
        let days = store.days(from: weeks.first?.first ?? month, through: weeks.last?.last ?? month)
        let today = store.today
        VStack(spacing: 4) {
            HStack {
                Button {
                    month = month.adding(months: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: Metrics.minimumTarget, height: 32)
                }
                Spacer()
                Text(CalendarText.month(month))
                    .font(.headline)
                Spacer()
                Button {
                    month = month.adding(months: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: Metrics.minimumTarget, height: 32)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(CalendarText.weekdayInitials(firstWeekday: store.firstWeekday).enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks, id: \.first) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        cell(day, occurrences: days[day] ?? [], today: today)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                month = month.adding(months: value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func cell(_ day: CivilDate, occurrences: [Occurrence], today: CivilDate) -> some View {
        let isSelected = day == selected
        let isToday = day == today
        let inMonth = day.month == month.month
        let colors = Array(Set(occurrences.compactMap { store.calendar(id: $0.event.calendarID)?.color })).sorted().prefix(3)
        return Button {
            selected = day
            if !inMonth { month = day.startOfMonth }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(isToday ? Color.red : Color.accentColor)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(day.day)")
                        .font(.body.weight(isToday || isSelected ? .semibold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(
                            isSelected ? Color.white : isToday ? Color.red : inMonth ? Color.primary : Color.secondary
                        )
                }
                .frame(height: 32)
                HStack(spacing: 2) {
                    ForEach(Array(colors), id: \.self) { color in
                        Circle()
                            .fill(CalendarColors.color(color))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A day's events, all-day ones first.
struct DayList: View {

    @EnvironmentObject private var store: CalendarStore

    let day: CivilDate

    let open: (Occurrence) -> Void

    var body: some View {
        let occurrences = store.days(from: day, through: day)[day] ?? []
        VStack(alignment: .leading, spacing: 0) {
            Text(CalendarText.relativeDate(day, today: store.today))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.vertical, 8)
            if occurrences.isEmpty {
                EmptyState("No Events")
            } else {
                List(occurrences) { occurrence in
                    Button {
                        open(occurrence)
                    } label: {
                        OccurrenceRow(occurrence: occurrence, day: day)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }
}

/// An event in a day's list: its calendar's color, title, time and place.
struct OccurrenceRow: View {

    @EnvironmentObject private var store: CalendarStore

    let occurrence: Occurrence

    let day: CivilDate

    var body: some View {
        let color = CalendarColors.color(store.calendar(id: occurrence.event.calendarID)?.color ?? 0)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(occurrence.event.displayTitle)
                    .lineLimit(1)
                if !occurrence.event.location.isEmpty {
                    Text(occurrence.event.location)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(CalendarText.span(occurrence, on: day, uses24Hour: store.uses24Hour))
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: Metrics.minimumTarget)
        .contentShape(Rectangle())
    }
}

#endif
