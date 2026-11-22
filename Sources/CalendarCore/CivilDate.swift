//
//  CivilDate.swift
//  CoreApps
//

/// A day on the calendar, with no time or time zone: 22 November 2026.
public struct CivilDate: Hashable, Comparable, Codable, Sendable {

    public var year: Int

    public var month: Int

    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `days` after 1 January 1970.
    public init(daysSince1970 days: Int) {
        // Howard Hinnant's civil_from_days.
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        day = dayOfYear - (153 * mp + 2) / 5 + 1
        month = mp < 10 ? mp + 3 : mp - 9
        year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
    }

    /// Reads `2026-11-22` or `20261122`.
    public init?(_ text: some StringProtocol) {
        let digits = String(text.filter(\.isNumber))
        guard digits.count == 8, text.count == 8 || text.count == 10,
              let year = Int(digits.prefix(4)),
              let month = Int(digits.dropFirst(4).prefix(2)),
              let day = Int(digits.suffix(2)),
              (1...12).contains(month), (1...Self.days(inMonth: month, year: year)).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Days since 1 January 1970.
    public var daysSince1970: Int {
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// The day of the week, from 0 for Sunday.
    public var weekday: Int {
        ((daysSince1970 + 4) % 7 + 7) % 7
    }

    public func adding(days: Int) -> CivilDate {
        CivilDate(daysSince1970: daysSince1970 + days)
    }

    /// The same day `months` later, or the month's last day when it's
    /// shorter: 31 January and a month is 28 or 29 February.
    public func adding(months: Int) -> CivilDate {
        let index = year * 12 + (month - 1) + months
        let year = index >= 0 ? index / 12 : (index - 11) / 12
        let month = index - year * 12 + 1
        return CivilDate(year: year, month: month, day: min(day, Self.days(inMonth: month, year: year)))
    }

    /// The days from this one to another: negative when it's before.
    public func days(to other: CivilDate) -> Int {
        other.daysSince1970 - daysSince1970
    }

    /// The first of the month.
    public var startOfMonth: CivilDate {
        CivilDate(year: year, month: month, day: 1)
    }

    /// The day of the week `firstWeekday` on or before this one, where a
    /// week starts.
    public func startOfWeek(firstWeekday: Int) -> CivilDate {
        adding(days: -((weekday - firstWeekday + 7) % 7))
    }

    public static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    public static func days(inMonth month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// `20261122`, as iCalendar writes a date.
    public var compact: String {
        pad(year, 4) + pad(month) + pad(day)
    }
}

extension CivilDate: CustomStringConvertible {

    /// `2026-11-22`.
    public var description: String {
        pad(year, 4) + "-" + pad(month) + "-" + pad(day)
    }
}

/// A moment on a local clock: a day and the minute into it.
public struct DateTime: Hashable, Comparable, Codable, Sendable {

    public var date: CivilDate

    /// Minutes since midnight, from 0 to 1439.
    public var minute: Int

    public init(date: CivilDate, minute: Int = 0) {
        self.date = date
        self.minute = minute
    }

    public init(date: CivilDate, hour: Int, minute: Int) {
        self.init(date: date, minute: hour * 60 + minute)
    }

    /// The moment `minutes` after midnight at the start of 1 January 1970.
    public init(minutesSince1970 minutes: Int) {
        let days = minutes >= 0 ? minutes / 1440 : (minutes - 1439) / 1440
        self.init(date: CivilDate(daysSince1970: days), minute: minutes - days * 1440)
    }

    /// Reads iCalendar's `20261122T093000`, with a `Z` after it or not.
    public init?(_ text: some StringProtocol) {
        let parts = text.split(separator: "T")
        guard parts.count == 2, let date = CivilDate(parts[0]) else { return nil }
        let time = String(parts[1].filter(\.isNumber))
        guard time.count >= 4, let hour = Int(time.prefix(2)), let minute = Int(time.dropFirst(2).prefix(2)),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        self.init(date: date, hour: hour, minute: minute)
    }

    public var hour: Int { minute / 60 }

    public var minutesSince1970: Int {
        date.daysSince1970 * 1440 + minute
    }

    public func adding(minutes: Int) -> DateTime {
        DateTime(minutesSince1970: minutesSince1970 + minutes)
    }

    public func minutes(to other: DateTime) -> Int {
        other.minutesSince1970 - minutesSince1970
    }

    public static func < (lhs: DateTime, rhs: DateTime) -> Bool {
        lhs.minutesSince1970 < rhs.minutesSince1970
    }

    /// `20261122T093000`, as iCalendar writes a local time.
    public var compact: String {
        date.compact + "T" + pad(hour) + pad(minute % 60) + "00"
    }
}

extension DateTime: CustomStringConvertible {

    public var description: String {
        "\(date) \(pad(hour)):\(pad(minute % 60))"
    }
}

func pad(_ value: Int, _ width: Int = 2) -> String {
    let text = String(value)
    return String(repeating: "0", count: max(0, width - text.count)) + text
}
