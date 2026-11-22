//
//  MapsText.swift
//  CoreApps
//

/// Distances, times and directions written out.
public enum MapsText {

    /// A distance: `350 m`, `1.2 km`, `12 km`; or in miles and feet:
    /// `500 ft`, `0.3 mi`, `12 mi`.
    public static func distance(_ metres: Double, usesMiles: Bool) -> String {
        if usesMiles {
            let miles = metres / 1609.344
            if miles < 0.1 { return "\(rounded(metres * 3.280_84, to: 50)) ft" }
            return miles < 10 ? "\(decimal(miles)) mi" : "\(Int(miles.rounded())) mi"
        }
        if metres < 1000 { return "\(rounded(metres, to: metres < 100 ? 10 : 50)) m" }
        let kilometres = metres / 1000
        return kilometres < 10 ? "\(decimal(kilometres)) km" : "\(Int(kilometres.rounded())) km"
    }

    /// A travel time: `5 min`, `1 hr 20 min`.
    public static func duration(_ seconds: Double) -> String {
        let minutes = max(1, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) hr" : "\(hours) hr \(rest) min"
    }

    /// A bearing as a direction: `north`, `southeast`.
    public static func cardinal(_ degrees: Double) -> String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return names[Int((normalized / 45).rounded()) % 8]
    }

    /// `1st`, `2nd`, `3rd`, `4th`.
    public static func ordinal(_ number: Int) -> String {
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

    /// A coordinate: `51.5194° N, 0.1270° W`.
    public static func coordinate(_ coordinate: Coordinate) -> String {
        let latitude = "\(decimal(abs(coordinate.latitude), places: 4))° \(coordinate.latitude < 0 ? "S" : "N")"
        let longitude = "\(decimal(abs(coordinate.longitude), places: 4))° \(coordinate.longitude < 0 ? "W" : "E")"
        return "\(latitude), \(longitude)"
    }

    /// Whether a region measures roads in miles.
    public static func usesMiles(region: String?) -> Bool {
        ["US", "GB", "LR", "MM"].contains(region?.uppercased() ?? "")
    }

    /// Rounded to a step, and never to nothing when there's something.
    static func rounded(_ value: Double, to step: Double) -> Int {
        let rounded = Int((value / step).rounded() * step)
        return value > 0 ? max(Int(step), rounded) : rounded
    }

    static func decimal(_ value: Double, places: Int = 1) -> String {
        var scale = 1
        for _ in 0..<places { scale *= 10 }
        let scaled = Int((value * Double(scale)).rounded())
        let fraction = String(scaled % scale)
        return "\(scaled / scale).\(String(repeating: "0", count: places - fraction.count))\(fraction)"
    }
}
