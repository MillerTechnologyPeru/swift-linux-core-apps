//
//  ICalendar.swift
//  CoreApps
//

/// A time as an iCalendar file gives it, before it's on the local clock.
public enum ICalendarTime: Hashable, Sendable {
    /// A day, for an all-day event.
    case date(CivilDate)
    /// A time on whatever clock the reader's on.
    case floating(DateTime)
    /// A time in UTC: `…Z`.
    case utc(DateTime)
    /// A time in a named zone: `TZID=Europe/London:…`.
    case zoned(DateTime, String)
}

/// Reads and writes events as iCalendar (RFC 5545) `.ics` text, as every
/// calendar exports.
///
/// Time zones need the system's zone data, which this module goes without:
/// the reader and writer take a function that puts a time on the local
/// clock, or takes it off.
public enum ICalendar {

    // MARK: Reading

    /// The events in iCalendar text, on the calendar given. `toLocal` puts
    /// a UTC or zoned time on the local clock.
    ///
    /// A changed occurrence of a repeating event (one with a
    /// `RECURRENCE-ID`) becomes an event of its own, and its day an
    /// exception to the repeating one.
    public static func parse(_ text: String, calendarID: String, toLocal: (ICalendarTime) -> DateTime) -> [Event] {
        var events: [Event] = []
        var overrides: [(uid: String, day: CivilDate, event: Event)] = []
        var properties: [Property]?
        var depth = 0
        for line in unfold(text) {
            guard let property = Property(line: line) else { continue }
            let value = property.value.uppercased()
            if property.name == "BEGIN" {
                if value == "VEVENT" { properties = []; depth = 0 } else if properties != nil { depth += 1 }
                if properties != nil, value != "VEVENT" { properties?.append(property) }
                continue
            }
            if property.name == "END" {
                if value == "VEVENT", depth == 0, let eventProperties = properties {
                    if let (event, recurrenceDay) = makeEvent(eventProperties, calendarID: calendarID, toLocal: toLocal) {
                        if let recurrenceDay {
                            overrides.append((event.id, recurrenceDay, event))
                        } else {
                            events.append(event)
                        }
                    }
                    properties = nil
                } else if properties != nil {
                    depth -= 1
                    properties?.append(property)
                }
                continue
            }
            properties?.append(property)
        }
        for override in overrides {
            var event = override.event
            if let index = events.firstIndex(where: { $0.id == override.uid }) {
                events[index].exceptions.insert(override.day)
            }
            event.id = "\(override.uid)-\(override.day.compact)"
            events.append(event)
        }
        return events
    }

    private static func makeEvent(
        _ properties: [Property], calendarID: String, toLocal: (ICalendarTime) -> DateTime
    ) -> (Event, CivilDate?)? {
        var id: String?
        var title = ""
        var location = ""
        var notes = ""
        var start: ICalendarTime?
        var end: ICalendarTime?
        var duration: Int?
        var rule: String?
        var exceptions: Set<CivilDate> = []
        var recurrenceDay: CivilDate?
        var alert: Int?
        var inAlarm = false
        for property in properties {
            if property.name == "BEGIN", property.value.uppercased() == "VALARM" { inAlarm = true; continue }
            if property.name == "END", property.value.uppercased() == "VALARM" { inAlarm = false; continue }
            if inAlarm {
                // The first alarm before the start; one at a fixed time is left out.
                if property.name == "TRIGGER", alert == nil, property.parameter("VALUE")?.uppercased() != "DATE-TIME",
                   let minutes = parseDuration(property.value), minutes <= 0 {
                    alert = -minutes
                }
                continue
            }
            switch property.name {
            case "UID": id = property.text
            case "SUMMARY": title = property.text
            case "LOCATION": location = property.text
            case "DESCRIPTION": notes = property.text
            case "DTSTART": start = time(property)
            case "DTEND": end = time(property)
            case "DURATION": duration = parseDuration(property.value)
            case "RRULE": rule = property.value
            case "EXDATE":
                for value in property.value.split(separator: ",") {
                    var single = property
                    single.value = String(value)
                    if let time = time(single) { exceptions.insert(localDate(time, toLocal)) }
                }
            case "RECURRENCE-ID":
                if let time = time(property) { recurrenceDay = localDate(time, toLocal) }
            default:
                break
            }
        }
        guard let start else { return nil }
        let isAllDay: Bool
        let localStart: DateTime
        if case let .date(day) = start {
            isAllDay = true
            localStart = DateTime(date: day)
        } else {
            isAllDay = false
            localStart = toLocal(start)
        }
        var localEnd: DateTime
        if let end {
            if case let .date(day) = end { localEnd = DateTime(date: day) } else { localEnd = toLocal(end) }
        } else if let duration {
            localEnd = localStart.adding(minutes: duration)
        } else {
            // An all-day event without an end lasts the day; a timed one, no time.
            localEnd = isAllDay ? localStart.adding(minutes: 1440) : localStart
        }
        if localEnd < localStart { localEnd = localStart }
        var event = Event(
            id: id ?? Identifier.make(), title: title, calendarID: calendarID,
            start: localStart, end: localEnd, isAllDay: isAllDay
        )
        event.location = location
        event.notes = notes
        event.recurrence = rule.flatMap(Recurrence.init(rule:))
        event.exceptions = exceptions
        event.alert = alert
        return (event, recurrenceDay)
    }

    private static func time(_ property: Property) -> ICalendarTime? {
        let value = property.value
        if property.parameter("VALUE")?.uppercased() == "DATE" || !value.contains("T") {
            return CivilDate(value.prefix(8)).map(ICalendarTime.date)
        }
        guard let time = DateTime(value) else { return nil }
        if value.uppercased().hasSuffix("Z") { return .utc(time) }
        if let zone = property.parameter("TZID") { return .zoned(time, zone) }
        return .floating(time)
    }

    private static func localDate(_ time: ICalendarTime, _ toLocal: (ICalendarTime) -> DateTime) -> CivilDate {
        if case let .date(day) = time { return day }
        return toLocal(time).date
    }

    /// Minutes in an iCalendar duration: `-PT15M`, `P1D`, `P1W`,
    /// `PT1H30M`. Seconds are dropped.
    public static func parseDuration(_ text: String) -> Int? {
        var text = Substring(text.uppercased())
        var sign = 1
        if text.first == "-" { sign = -1; text.removeFirst() } else if text.first == "+" { text.removeFirst() }
        guard text.first == "P" else { return nil }
        text.removeFirst()
        var minutes = 0
        var number = ""
        var inTime = false
        for character in text {
            if character.isNumber { number.append(character); continue }
            if character == "T" { inTime = true; continue }
            let value = Int(number) ?? 0
            number = ""
            switch (character, inTime) {
            case ("W", false): minutes += value * 7 * 1440
            case ("D", false): minutes += value * 1440
            case ("H", true): minutes += value * 60
            case ("M", true): minutes += value
            case ("S", true): break
            default: return nil
            }
        }
        return sign * minutes
    }

    // MARK: Writing

    /// The events as an iCalendar file. `toUTC` takes a local time off the
    /// local clock, so timed events are written in UTC; `stamp` is now, in
    /// UTC, for `DTSTAMP`.
    public static func write(_ events: [Event], stamp: DateTime, toUTC: (DateTime) -> DateTime) -> String {
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Swift Linux//Calendar//EN", "CALSCALE:GREGORIAN"]
        func utc(_ time: DateTime) -> String { toUTC(time).compact + "Z" }
        for event in events {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:" + escape(event.id))
            lines.append("DTSTAMP:" + stamp.compact + "Z")
            if event.isAllDay {
                lines.append("DTSTART;VALUE=DATE:" + event.start.date.compact)
                lines.append("DTEND;VALUE=DATE:" + event.end.date.compact)
            } else {
                lines.append("DTSTART:" + utc(event.start))
                lines.append("DTEND:" + utc(event.end))
            }
            lines.append("SUMMARY:" + escape(event.title))
            if !event.location.isEmpty { lines.append("LOCATION:" + escape(event.location)) }
            if !event.notes.isEmpty { lines.append("DESCRIPTION:" + escape(event.notes)) }
            if let recurrence = event.recurrence {
                // UNTIL takes the start's form, and covers the whole day.
                let until = recurrence.until.map { day in
                    event.isAllDay ? day.compact : utc(DateTime(date: day, minute: 1439))
                }
                lines.append("RRULE:" + recurrence.rule(until: until))
            }
            for day in event.exceptions.sorted() {
                if event.isAllDay {
                    lines.append("EXDATE;VALUE=DATE:" + day.compact)
                } else {
                    lines.append("EXDATE:" + utc(DateTime(date: day, minute: event.start.minute)))
                }
            }
            if let alert = event.alert {
                lines += [
                    "BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:" + escape(event.title),
                    "TRIGGER:" + (alert == 0 ? "PT0M" : "-PT\(alert)M"), "END:VALARM",
                ]
            }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: Lines

    struct Property {
        /// In capitals.
        var name: String
        var parameters: [(name: String, value: String)]
        /// As written, still escaped.
        var value: String

        init?(line: String) {
            var quoted = false
            var colon: String.Index?
            for index in line.indices {
                if line[index] == "\"" { quoted.toggle() }
                if line[index] == ":", !quoted { colon = index; break }
            }
            guard let colon else { return nil }
            value = String(line[line.index(after: colon)...])
            let head = line[..<colon].split(separator: ";", omittingEmptySubsequences: false)
            guard let first = head.first, !first.isEmpty else { return nil }
            name = first.uppercased()
            parameters = head.dropFirst().compactMap { parameter in
                guard let equals = parameter.firstIndex(of: "=") else { return nil }
                let value = parameter[parameter.index(after: equals)...].filter { $0 != "\"" }
                return (parameter[..<equals].uppercased(), String(value))
            }
        }

        func parameter(_ name: String) -> String? {
            parameters.first { $0.name == name }?.value
        }

        var text: String { ICalendar.unescape(value) }
    }

    static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for piece in text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            if let first = piece.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += piece.dropFirst()
            } else if !piece.isEmpty {
                lines.append(String(piece))
            }
        }
        return lines
    }

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
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

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
}
