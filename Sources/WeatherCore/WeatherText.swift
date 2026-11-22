//
//  WeatherText.swift
//  CoreApps
//

/// The units the weather is shown in. Forecasts come in metric.
public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    /// °C, km/h, mm, hPa.
    case metric
    /// °F, mph, in, inHg.
    case us

    public var name: String {
        switch self {
        case .metric: "Celsius"
        case .us: "Fahrenheit"
        }
    }

    /// The system a region uses: Fahrenheit in the United States and the
    /// few places that keep it.
    public init(region: String?) {
        switch region?.uppercased() {
        case "US", "BS", "BZ", "KY", "PW", "LR", "FM", "MH": self = .us
        default: self = .metric
        }
    }
}

/// The weather written out.
public enum WeatherText {

    /// A temperature, rounded: `7°`.
    public static func temperature(_ celsius: Double, in units: UnitSystem) -> String {
        let value = units == .us ? celsius * 9 / 5 + 32 : celsius
        let rounded = Int(value.rounded())
        return "\(rounded)°"
    }

    /// A day's high and low: `H:9° L:3°`.
    public static func highLow(high: Double, low: Double, in units: UnitSystem) -> String {
        "H:\(temperature(high, in: units)) L:\(temperature(low, in: units))"
    }

    /// An hour of the hour-by-hour strip: `8 PM`, or `20` on a 24-hour clock.
    public static func hour(_ time: LocalDateTime, uses24Hour: Bool) -> String {
        if uses24Hour {
            return pad(time.hour)
        }
        return "\(twelveHour(time.hour)) \(time.hour < 12 ? "AM" : "PM")"
    }

    /// A time of day: `7:30 AM`, or `07:30`.
    public static func time(_ time: LocalDateTime, uses24Hour: Bool) -> String {
        if uses24Hour {
            return "\(pad(time.hour)):\(pad(time.minute))"
        }
        return "\(twelveHour(time.hour)):\(pad(time.minute)) \(time.hour < 12 ? "AM" : "PM")"
    }

    /// A day in the forecast: `Today`, or the day of the week, `Mon`.
    public static func day(_ date: LocalDateTime, today: LocalDateTime) -> String {
        if date.startOfDay == today.startOfDay { return "Today" }
        return weekdays[date.weekday]
    }

    static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// The direction wind blows from, on a 16-point compass: `NE`.
    public static func compass(_ degrees: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return points[Int((normalized / 22.5).rounded()) % 16]
    }

    /// The wind's speed: `9 km/h`, or `6 mph`.
    public static func windSpeed(_ kilometresPerHour: Double, in units: UnitSystem) -> String {
        switch units {
        case .metric: "\(Int(kilometresPerHour.rounded())) km/h"
        case .us: "\(Int((kilometresPerHour / 1.609_344).rounded())) mph"
        }
    }

    /// Rain and snow: `1.2 mm`, or `0.05 in`.
    public static func precipitation(_ millimetres: Double, in units: UnitSystem) -> String {
        switch units {
        case .metric: "\(decimal(millimetres, places: millimetres < 10 ? 1 : 0)) mm"
        case .us: "\(decimal(millimetres / 25.4, places: 2)) in"
        }
    }

    /// Air pressure at sea level: `1016 hPa`, or `30.00 inHg`.
    public static func pressure(_ hectopascals: Double, in units: UnitSystem) -> String {
        switch units {
        case .metric: "\(Int(hectopascals.rounded())) hPa"
        case .us: "\(decimal(hectopascals * 0.029_529_983, places: 2)) inHg"
        }
    }

    /// A share: `71%`.
    public static func percent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    /// How strong the sun is, by the UV index: `Low` to `Extreme`.
    public static func uvLevel(_ index: Double) -> String {
        switch Int(index.rounded()) {
        case ..<3: "Low"
        case 3...5: "Moderate"
        case 6...7: "High"
        case 8...10: "Very High"
        default: "Extreme"
        }
    }

    /// How the felt temperature compares with the real one.
    public static func feelsLike(_ apparent: Double, actual: Double) -> String {
        let difference = apparent - actual
        if difference <= -2 { return "Wind is making it feel colder." }
        if difference >= 2 { return "Humidity is making it feel warmer." }
        return "Similar to the actual temperature."
    }

    /// `value` with `places` digits after the point.
    public static func decimal(_ value: Double, places: Int) -> String {
        var scale = 1
        for _ in 0..<places { scale *= 10 }
        let scaled = Int((abs(value) * Double(scale)).rounded())
        let sign = value < 0 && scaled != 0 ? "-" : ""
        guard places > 0 else { return sign + String(scaled) }
        let fraction = String(scaled % scale)
        return sign + String(scaled / scale) + "." + String(repeating: "0", count: places - fraction.count) + fraction
    }

    private static func twelveHour(_ hour: Int) -> Int {
        hour % 12 == 0 ? 12 : hour % 12
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
