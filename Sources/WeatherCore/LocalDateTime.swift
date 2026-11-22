//
//  LocalDateTime.swift
//  CoreApps
//

/// A time on a place's own clock, as Open-Meteo writes it:
/// `2026-11-22T20:30`, or a day alone, `2026-11-22`.
public struct LocalDateTime: Equatable, Hashable, Comparable, Codable, Sendable {

    public var year: Int

    public var month: Int

    public var day: Int

    public var hour: Int

    public var minute: Int

    public init(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    /// Reads `YYYY-MM-DD`, with `THH:MM` after it or not.
    public init?(_ text: String) {
        let parts = text.split(separator: "T", maxSplits: 1)
        guard let date = parts.first else { return nil }
        let days = date.split(separator: "-").compactMap { Int($0) }
        guard days.count == 3 else { return nil }
        var hour = 0
        var minute = 0
        if parts.count == 2 {
            let times = parts[1].split(separator: ":").compactMap { Int($0) }
            guard times.count >= 2 else { return nil }
            hour = times[0]
            minute = times[1]
        }
        guard (1...12).contains(days[1]), (1...31).contains(days[2]), (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        self.init(year: days[0], month: days[1], day: days[2], hour: hour, minute: minute)
    }

    /// The time on a clock `offset` seconds ahead of UTC, at a moment given
    /// in seconds since 1970.
    public init(secondsSince1970 seconds: Int, offset: Int = 0) {
        let local = seconds + offset
        let days = local >= 0 ? local / 86_400 : (local - 86_399) / 86_400
        let secondsIntoDay = local - days * 86_400
        let (year, month, day) = Self.civil(fromDays: days)
        self.init(year: year, month: month, day: day, hour: secondsIntoDay / 3600, minute: secondsIntoDay % 3600 / 60)
    }

    /// The same day at midnight.
    public var startOfDay: LocalDateTime {
        LocalDateTime(year: year, month: month, day: day)
    }

    /// Days since 1970-01-01.
    public var daysSince1970: Int {
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// Minutes since 1970-01-01, on this clock.
    public var minutesSince1970: Int {
        daysSince1970 * 1440 + hour * 60 + minute
    }

    /// The day of the week, from 0 for Sunday.
    public var weekday: Int {
        let days = daysSince1970
        // 1970-01-01 was a Thursday.
        return ((days + 4) % 7 + 7) % 7
    }

    public static func < (lhs: LocalDateTime, rhs: LocalDateTime) -> Bool {
        lhs.minutesSince1970 < rhs.minutesSince1970
    }

    private static func civil(fromDays days: Int) -> (Int, Int, Int) {
        // Howard Hinnant's civil_from_days.
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let mp = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }

    // Stored as Open-Meteo writes it.

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let time = LocalDateTime(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a local time: \(text)"))
        }
        self = time
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension LocalDateTime: CustomStringConvertible {

    public var description: String {
        "\(Self.pad(year, 4))-\(Self.pad(month))-\(Self.pad(day))T\(Self.pad(hour)):\(Self.pad(minute))"
    }

    private static func pad(_ value: Int, _ width: Int = 2) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
