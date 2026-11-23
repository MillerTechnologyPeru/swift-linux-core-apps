//
//  PlaybackClock.swift
//  CoreApps
//

/// What the player's bar shows of where playing is: the time gone, the
/// time left, and where the scrubber sits.
public struct PlaybackClock: Equatable, Sendable {

    /// Seconds into the video.
    public var position: Double

    /// How long the video is, in seconds; `nil` until it's known, and for
    /// a live stream.
    public var duration: Double?

    public init(position: Double, duration: Double?) {
        self.position = position
        self.duration = duration
    }

    /// Whether the video has a length a scrubber can span.
    public var isSeekable: Bool {
        guard let duration else { return false }
        return duration.isFinite && duration > 0
    }

    /// The position, kept within the video.
    public var clampedPosition: Double {
        Self.clamp(position, to: duration)
    }

    /// The scrubber's range: the video's length, or a second while it
    /// isn't known, so the slider has something to span.
    public var range: ClosedRange<Double> {
        0...(isSeekable ? duration! : 1)
    }

    /// The time gone, as the bar's left label shows it.
    public var elapsedText: String {
        Self.text(clampedPosition, longest: duration ?? clampedPosition)
    }

    /// The time left, after a minus sign, as the bar's right label shows
    /// it; "Live" for a stream with no end.
    public var remainingText: String {
        guard isSeekable, let duration else { return "Live" }
        return "-" + Self.text(duration - clampedPosition, longest: duration)
    }

    /// Where to seek to for a skip of `seconds`, forward or back.
    public func skipped(by seconds: Double) -> Double {
        Self.clamp(clampedPosition + seconds, to: duration)
    }

    /// `seconds`, at least 0 and at most `duration`, where that's known.
    public static func clamp(_ seconds: Double, to duration: Double?) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        guard let duration, duration.isFinite, duration > 0 else { return seconds }
        return seconds < duration ? seconds : duration
    }

    /// `seconds` as minutes and seconds, or hours, minutes and seconds:
    /// "0:07", "12:30", "1:02:03". With `longest` an hour or more, every
    /// time has its hours, so the two labels match ("0:00:07").
    public static func text(_ seconds: Double, longest: Double = 0) -> String {
        let total = seconds.isFinite && seconds > 0 ? Int(seconds) : 0
        let hours = total / 3600, minutes = total % 3600 / 60, rest = total % 60
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        let showsHours = hours > 0 || (longest.isFinite && longest >= 3600)
        return showsHours ? "\(hours):\(two(minutes)):\(two(rest))" : "\(minutes):\(two(rest))"
    }
}
