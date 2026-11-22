//
//  Stopwatch.swift
//  CoreApps
//

/// A stopwatch: it runs, stops and runs on, and keeps laps.
///
/// Times are seconds on any steady clock, passed in, so that it can be
/// tested and drawn without a clock of its own.
public struct Stopwatch: Hashable, Codable, Sendable {

    /// The time run before the current start.
    private var banked = 0.0

    /// When it last started; `nil` while stopped.
    private var startedAt: Double?

    /// The lengths of the laps finished, first first.
    public private(set) var laps: [Double] = []

    /// Where the current lap began, as an elapsed time.
    private var lapStart = 0.0

    public init() { }

    public var isRunning: Bool { startedAt != nil }

    /// Whether it's back at zero.
    public var isReset: Bool { startedAt == nil && banked == 0 && laps.isEmpty }

    public func elapsed(at time: Double) -> Double {
        banked + (startedAt.map { max(0, time - $0) } ?? 0)
    }

    /// How long the current lap has run.
    public func currentLap(at time: Double) -> Double {
        elapsed(at: time) - lapStart
    }

    public mutating func start(at time: Double) {
        guard startedAt == nil else { return }
        startedAt = time
    }

    public mutating func stop(at time: Double) {
        guard startedAt != nil else { return }
        banked = elapsed(at: time)
        startedAt = nil
    }

    /// Ends the current lap and begins another.
    public mutating func lap(at time: Double) {
        guard isRunning else { return }
        let now = elapsed(at: time)
        laps.append(now - lapStart)
        lapStart = now
    }

    public mutating func reset() {
        self = Stopwatch()
    }

    /// The positions of the fastest and slowest laps, when there are two
    /// or more to tell apart.
    public var fastestLap: Int? {
        laps.count > 1 ? laps.indices.min { laps[$0] < laps[$1] } : nil
    }

    public var slowestLap: Int? {
        laps.count > 1 ? laps.indices.max { laps[$0] < laps[$1] } : nil
    }
}
