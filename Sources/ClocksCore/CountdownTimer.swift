//
//  CountdownTimer.swift
//  CoreApps
//

/// A timer counting down from a length of time.
public struct CountdownTimer: Hashable, Codable, Sendable {

    /// The length it was set for, in seconds.
    public private(set) var duration: Double

    /// The time left before the current run.
    private var remainingAtStart: Double

    /// When it last started counting; `nil` while paused or not started.
    private var startedAt: Double?

    /// Whether it's been started since it was set.
    public private(set) var isStarted = false

    public init(duration: Double = 0) {
        self.duration = max(0, duration)
        remainingAtStart = max(0, duration)
    }

    public var isRunning: Bool { startedAt != nil }

    public var isPaused: Bool { isStarted && startedAt == nil }

    public func remaining(at time: Double) -> Double {
        guard let startedAt else { return remainingAtStart }
        return max(0, remainingAtStart - (time - startedAt))
    }

    /// How much of it has gone, from 0 to 1.
    public func progress(at time: Double) -> Double {
        duration > 0 ? 1 - remaining(at: time) / duration : 0
    }

    /// Whether it has counted down to nothing.
    public func isFinished(at time: Double) -> Bool {
        isStarted && remaining(at: time) <= 0
    }

    /// Sets a new length, stopping it.
    public mutating func set(_ seconds: Double) {
        self = CountdownTimer(duration: seconds)
    }

    public mutating func start(at time: Double) {
        guard startedAt == nil, remainingAtStart > 0 else { return }
        startedAt = time
        isStarted = true
    }

    public mutating func pause(at time: Double) {
        guard startedAt != nil else { return }
        remainingAtStart = remaining(at: time)
        startedAt = nil
    }

    /// Back to the length it was set for, not counting.
    public mutating func cancel() {
        set(duration)
    }

    /// Adds time to it, as "+1 minute" does.
    public mutating func add(_ seconds: Double, at time: Double) {
        remainingAtStart = remaining(at: time) + seconds
        duration += seconds
        if startedAt != nil { startedAt = time }
    }
}
