//
//  CameraControls.swift
//  CoreApps
//

/// The zoom buttons: the factors a camera's range reaches, as a phone's
/// camera offers them.
public enum ZoomLevels {

    static let candidates: [Double] = [0.5, 1, 2, 3, 5, 10]

    /// The candidates in `lower...upper`, which always has 1. A range of 1
    /// alone has no buttons.
    public static func presets(lower: Double, upper: Double) -> [Double] {
        let presets = candidates.filter { $0 >= lower - 0.001 && $0 <= upper + 0.001 }
        return presets.count > 1 ? presets : []
    }

    /// The preset a button shows as on: the largest at or below `factor`.
    public static func current(_ factor: Double, in presets: [Double]) -> Double? {
        presets.last { $0 <= factor + 0.001 } ?? presets.first
    }

    /// A factor as people read it: `0.5×`, `1×`, `2.4×`.
    public static func label(_ factor: Double) -> String {
        let tenths = Int((factor * 10).rounded())
        let whole = tenths / 10, fraction = tenths % 10
        let number = fraction == 0 ? String(whole) : String(whole) + "." + String(fraction)
        return number + "×"
    }
}

/// How long a recording has run: `0:07`, `12:30`, `1:02:03`.
public enum RecordingTime {

    public static func format(_ seconds: Double) -> String {
        let total = seconds.isFinite && seconds > 0 ? Int(seconds) : 0
        let hours = total / 3600, minutes = total / 60 % 60, secs = total % 60
        func two(_ value: Int) -> String { value < 10 ? "0" + String(value) : String(value) }
        if hours > 0 {
            return String(hours) + ":" + two(minutes) + ":" + two(secs)
        }
        return String(minutes) + ":" + two(secs)
    }
}

/// The flash button: off, automatic, then on.
public enum FlashSetting: CaseIterable, Sendable {

    case off
    case auto
    case on

    /// The next setting, as the button steps through them.
    public var next: FlashSetting {
        switch self {
        case .off: .auto
        case .auto: .on
        case .on: .off
        }
    }

    public var symbol: String {
        switch self {
        case .off: "bolt.slash"
        case .auto, .on: "bolt"
        }
    }

    public var name: String {
        switch self {
        case .off: "Flash Off"
        case .auto: "Flash Auto"
        case .on: "Flash On"
        }
    }
}
