//
//  Alarm.swift
//  CoreApps
//

/// Days of the week, as a set.
public struct Weekdays: OptionSet, Hashable, Codable, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sunday = Weekdays(rawValue: 1 << 0)
    public static let monday = Weekdays(rawValue: 1 << 1)
    public static let tuesday = Weekdays(rawValue: 1 << 2)
    public static let wednesday = Weekdays(rawValue: 1 << 3)
    public static let thursday = Weekdays(rawValue: 1 << 4)
    public static let friday = Weekdays(rawValue: 1 << 5)
    public static let saturday = Weekdays(rawValue: 1 << 6)

    public static let weekdays: Weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let weekend: Weekdays = [.saturday, .sunday]
    public static let everyDay: Weekdays = [.weekdays, .weekend]

    /// The day of a weekday's number, Sunday being 0.
    public init(day: Int) {
        self.init(rawValue: 1 << ((day % 7 + 7) % 7))
    }

    /// The days in order from Sunday, with their short names.
    public static let all: [(day: Weekdays, name: String)] = [
        (.sunday, "Sun"), (.monday, "Mon"), (.tuesday, "Tue"), (.wednesday, "Wed"),
        (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat"),
    ]

    /// The days in words, as an alarm's row has them.
    public var summary: String {
        switch self {
        case []: "Never"
        case .everyDay: "Every day"
        case .weekdays: "Weekdays"
        case .weekend: "Weekends"
        default: Self.all.filter { contains($0.day) }.map(\.name).joined(separator: " ")
        }
    }
}

/// A moment in local time, as alarms need it: the day of the week, and
/// how far into the day.
public struct LocalTime: Hashable, Sendable {

    /// Sunday is 0, Saturday 6.
    public var weekday: Int

    /// Seconds since midnight.
    public var secondsIntoDay: Double

    public init(weekday: Int, secondsIntoDay: Double) {
        self.weekday = weekday
        self.secondsIntoDay = secondsIntoDay
    }

    public init(weekday: Int, hour: Int, minute: Int, second: Double = 0) {
        self.init(weekday: weekday, secondsIntoDay: Double(hour * 3600 + minute * 60) + second)
    }
}

/// A time of day to be woken at, perhaps again on some days of the week.
public struct Alarm: Identifiable, Hashable, Codable, Sendable {

    public var id: String

    public var hour: Int

    public var minute: Int

    public var label: String

    /// The days it goes off again; none for an alarm that goes off once.
    public var days: Weekdays

    public var isEnabled: Bool

    public init(id: String, hour: Int, minute: Int, label: String = "", days: Weekdays = [], isEnabled: Bool = true) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.days = days
        self.isEnabled = isEnabled
    }

    /// How long snoozing puts an alarm off, in minutes.
    public static let snoozeMinutes = 9

    /// The label, or what an alarm without one is called.
    public var title: String {
        label.isEmpty ? "Alarm" : label
    }

    /// Seconds from a moment until the alarm next goes off, or `nil` if
    /// it's off. An alarm due at the very moment counts as gone off.
    public func secondsUntilNext(from now: LocalTime) -> Double? {
        guard isEnabled else { return nil }
        let target = Double(hour * 3600 + minute * 60)
        let day = 86_400.0
        for ahead in 0...7 {
            let weekday = (now.weekday + ahead) % 7
            guard days.isEmpty || days.contains(Weekdays(day: weekday)) else { continue }
            let wait = Double(ahead) * day + target - now.secondsIntoDay
            if wait > 0 { return wait }
        }
        return nil
    }

    /// Whether the alarm went off between two moments: after the first,
    /// and at or before the second.
    public func goesOff(after earlier: LocalTime, until later: LocalTime) -> Bool {
        guard let wait = secondsUntilNext(from: earlier) else { return false }
        var span = later.secondsIntoDay - earlier.secondsIntoDay
        span += Double(((later.weekday - earlier.weekday) % 7 + 7) % 7) * 86_400
        return wait <= span
    }
}
