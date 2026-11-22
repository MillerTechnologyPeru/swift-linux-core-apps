//
//  Condition.swift
//  CoreApps
//

/// The weather, as a WMO weather code names it.
public enum Condition: Equatable, Hashable, Sendable {
    case clear
    case mostlyClear
    case partlyCloudy
    case cloudy
    case fog
    case drizzle
    case freezingDrizzle
    case rain(Intensity)
    case freezingRain
    case snow(Intensity)
    case snowGrains
    case showers(Intensity)
    case snowShowers
    case thunderstorm
    case thunderstormWithHail

    /// How hard it rains or snows.
    public enum Intensity: Equatable, Hashable, Sendable {
        case light
        case moderate
        case heavy
    }

    /// The condition a WMO code (as Open-Meteo gives it) stands for. A code
    /// it doesn't know is taken for cloud.
    public init(code: Int) {
        switch code {
        case 0: self = .clear
        case 1: self = .mostlyClear
        case 2: self = .partlyCloudy
        case 3: self = .cloudy
        case 45, 48: self = .fog
        case 51, 53, 55: self = .drizzle
        case 56, 57: self = .freezingDrizzle
        case 61: self = .rain(.light)
        case 63: self = .rain(.moderate)
        case 65: self = .rain(.heavy)
        case 66, 67: self = .freezingRain
        case 71: self = .snow(.light)
        case 73: self = .snow(.moderate)
        case 75: self = .snow(.heavy)
        case 77: self = .snowGrains
        case 80: self = .showers(.light)
        case 81: self = .showers(.moderate)
        case 82: self = .showers(.heavy)
        case 85, 86: self = .snowShowers
        case 95: self = .thunderstorm
        case 96, 99: self = .thunderstormWithHail
        default: self = .cloudy
        }
    }

    /// The condition's name: a clear sky is sunny by day.
    public func name(isDay: Bool = true) -> String {
        switch self {
        case .clear: isDay ? "Sunny" : "Clear"
        case .mostlyClear: isDay ? "Mostly Sunny" : "Mostly Clear"
        case .partlyCloudy: "Partly Cloudy"
        case .cloudy: "Cloudy"
        case .fog: "Foggy"
        case .drizzle: "Drizzle"
        case .freezingDrizzle: "Freezing Drizzle"
        case .rain(.light): "Light Rain"
        case .rain(.moderate): "Rain"
        case .rain(.heavy): "Heavy Rain"
        case .freezingRain: "Freezing Rain"
        case .snow(.light): "Light Snow"
        case .snow(.moderate): "Snow"
        case .snow(.heavy): "Heavy Snow"
        case .snowGrains: "Snow Grains"
        case .showers(.light): "Light Showers"
        case .showers(.moderate): "Showers"
        case .showers(.heavy): "Heavy Showers"
        case .snowShowers: "Snow Showers"
        case .thunderstorm: "Thunderstorms"
        case .thunderstormWithHail: "Thunderstorms and Hail"
        }
    }

    /// The picture the condition is drawn with.
    public func glyph(isDay: Bool = true) -> Glyph {
        switch self {
        case .clear: isDay ? .sun : .moon
        case .mostlyClear, .partlyCloudy: isDay ? .partlySun : .partlyMoon
        case .cloudy: .cloud
        case .fog: .fog
        case .drizzle: .drizzle
        case .rain(.heavy), .showers(.heavy): .heavyRain
        case .rain, .showers: .rain
        case .freezingDrizzle, .freezingRain: .sleet
        case .snow, .snowGrains, .snowShowers: .snow
        case .thunderstorm, .thunderstormWithHail: .thunderstorm
        }
    }

    /// Whether the sky is mostly clear, which a forecast's colors follow.
    public var isClear: Bool {
        switch self {
        case .clear, .mostlyClear, .partlyCloudy: true
        default: false
        }
    }
}

/// A picture of the weather.
public enum Glyph: Equatable, Hashable, Sendable, CaseIterable {
    case sun
    case moon
    case partlySun
    case partlyMoon
    case cloud
    case fog
    case drizzle
    case rain
    case heavyRain
    case sleet
    case snow
    case thunderstorm
}
