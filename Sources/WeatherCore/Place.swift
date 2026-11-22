//
//  Place.swift
//  CoreApps
//

/// A place to show the weather of, as Open-Meteo's geocoding names it.
public struct Place: Codable, Identifiable, Hashable, Sendable {

    /// GeoNames' number for the place.
    public var id: Int

    public var name: String

    /// The state, province or region.
    public var admin1: String?

    public var country: String?

    public var latitude: Double

    public var longitude: Double

    public var timezone: String?

    public init(
        id: Int, name: String, admin1: String? = nil, country: String? = nil,
        latitude: Double, longitude: Double, timezone: String? = nil
    ) {
        self.id = id
        self.name = name
        self.admin1 = admin1
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    /// Where the place is: its region and country, leaving out a region
    /// named as the place is.
    public var subtitle: String {
        var parts: [String] = []
        if let admin1, !admin1.isEmpty, admin1 != name { parts.append(admin1) }
        if let country, !country.isEmpty { parts.append(country) }
        return parts.joined(separator: ", ")
    }
}

/// What a search for places finds. Open-Meteo leaves `results` out when
/// nothing matches.
public struct PlaceSearch: Decodable, Sendable {

    public var results: [Place]?

    public var places: [Place] { results ?? [] }
}

/// Open-Meteo's addresses: its forecast and its place search, free and
/// without a key.
public enum OpenMeteo {

    /// What's asked for now.
    static let current = [
        "temperature_2m", "relative_humidity_2m", "apparent_temperature", "is_day", "precipitation",
        "weather_code", "pressure_msl", "wind_speed_10m", "wind_direction_10m",
    ]

    /// What's asked for by the hour.
    static let hourly = ["temperature_2m", "weather_code", "precipitation_probability", "is_day"]

    /// What's asked for by the day.
    static let daily = [
        "weather_code", "temperature_2m_max", "temperature_2m_min", "sunrise", "sunset",
        "uv_index_max", "precipitation_probability_max", "precipitation_sum",
    ]

    /// The forecast for a place, in metric units, on the place's own clock.
    public static func forecastURL(for place: Place, days: Int = 10) -> String {
        "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(place.latitude)&longitude=\(place.longitude)"
            + "&current=\(current.joined(separator: ","))"
            + "&hourly=\(hourly.joined(separator: ","))"
            + "&daily=\(daily.joined(separator: ","))"
            + "&timezone=auto&forecast_days=\(days)"
    }

    /// Places whose names start with `name`.
    public static func searchURL(for name: String, count: Int = 10, language: String = "en") -> String {
        "https://geocoding-api.open-meteo.com/v1/search"
            + "?name=\(percentEncoded(name))&count=\(count)&language=\(percentEncoded(language))&format=json"
    }

    /// The attribution Open-Meteo's licence asks for.
    public static let attribution = "Weather data by Open-Meteo.com"

    /// `text` with everything but letters, digits and `-._~` escaped, for
    /// a query.
    public static func percentEncoded(_ text: String) -> String {
        let hex = Array("0123456789ABCDEF")
        var result = ""
        for byte in text.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "~"):
                result.append(Character(Unicode.Scalar(byte)))
            default:
                result.append("%")
                result.append(hex[Int(byte >> 4)])
                result.append(hex[Int(byte & 0xF)])
            }
        }
        return result
    }
}
