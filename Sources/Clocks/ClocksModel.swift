//
//  ClocksModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ClocksCore
import Foundation

/// What's ringing.
enum Ringing: Equatable {
    case alarm(Alarm)
    case timer

    var title: String {
        switch self {
        case let .alarm(alarm): alarm.title
        case .timer: "Timer"
        }
    }
}

/// What the clocks keep between launches.
private struct Saved: Codable {
    var cities: [String]
    var alarms: [Alarm]
    var uses24Hour: Bool?
}

/// The places shown, the alarms, the stopwatch and the timer, and whatever
/// is ringing.
@MainActor
final class ClocksModel: ObservableObject {

    /// The time zones of the places shown, by their identifiers.
    @Published var cities: [String] { didSet { save() } }

    @Published var alarms: [Alarm] { didSet { save() } }

    @Published var uses24Hour: Bool { didSet { save() } }

    @Published var stopwatch = Stopwatch()

    @Published var timer = CountdownTimer(duration: 5 * 60)

    @Published private(set) var ringing: Ringing?

    /// When a snoozed alarm rings again, on the steady clock.
    private var snoozedUntil: (alarm: Alarm, time: Double)?

    /// The local time last looked at, for telling which alarms passed.
    private var lastCheck: LocalTime

    private let chime = ChimePlayer()

    private let file: URL

    /// Seconds on a steady clock, which the stopwatch and timer go by.
    static var now: Double {
        ProcessInfo.processInfo.systemUptime
    }

    init() {
        file = Self.storeURL()
        let saved = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        cities = saved?.cities ?? Self.defaultCities
        alarms = saved?.alarms ?? []
        uses24Hour = saved?.uses24Hour ?? Self.localeUses24Hour
        lastCheck = Self.localTime()
    }

    // MARK: Keeping

    private static let defaultCities = ["America/Los_Angeles", "America/New_York", "Europe/London", "Asia/Tokyo"]

    /// Where the clocks keep what they keep: the configuration folder on
    /// Linux, Application Support on Apple's systems.
    private static func storeURL() -> URL {
        #if canImport(Darwin)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        var base = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(".config", isDirectory: true)
        if let path = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], path.hasPrefix("/") {
            base = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        return base.appendingPathComponent("clocks", isDirectory: true).appendingPathComponent("clocks.json")
    }

    private func save() {
        let saved = Saved(cities: cities, alarms: alarms, uses24Hour: uses24Hour)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    /// Whether the user's locale writes times on a 24-hour clock.
    private static var localeUses24Hour: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return !format.contains("a")
    }

    // MARK: Time

    /// A moment as alarms see it: here, by the day of the week.
    static func localTime(_ date: Date = Date()) -> LocalTime {
        let parts = Calendar.current.dateComponents([.weekday, .hour, .minute, .second, .nanosecond], from: date)
        let second = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        return LocalTime(weekday: (parts.weekday ?? 1) - 1, hour: parts.hour ?? 0, minute: parts.minute ?? 0, second: second)
    }

    /// The alarm that goes off next, and how long until it does.
    var nextAlarm: (alarm: Alarm, seconds: Double)? {
        let now = Self.localTime()
        return alarms
            .compactMap { alarm in alarm.secondsUntilNext(from: now).map { (alarm, $0) } }
            .min { $0.1 < $1.1 }
    }

    // MARK: Alarms

    func add(_ alarm: Alarm) {
        alarms.append(alarm)
        sortAlarms()
    }

    func update(_ alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return add(alarm) }
        alarms[index] = alarm
        sortAlarms()
    }

    func delete(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
    }

    func setEnabled(_ isEnabled: Bool, for alarm: Alarm) {
        guard let index = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[index].isEnabled = isEnabled
    }

    private func sortAlarms() {
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    // MARK: Ringing

    /// Looks at the time: called a few times a second while open.
    func tick() {
        let now = Self.localTime()
        let steady = Self.now
        if ringing == nil {
            if timer.isRunning, timer.isFinished(at: steady) {
                timer.pause(at: steady)
                ring(.timer)
            } else if let snoozed = snoozedUntil, steady >= snoozed.time {
                snoozedUntil = nil
                ring(.alarm(snoozed.alarm))
            } else if let alarm = alarms.first(where: { $0.goesOff(after: lastCheck, until: now) }) {
                // An alarm for once turns itself off.
                if alarm.days.isEmpty { setEnabled(false, for: alarm) }
                ring(.alarm(alarm))
            }
        }
        lastCheck = now
        chime.refill()
    }

    func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000)
            tick()
        }
    }

    private func ring(_ what: Ringing) {
        ringing = what
        chime.start()
    }

    /// Stops what's ringing. A timer goes back to its length.
    func stopRinging() {
        if ringing == .timer { timer.cancel() }
        ringing = nil
        chime.stop()
    }

    /// Puts the ringing alarm off for a few minutes.
    func snooze() {
        guard case let .alarm(alarm) = ringing else { return stopRinging() }
        snoozedUntil = (alarm, Self.now + Double(Alarm.snoozeMinutes * 60))
        ringing = nil
        chime.stop()
    }
}

#endif
