//
//  TimeText.swift
//  CoreApps
//

/// Times written as clocks write them.
public enum TimeText {

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// A stopwatch's time: "02:07.43", or "1:02:07.43" past an hour.
    public static func stopwatch(_ seconds: Double) -> String {
        let hundredths = Int((max(0, seconds) * 100).rounded(.down))
        let total = hundredths / 100
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        let fraction = two(hundredths % 100)
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(rest)).\(fraction)" : "\(two(minutes)):\(two(rest)).\(fraction)"
    }

    /// A timer's time left: "4:05", or "1:00:00". Part of a second counts
    /// as a whole one, so it shows 0:00 only when it's done.
    public static func countdown(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(rest))" : "\(minutes):\(two(rest))"
    }

    /// A time of day: "07:30" or "7:30 AM".
    public static func timeOfDay(hour: Int, minute: Int, uses24Hour: Bool) -> String {
        if uses24Hour { return "\(two(hour)):\(two(minute))" }
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):\(two(minute)) \(hour < 12 ? "AM" : "PM")"
    }

    /// How long until something, in words: "in 7 hours 5 minutes".
    public static func until(_ seconds: Double) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        if minutes < 1 { return "in less than a minute" }
        let days = minutes / 1440, hours = minutes % 1440 / 60, rest = minutes % 60
        var parts: [String] = []
        if days > 0 { parts.append(days == 1 ? "1 day" : "\(days) days") }
        if hours > 0 { parts.append(hours == 1 ? "1 hour" : "\(hours) hours") }
        if rest > 0, days == 0 { parts.append(rest == 1 ? "1 minute" : "\(rest) minutes") }
        return "in " + parts.joined(separator: " ")
    }

    /// The difference between two places' times, in words: "3 hours
    /// ahead", "5 hours 30 minutes behind", "Same time".
    public static func offset(_ seconds: Int) -> String {
        guard seconds != 0 else { return "Same time" }
        let minutes = abs(seconds) / 60
        let hours = minutes / 60, rest = minutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append(hours == 1 ? "1 hour" : "\(hours) hours") }
        if rest > 0 { parts.append(rest == 1 ? "1 minute" : "\(rest) minutes") }
        return parts.joined(separator: " ") + (seconds > 0 ? " ahead" : " behind")
    }

    /// Which day it is somewhere, beside here: "Today", "Tomorrow",
    /// "Yesterday".
    ///
    /// - Parameter difference: Its day of the year less here's; a year's
    ///   turn counts as a day.
    public static func day(_ difference: Int) -> String {
        switch difference {
        case 0: "Today"
        case 1, -364, -365: "Tomorrow"
        case -1, 364, 365: "Yesterday"
        default: difference > 0 ? "Tomorrow" : "Yesterday"
        }
    }

    /// A place's name from its time zone's: "New York" for
    /// "America/New_York", "Indianapolis" for
    /// "America/Indiana/Indianapolis".
    public static func city(_ identifier: String) -> String {
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// The region a time zone is in: "America" for "America/New_York".
    public static func region(_ identifier: String) -> String {
        let parts = identifier.split(separator: "/")
        return parts.count > 1 ? String(parts[0]).replacingOccurrences(of: "_", with: " ") : ""
    }
}

extension String {

    /// The text with every run of one string replaced by another, without
    /// Foundation.
    func replacingOccurrences(of target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }
        return split(separator: Substring(target), omittingEmptySubsequences: false).joined(separator: replacement)
    }
}
