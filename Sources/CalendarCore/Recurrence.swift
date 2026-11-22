//
//  Recurrence.swift
//  CoreApps
//

/// How an event repeats: the part of iCalendar's `RRULE` (RFC 5545) that
/// calendars use.
///
/// It handles `FREQ` (daily, weekly, monthly, yearly), `INTERVAL`, `COUNT`,
/// `UNTIL`, `BYDAY` (weekdays, and for months an ordinal: `2MO`, `-1FR`)
/// and `BYMONTHDAY`. Rules with other parts are read for these and the
/// rest ignored.
public struct Recurrence: Hashable, Codable, Sendable {

    public enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    /// A day of the week, and for a monthly rule which one in the month:
    /// 2 for the second, -1 for the last.
    public struct WeekdayRule: Hashable, Codable, Sendable {

        /// From 0 for Sunday.
        public var weekday: Int

        public var ordinal: Int?

        public init(weekday: Int, ordinal: Int? = nil) {
            self.weekday = weekday
            self.ordinal = ordinal
        }
    }

    public var frequency: Frequency

    public var interval: Int

    public var weekdays: [WeekdayRule]

    public var monthDays: [Int]

    /// How many times it happens in all, counting the first.
    public var count: Int?

    /// The last day it can happen on.
    public var until: CivilDate?

    public init(
        frequency: Frequency, interval: Int = 1, weekdays: [WeekdayRule] = [], monthDays: [Int] = [],
        count: Int? = nil, until: CivilDate? = nil
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.count = count
        self.until = until
    }

    static let dayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

    /// Reads a rule: `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE`.
    public init?(rule: String) {
        var parts: [String: String] = [:]
        for part in rule.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            parts[pair[0].uppercased()] = String(pair[1])
        }
        guard let frequency = parts["FREQ"].flatMap({ Frequency(rawValue: $0.uppercased()) }) else { return nil }
        let weekdays = (parts["BYDAY"] ?? "").split(separator: ",").compactMap { code -> WeekdayRule? in
            let text = code.uppercased()
            guard let weekday = Self.dayCodes.firstIndex(of: String(text.suffix(2))) else { return nil }
            let ordinal = Int(text.dropLast(2))
            return WeekdayRule(weekday: weekday, ordinal: ordinal)
        }
        let monthDays = (parts["BYMONTHDAY"] ?? "").split(separator: ",").compactMap { Int($0) }
        self.init(
            frequency: frequency,
            interval: parts["INTERVAL"].flatMap { Int($0) } ?? 1,
            weekdays: weekdays,
            monthDays: monthDays,
            count: parts["COUNT"].flatMap { Int($0) },
            until: parts["UNTIL"].flatMap { CivilDate($0.prefix(8)) }
        )
    }

    /// The rule as iCalendar writes it. `UNTIL` is written as the date's
    /// last moment, `until`, given in the form the event's start is.
    public func rule(until untilText: String? = nil) -> String {
        var parts = ["FREQ=\(frequency.rawValue)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        if !weekdays.isEmpty {
            parts.append("BYDAY=" + weekdays.map { rule in
                (rule.ordinal.map(String.init) ?? "") + Self.dayCodes[rule.weekday]
            }.joined(separator: ","))
        }
        if !monthDays.isEmpty { parts.append("BYMONTHDAY=" + monthDays.map(String.init).joined(separator: ",")) }
        if let count { parts.append("COUNT=\(count)") }
        if let until { parts.append("UNTIL=" + (untilText ?? until.compact)) }
        return parts.joined(separator: ";")
    }

    // MARK: Days

    /// The days the event happens on, from the first, in order, up to and
    /// including `last`. The first day is always one, as iCalendar has it.
    public func dates(from first: CivilDate, through last: CivilDate) -> [CivilDate] {
        var dates: [CivilDate] = []
        let end = min(last, until ?? last)
        var made = 0
        func add(_ date: CivilDate) -> Bool {
            guard date >= first else { return true }
            guard date <= end, count.map({ made < $0 }) ?? true else { return false }
            made += 1
            dates.append(date)
            return true
        }
        // A guard against rules that never land on a day.
        let limit = 20_000
        var step = 0
        switch frequency {
        case .daily:
            var date = first
            while step < limit, add(date) {
                date = date.adding(days: interval)
                step += 1
            }
        case .weekly:
            let days = (weekdays.isEmpty ? [first.weekday] : weekdays.map(\.weekday))
                // Weeks start on Monday, as iCalendar's do by default.
                .map { ($0 + 6) % 7 }
                .sorted()
            var monday = first.adding(days: -((first.weekday + 6) % 7))
            loop: while step < limit {
                for offset in Set(days).sorted() {
                    if !add(monday.adding(days: offset)) { break loop }
                }
                monday = monday.adding(days: 7 * interval)
                step += 1
            }
        case .monthly:
            var month = first.startOfMonth
            loop: while step < limit {
                for date in monthDates(in: month, first: first) {
                    if !add(date) { break loop }
                }
                month = month.adding(months: interval)
                step += 1
            }
        case .yearly:
            var year = first.year
            loop: while step < limit {
                // 29 February comes only in leap years.
                if first.day <= CivilDate.days(inMonth: first.month, year: year) {
                    if !add(CivilDate(year: year, month: first.month, day: first.day)) { break loop }
                }
                year += interval
                step += 1
            }
        }
        return dates
    }

    /// The days in a month a monthly rule lands on, in order.
    private func monthDates(in month: CivilDate, first: CivilDate) -> [CivilDate] {
        let length = CivilDate.days(inMonth: month.month, year: month.year)
        var days: [Int] = []
        if !weekdays.isEmpty {
            for rule in weekdays {
                let firstOfMonth = month.weekday
                let firstMatch = 1 + (rule.weekday - firstOfMonth + 7) % 7
                let matches = Array(stride(from: firstMatch, through: length, by: 7))
                if let ordinal = rule.ordinal {
                    let index = ordinal > 0 ? ordinal - 1 : matches.count + ordinal
                    if matches.indices.contains(index) { days.append(matches[index]) }
                } else {
                    days += matches
                }
            }
        } else if !monthDays.isEmpty {
            for day in monthDays {
                let resolved = day > 0 ? day : length + day + 1
                if (1...length).contains(resolved) { days.append(resolved) }
            }
        } else if first.day <= length {
            // A month without the day is skipped: the 31st only in long months.
            days.append(first.day)
        }
        return Set(days).sorted().map { CivilDate(year: month.year, month: month.month, day: $0) }
    }

    // MARK: Presets

    /// The repeats the event editor offers.
    public enum Preset: String, CaseIterable, Sendable {
        case never
        case daily
        case weekdays
        case weekly
        case biweekly
        case monthly
        case yearly

        public var title: String {
            switch self {
            case .never: "Never"
            case .daily: "Every Day"
            case .weekdays: "Every Weekday"
            case .weekly: "Every Week"
            case .biweekly: "Every 2 Weeks"
            case .monthly: "Every Month"
            case .yearly: "Every Year"
            }
        }

        /// The rule, for an event starting on `start`.
        public func recurrence(startingOn start: CivilDate) -> Recurrence? {
            switch self {
            case .never: nil
            case .daily: Recurrence(frequency: .daily)
            case .weekdays: Recurrence(frequency: .weekly, weekdays: (1...5).map { WeekdayRule(weekday: $0) })
            case .weekly: Recurrence(frequency: .weekly, weekdays: [WeekdayRule(weekday: start.weekday)])
            case .biweekly: Recurrence(frequency: .weekly, interval: 2, weekdays: [WeekdayRule(weekday: start.weekday)])
            case .monthly: Recurrence(frequency: .monthly)
            case .yearly: Recurrence(frequency: .yearly)
            }
        }
    }

    /// The preset this rule is, if it's one, leaving its end aside.
    public func preset(startingOn start: CivilDate) -> Preset? {
        var plain = self
        plain.count = nil
        plain.until = nil
        return Preset.allCases.first { $0.recurrence(startingOn: start) == plain }
    }

    // MARK: Text

    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let ordinals = [1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth", -1: "last", -2: "second to last"]

    /// The rule in words: `Every 2 weeks on Monday and Wednesday`.
    public var summary: String {
        let unit: String
        switch frequency {
        case .daily: unit = interval == 1 ? "Every day" : "Every \(interval) days"
        case .weekly: unit = interval == 1 ? "Every week" : "Every \(interval) weeks"
        case .monthly: unit = interval == 1 ? "Every month" : "Every \(interval) months"
        case .yearly: unit = interval == 1 ? "Every year" : "Every \(interval) years"
        }
        var text = unit
        if frequency == .weekly, Set(weekdays.map(\.weekday)) == Set(1...5), weekdays.count == 5, interval == 1 {
            text = "Every weekday"
        } else if !weekdays.isEmpty, frequency != .daily {
            let names = weekdays.map { rule -> String in
                let name = Self.weekdayNames[rule.weekday]
                if let ordinal = rule.ordinal, let word = Self.ordinals[ordinal] { return "the \(word) \(name)" }
                return name
            }
            text += " on " + Self.list(names)
        } else if !monthDays.isEmpty, frequency == .monthly {
            text += " on the " + Self.list(monthDays.map { $0 == -1 ? "last day" : Self.ordinalNumber($0) })
        }
        if let count {
            text += count == 1 ? ", once" : ", \(count) times"
        } else if let until {
            text += ", until \(CalendarText.mediumDate(until))"
        }
        return text
    }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
    }

    static func ordinalNumber(_ number: Int) -> String {
        let suffix: String
        switch (number % 100, number % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(number)\(suffix)"
    }
}
