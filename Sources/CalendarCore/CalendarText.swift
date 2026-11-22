//
//  CalendarText.swift
//  CoreApps
//

/// Dates, times and spans written out.
public enum CalendarText {

    public static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    public static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// `November 2026`.
    public static func month(_ date: CivilDate) -> String {
        "\(monthNames[date.month - 1]) \(date.year)"
    }

    /// `S`, `M`… for the month grid's header, from `firstWeekday` on.
    public static func weekdayInitials(firstWeekday: Int) -> [String] {
        (0..<7).map { String(weekdayNames[(firstWeekday + $0) % 7].prefix(1)) }
    }

    /// `Nov 22, 2026`.
    public static func mediumDate(_ date: CivilDate) -> String {
        "\(monthNames[date.month - 1].prefix(3)) \(date.day), \(date.year)"
    }

    /// `Sunday, November 22`, with the year when it isn't `today`'s.
    public static func longDate(_ date: CivilDate, today: CivilDate) -> String {
        var text = "\(weekdayNames[date.weekday]), \(monthNames[date.month - 1]) \(date.day)"
        if date.year != today.year { text += ", \(date.year)" }
        return text
    }

    /// `Today`, `Tomorrow`, `Yesterday`, or the long date.
    public static func relativeDate(_ date: CivilDate, today: CivilDate) -> String {
        switch today.days(to: date) {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: longDate(date, today: today)
        }
    }

    /// `9:30 AM`, or `09:30`.
    public static func time(_ time: DateTime, uses24Hour: Bool) -> String {
        let hour = time.hour
        let minute = time.minute % 60
        if uses24Hour { return "\(pad(hour)):\(pad(minute))" }
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):\(pad(minute)) \(hour < 12 ? "AM" : "PM")"
    }

    /// When an occurrence is, as its row in a day's list says it:
    /// `all-day`, `9:30 AM – 10:30 AM`, or for one that began on an
    /// earlier day or ends on a later one, `until 11:00 AM` or
    /// `from 10:00 PM`.
    public static func span(_ occurrence: Occurrence, on day: CivilDate, uses24Hour: Bool) -> String {
        if occurrence.event.isAllDay { return "all-day" }
        let startsToday = occurrence.start.date == day
        let endsToday = occurrence.end.date == day || (occurrence.end.date == day.adding(days: 1) && occurrence.end.minute == 0)
        switch (startsToday, endsToday) {
        case (true, true):
            if occurrence.end == occurrence.start { return time(occurrence.start, uses24Hour: uses24Hour) }
            return "\(time(occurrence.start, uses24Hour: uses24Hour)) – \(time(occurrence.end, uses24Hour: uses24Hour))"
        case (true, false):
            return "from \(time(occurrence.start, uses24Hour: uses24Hour))"
        case (false, true):
            return "until \(time(occurrence.end, uses24Hour: uses24Hour))"
        case (false, false):
            return "all-day"
        }
    }

    /// The whole of an occurrence's time, for its page:
    /// `Sunday, November 22 · 9:30 – 10:30 AM`.
    public static func fullSpan(_ occurrence: Occurrence, today: CivilDate, uses24Hour: Bool) -> [String] {
        let event = occurrence.event
        if event.isAllDay {
            let last = occurrence.end.date.adding(days: -1)
            if last <= occurrence.start.date { return [longDate(occurrence.start.date, today: today), "all-day"] }
            return ["from \(longDate(occurrence.start.date, today: today))", "to \(longDate(last, today: today))"]
        }
        if occurrence.start.date == occurrence.end.date || occurrence.end == DateTime(date: occurrence.start.date.adding(days: 1)) {
            return [
                longDate(occurrence.start.date, today: today),
                "\(time(occurrence.start, uses24Hour: uses24Hour)) – \(time(occurrence.end, uses24Hour: uses24Hour))",
            ]
        }
        return [
            "from \(time(occurrence.start, uses24Hour: uses24Hour)) \(longDate(occurrence.start.date, today: today))",
            "to \(time(occurrence.end, uses24Hour: uses24Hour)) \(longDate(occurrence.end.date, today: today))",
        ]
    }

    /// A span of minutes: `1 hr 30 min`, `2 days`.
    public static func duration(_ minutes: Int) -> String {
        if minutes >= 1440, minutes % 1440 == 0 {
            let days = minutes / 1440
            return days == 1 ? "1 day" : "\(days) days"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return hours == 1 ? "1 hr" : "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }

    /// The alerts the editor offers, in minutes before.
    public static let alertChoices = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10_080]

    /// `At time of event`, `15 minutes before`, `1 day before`.
    public static func alert(_ minutes: Int?) -> String {
        guard let minutes else { return "None" }
        switch minutes {
        case 0: return "At time of event"
        case 10_080: return "1 week before"
        case let days where days >= 1440 && days % 1440 == 0:
            return days == 1440 ? "1 day before" : "\(days / 1440) days before"
        case let hours where hours >= 60 && hours % 60 == 0:
            return hours == 60 ? "1 hour before" : "\(hours / 60) hours before"
        default:
            return minutes == 1 ? "1 minute before" : "\(minutes) minutes before"
        }
    }

    /// What an alert says when it comes: `Lunch is now`, `Lunch in 15
    /// minutes`, `Lunch tomorrow at 9:30 AM`.
    public static func reminder(_ occurrence: Occurrence, now: DateTime, uses24Hour: Bool) -> String {
        let title = occurrence.event.displayTitle
        let minutes = now.minutes(to: occurrence.start)
        if occurrence.event.isAllDay {
            return "\(title) \(relativeDate(occurrence.start.date, today: now.date).lowercased())"
        }
        if minutes <= 0 { return "\(title) is now" }
        if minutes < 60 { return minutes == 1 ? "\(title) in 1 minute" : "\(title) in \(minutes) minutes" }
        let day = relativeDate(occurrence.start.date, today: now.date)
        let when = day == "Today" ? "today" : day == "Tomorrow" ? "tomorrow" : "on \(day)"
        return "\(title) \(when) at \(time(occurrence.start, uses24Hour: uses24Hour))"
    }
}
