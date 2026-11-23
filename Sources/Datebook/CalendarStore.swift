//
//  CalendarStore.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CalendarCore
import Foundation
#if Apple
import UniformTypeIdentifiers
#endif

/// What the calendar keeps.
private struct Saved: Codable {
    var calendars: [CalendarInfo]
    var events: [Event]
}

/// The calendars and their events, and the alerts that come due while the
/// app is open.
@MainActor
final class CalendarStore: ObservableObject {

    @Published private(set) var calendars: [CalendarInfo]

    @Published private(set) var events: [Event]

    /// Alerts that came due, the first shown.
    @Published var dueAlerts: [Occurrence] = []

    /// Why the calendar couldn't be read or written.
    @Published var failure: String?

    /// The day weeks start on, from 0 for Sunday, as the locale has it.
    let firstWeekday = Foundation.Calendar.current.firstWeekday - 1

    let uses24Hour: Bool

    let file: URL

    /// When alerts were last looked for.
    private var lastCheck: DateTime

    init() {
        file = Self.folder().appendingPathComponent("calendar.json")
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        uses24Hour = !format.contains("a")
        lastCheck = Self.dateTime(Date())
        if let data = try? Data(contentsOf: file) {
            do {
                let saved = try JSONDecoder().decode(Saved.self, from: data)
                calendars = saved.calendars.isEmpty ? CalendarInfo.defaults : saved.calendars
                events = saved.events
                return
            } catch {
                failure = "The calendar couldn't be read: \(error.localizedDescription)"
            }
        }
        calendars = CalendarInfo.defaults
        events = []
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
        return base.appendingPathComponent("calendar", isDirectory: true)
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(Saved(calendars: calendars, events: events))
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
        } catch {
            failure = "The calendar couldn't be saved: \(error.localizedDescription)"
        }
    }

    // MARK: Time

    /// A moment on the local clock.
    nonisolated static func dateTime(_ date: Date, in zone: TimeZone = .current) -> DateTime {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return DateTime(
            date: CivilDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1),
            hour: parts.hour ?? 0, minute: parts.minute ?? 0
        )
    }

    /// The moment a time on a clock is.
    nonisolated static func date(_ time: DateTime, in zone: TimeZone = .current) -> Date {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = DateComponents(year: time.date.year, month: time.date.month, day: time.date.day, hour: time.hour, minute: time.minute % 60)
        return calendar.date(from: parts) ?? Date()
    }

    /// An iCalendar time on the local clock. A zone the system doesn't
    /// know is taken for the local one.
    nonisolated static func toLocal(_ time: ICalendarTime) -> DateTime {
        switch time {
        case let .date(day): DateTime(date: day)
        case let .floating(time): time
        case let .utc(time): dateTime(date(time, in: TimeZone(identifier: "UTC")!))
        case let .zoned(time, zone): dateTime(date(time, in: TimeZone(identifier: zone) ?? .current))
        }
    }

    nonisolated static func toUTC(_ time: DateTime) -> DateTime {
        dateTime(date(time), in: TimeZone(identifier: "UTC")!)
    }

    var now: DateTime { Self.dateTime(Date()) }

    var today: CivilDate { now.date }

    // MARK: Calendars

    func calendar(id: String) -> CalendarInfo? {
        calendars.first { $0.id == id }
    }

    func setShown(_ isShown: Bool, _ calendar: CalendarInfo) {
        guard let index = calendars.firstIndex(where: { $0.id == calendar.id }) else { return }
        calendars[index].isShown = isShown
        save()
    }

    func addCalendar(named name: String) {
        let used = Set(calendars.map(\.color))
        let color = (0..<8).first { !used.contains($0) } ?? calendars.count % 8
        calendars.append(CalendarInfo(name: name, color: color))
        save()
    }

    /// Removes a calendar and its events. The last calendar stays.
    func deleteCalendar(_ calendar: CalendarInfo) {
        guard calendars.count > 1 else { return }
        calendars.removeAll { $0.id == calendar.id }
        events.removeAll { $0.calendarID == calendar.id }
        save()
    }

    /// The events on calendars that are shown.
    var shownEvents: [Event] {
        let shown = Set(calendars.filter(\.isShown).map(\.id))
        return events.filter { shown.contains($0.calendarID) }
    }

    // MARK: Events

    func event(id: String) -> Event? {
        events.first { $0.id == id }
    }

    /// Adds an event, or replaces the one with its id.
    func save(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        save()
    }

    func delete(_ event: Event) {
        events.removeAll { $0.id == event.id }
        save()
    }

    /// Takes one day out of a repeating event.
    func deleteOccurrence(of event: Event, on day: CivilDate) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].exceptions.insert(day)
        save()
    }

    /// The shown events' occurrences each day from `first` through `last`.
    func days(from first: CivilDate, through last: CivilDate) -> [CivilDate: [Occurrence]] {
        Agenda.days(shownEvents, from: first, through: last)
    }

    // MARK: Files

    /// Imports the events in an iCalendar file onto a calendar, and says
    /// how many.
    func importEvents(from url: URL, into calendarID: String) -> String {
        #if canImport(Darwin)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        #endif
        guard let data = try? Data(contentsOf: url) else {
            return "“\(url.lastPathComponent)” couldn't be read."
        }
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let imported = ICalendar.parse(text, calendarID: calendarID, toLocal: Self.toLocal)
        guard !imported.isEmpty else { return "“\(url.lastPathComponent)” has no events in it." }
        var added = 0
        for event in imported {
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                var updated = event
                updated.calendarID = events[index].calendarID
                events[index] = updated
            } else {
                events.append(event)
                added += 1
            }
        }
        save()
        let updated = imported.count - added
        var parts: [String] = []
        if added > 0 { parts.append(added == 1 ? "Added 1 event" : "Added \(added) events") }
        if updated > 0 { parts.append(updated == 1 ? "updated 1 already here" : "updated \(updated) already here") }
        let sentence = parts.joined(separator: " and ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    /// The events as an iCalendar file.
    func exportText(_ events: [Event]? = nil) -> String {
        ICalendar.write(events ?? self.events, stamp: Self.dateTime(Date(), in: TimeZone(identifier: "UTC")!), toUTC: Self.toUTC)
    }

    // MARK: Alerts

    /// Looks for alerts come due since the last look.
    func checkAlerts() {
        let now = self.now
        let due = Agenda.alerts(shownEvents, after: lastCheck, upTo: now)
        dueAlerts += due
        lastCheck = now
    }

    func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            checkAlerts()
        }
    }
}

/// Events as an iCalendar file, for exporting.
struct ICalendarDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.iCalendarFile] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

extension UTType {

    /// iCalendar files, `.ics`.
    static var iCalendarFile: UTType {
        #if Apple
        .calendarEvent
        #else
        UTType(exportedAs: "public.calendar-event")
        #endif
    }

    /// Tells Cacao's file dialogs what iCalendar files are called.
    static func declareICalendar() {
        // Only Cacao's own UTType, on Linux, is told: on a Mac, Cacao's is
        // Apple's, which knows the extension already.
        #if Native && !canImport(UniformTypeIdentifiers)
        UTType.declareFilenameExtension("ics", for: .iCalendarFile)
        #endif
    }
}

#endif
