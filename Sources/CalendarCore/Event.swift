//
//  Event.swift
//  CoreApps
//

/// Something on the calendar, at times on the local clock.
public struct Event: Identifiable, Hashable, Codable, Sendable {

    /// The iCalendar UID, kept across imports and exports.
    public var id: String

    public var title: String

    public var location: String = ""

    public var notes: String = ""

    /// The calendar it's on, by its id.
    public var calendarID: String

    public var start: DateTime

    /// When it ends. For an all-day event, midnight after its last day.
    public var end: DateTime

    public var isAllDay: Bool = false

    public var recurrence: Recurrence?

    /// The days a repeating event doesn't happen on after all.
    public var exceptions: Set<CivilDate> = []

    /// Minutes before the start to remind, if at all.
    public var alert: Int?

    public init(
        id: String = Identifier.make(), title: String, calendarID: String, start: DateTime, end: DateTime,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.calendarID = calendarID
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    /// How long each occurrence lasts, in minutes.
    public var duration: Int {
        max(0, start.minutes(to: end))
    }

    /// The times it happens that overlap `from` up to `to`, in order.
    public func occurrences(from: DateTime, to: DateTime) -> [Occurrence] {
        let length = duration
        func overlaps(_ start: DateTime) -> Bool {
            let end = start.adding(minutes: length)
            return start < to && (end > from || (length == 0 && start >= from))
        }
        guard let recurrence else {
            return overlaps(start) ? [Occurrence(event: self, start: start, end: end)] : []
        }
        // An occurrence that starts before `from` may last into it.
        let lastDay = to.date
        return recurrence.dates(from: start.date, through: lastDay)
            .filter { !exceptions.contains($0) }
            .map { DateTime(date: $0, minute: start.minute) }
            .filter(overlaps)
            .map { Occurrence(event: self, start: $0, end: $0.adding(minutes: length)) }
    }

    /// Whether the event has nothing worth keeping.
    public var isEmpty: Bool {
        title.trimmed.isEmpty && location.trimmed.isEmpty && notes.trimmed.isEmpty
    }

    /// The title, or a stand-in for an event without one.
    public var displayTitle: String {
        title.trimmed.isEmpty ? "New Event" : title
    }
}

/// One time an event happens.
public struct Occurrence: Identifiable, Hashable, Sendable {

    public var event: Event

    public var start: DateTime

    public var end: DateTime

    public init(event: Event, start: DateTime, end: DateTime) {
        self.event = event
        self.start = start
        self.end = end
    }

    public var id: String { "\(event.id)@\(start.minutesSince1970)" }

    /// The days it covers: one for most, several for an event across
    /// midnight. An all-day event's end is the midnight after its last day.
    public var days: [CivilDate] {
        let last = end > start && end.minute == 0 ? end.date.adding(days: -1) : end.date
        let count = max(0, start.date.days(to: max(last, start.date)))
        return (0...count).map { start.date.adding(days: $0) }
    }
}

/// A calendar events go on: Home, Work.
public struct CalendarInfo: Identifiable, Hashable, Codable, Sendable {

    public var id: String

    public var name: String

    /// Which of the app's colors.
    public var color: Int

    public var isShown: Bool = true

    public init(id: String = Identifier.make(), name: String, color: Int) {
        self.id = id
        self.name = name
        self.color = color
    }

    /// The calendars a new user starts with.
    public static let defaults = [
        CalendarInfo(id: "home", name: "Home", color: 0),
        CalendarInfo(id: "work", name: "Work", color: 4),
    ]
}

/// Laying events out by day and month.
public enum Agenda {

    /// The occurrences of the events on each day from `first` through
    /// `last`, each day's all-day events first, then by start.
    public static func days(_ events: [Event], from first: CivilDate, through last: CivilDate) -> [CivilDate: [Occurrence]] {
        let from = DateTime(date: first)
        let to = DateTime(date: last.adding(days: 1))
        var days: [CivilDate: [Occurrence]] = [:]
        for event in events {
            for occurrence in event.occurrences(from: from, to: to) {
                for day in occurrence.days where day >= first && day <= last {
                    days[day, default: []].append(occurrence)
                }
            }
        }
        for (day, occurrences) in days {
            days[day] = sorted(occurrences)
        }
        return days
    }

    /// All-day events first, then by start, then by title.
    public static func sorted(_ occurrences: [Occurrence]) -> [Occurrence] {
        occurrences.sorted { lhs, rhs in
            if lhs.event.isAllDay != rhs.event.isAllDay { return lhs.event.isAllDay }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.event.title < rhs.event.title
        }
    }

    /// The weeks of a month's grid, each of seven days, starting on
    /// `firstWeekday` (0 for Sunday): from the week with the 1st to the
    /// week with the last day.
    public static func weeks(of month: CivilDate, firstWeekday: Int) -> [[CivilDate]] {
        let first = month.startOfMonth
        let last = first.adding(days: CivilDate.days(inMonth: first.month, year: first.year) - 1)
        var start = first.startOfWeek(firstWeekday: firstWeekday)
        var weeks: [[CivilDate]] = []
        while start <= last {
            weeks.append((0..<7).map { start.adding(days: $0) })
            start = start.adding(days: 7)
        }
        return weeks
    }

    /// The occurrences whose alerts come due after `after` and up to
    /// `now`, by the moment each alert is due.
    public static func alerts(_ events: [Event], after: DateTime, upTo now: DateTime) -> [Occurrence] {
        guard now > after else { return [] }
        // Alerts are at most a week before an event.
        let horizon = now.adding(minutes: 7 * 1440 + 1)
        return events.flatMap { event -> [Occurrence] in
            guard let alert = event.alert else { return [] }
            return event.occurrences(from: after.adding(minutes: -event.duration), to: horizon).filter { occurrence in
                let due = occurrence.start.adding(minutes: -alert)
                return due > after && due <= now
            }
        }
        .sorted { $0.start < $1.start }
    }
}

/// Makes the ids of new events: random, in the form of a UUID.
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

    /// The string without spaces and newlines at either end.
    var trimmed: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
