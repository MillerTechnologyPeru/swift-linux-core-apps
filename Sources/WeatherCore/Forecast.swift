//
//  Forecast.swift
//  CoreApps
//

/// A place's weather now, by the hour and by the day, as Open-Meteo's
/// forecast gives it. Temperatures are in °C, wind in km/h, rain in mm and
/// pressure in hPa; times are on the place's own clock.
public struct Forecast: Codable, Equatable, Sendable {

    /// Seconds the place's clock is ahead of UTC.
    public var utcOffset: Int

    public var timezone: String

    public var current: Current

    public var hourly: Hourly

    public var daily: Daily

    enum CodingKeys: String, CodingKey {
        case utcOffset = "utc_offset_seconds"
        case timezone
        case current
        case hourly
        case daily
    }

    public init(utcOffset: Int, timezone: String, current: Current, hourly: Hourly, daily: Daily) {
        self.utcOffset = utcOffset
        self.timezone = timezone
        self.current = current
        self.hourly = hourly
        self.daily = daily
    }

    /// The weather at the moment the forecast was made.
    public struct Current: Codable, Equatable, Sendable {
        public var time: LocalDateTime
        public var temperature: Double
        public var apparentTemperature: Double?
        public var humidity: Double?
        public var isDay: Int?
        public var precipitation: Double?
        public var weatherCode: Int?
        public var pressure: Double?
        public var windSpeed: Double?
        public var windDirection: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case humidity = "relative_humidity_2m"
            case isDay = "is_day"
            case precipitation
            case weatherCode = "weather_code"
            case pressure = "pressure_msl"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
        }

        public init(
            time: LocalDateTime, temperature: Double, apparentTemperature: Double? = nil, humidity: Double? = nil,
            isDay: Int? = 1, precipitation: Double? = nil, weatherCode: Int? = 0, pressure: Double? = nil,
            windSpeed: Double? = nil, windDirection: Double? = nil
        ) {
            self.time = time
            self.temperature = temperature
            self.apparentTemperature = apparentTemperature
            self.humidity = humidity
            self.isDay = isDay
            self.precipitation = precipitation
            self.weatherCode = weatherCode
            self.pressure = pressure
            self.windSpeed = windSpeed
            self.windDirection = windDirection
        }
    }

    /// The forecast hour by hour, in columns.
    public struct Hourly: Codable, Equatable, Sendable {
        public var time: [String]
        public var temperature: [Double?]
        public var weatherCode: [Int?]
        public var precipitationProbability: [Int?]?
        public var isDay: [Int?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitationProbability = "precipitation_probability"
            case isDay = "is_day"
        }

        public init(time: [String], temperature: [Double?], weatherCode: [Int?], precipitationProbability: [Int?]? = nil, isDay: [Int?]? = nil) {
            self.time = time
            self.temperature = temperature
            self.weatherCode = weatherCode
            self.precipitationProbability = precipitationProbability
            self.isDay = isDay
        }
    }

    /// The forecast day by day, in columns.
    public struct Daily: Codable, Equatable, Sendable {
        public var time: [String]
        public var weatherCode: [Int?]
        public var temperatureMax: [Double?]
        public var temperatureMin: [Double?]
        public var sunrise: [String?]?
        public var sunset: [String?]?
        public var uvIndexMax: [Double?]?
        public var precipitationProbabilityMax: [Int?]?
        public var precipitationSum: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperatureMax = "temperature_2m_max"
            case temperatureMin = "temperature_2m_min"
            case sunrise
            case sunset
            case uvIndexMax = "uv_index_max"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case precipitationSum = "precipitation_sum"
        }

        public init(
            time: [String], weatherCode: [Int?], temperatureMax: [Double?], temperatureMin: [Double?],
            sunrise: [String?]? = nil, sunset: [String?]? = nil, uvIndexMax: [Double?]? = nil,
            precipitationProbabilityMax: [Int?]? = nil, precipitationSum: [Double?]? = nil
        ) {
            self.time = time
            self.weatherCode = weatherCode
            self.temperatureMax = temperatureMax
            self.temperatureMin = temperatureMin
            self.sunrise = sunrise
            self.sunset = sunset
            self.uvIndexMax = uvIndexMax
            self.precipitationProbabilityMax = precipitationProbabilityMax
            self.precipitationSum = precipitationSum
        }
    }
}

// MARK: - Reading it

/// One hour of the forecast.
public struct Hour: Equatable, Sendable {
    public var time: LocalDateTime
    public var temperature: Double
    public var condition: Condition
    public var isDay: Bool
    /// The chance of rain or snow, in percent.
    public var precipitationChance: Int?
}

/// One day of the forecast.
public struct Day: Equatable, Sendable {
    public var date: LocalDateTime
    public var condition: Condition
    public var high: Double
    public var low: Double
    public var sunrise: LocalDateTime?
    public var sunset: LocalDateTime?
    public var uvIndex: Double?
    /// The chance of rain or snow, in percent.
    public var precipitationChance: Int?
    /// Rain and snow in all, in mm.
    public var precipitation: Double?
}

/// What it's like out at some moment.
public struct Reading: Equatable, Sendable {
    public var temperature: Double
    public var condition: Condition
    public var isDay: Bool
}

/// A column in the hour-by-hour strip.
public enum HourItem: Equatable, Sendable {
    /// An hour, the first being the one it is now.
    case hour(Hour, isNow: Bool)
    case sunrise(LocalDateTime)
    case sunset(LocalDateTime)

    public var time: LocalDateTime {
        switch self {
        case let .hour(hour, _): hour.time
        case let .sunrise(time), let .sunset(time): time
        }
    }

    /// Tells columns apart.
    public var id: String {
        switch self {
        case let .hour(hour, _): "hour \(hour.time)"
        case let .sunrise(time): "sunrise \(time)"
        case let .sunset(time): "sunset \(time)"
        }
    }
}

extension Forecast {

    /// The hours, leaving out any with no temperature.
    public var hours: [Hour] {
        var hours: [Hour] = []
        hours.reserveCapacity(hourly.time.count)
        for index in hourly.time.indices {
            guard let time = LocalDateTime(hourly.time[index]),
                  let temperature = hourly.temperature.element(index) ?? nil
            else { continue }
            hours.append(Hour(
                time: time,
                temperature: temperature,
                condition: Condition(code: (hourly.weatherCode.element(index) ?? nil) ?? 3),
                isDay: ((hourly.isDay?.element(index) ?? nil) ?? 1) != 0,
                precipitationChance: hourly.precipitationProbability?.element(index) ?? nil
            ))
        }
        return hours
    }

    /// The days, leaving out any with no high or low.
    public var days: [Day] {
        var days: [Day] = []
        for index in daily.time.indices {
            guard let date = LocalDateTime(daily.time[index]),
                  let high = daily.temperatureMax.element(index) ?? nil,
                  let low = daily.temperatureMin.element(index) ?? nil
            else { continue }
            days.append(Day(
                date: date,
                condition: Condition(code: (daily.weatherCode.element(index) ?? nil) ?? 3),
                high: high,
                low: low,
                sunrise: (daily.sunrise?.element(index) ?? nil).flatMap(LocalDateTime.init),
                sunset: (daily.sunset?.element(index) ?? nil).flatMap(LocalDateTime.init),
                uvIndex: daily.uvIndexMax?.element(index) ?? nil,
                precipitationChance: daily.precipitationProbabilityMax?.element(index) ?? nil,
                precipitation: daily.precipitationSum?.element(index) ?? nil
            ))
        }
        return days
    }

    /// The time at the place, at a moment in seconds since 1970.
    public func localTime(secondsSince1970: Int) -> LocalDateTime {
        LocalDateTime(secondsSince1970: secondsSince1970, offset: utcOffset)
    }

    /// What it's like at `now`: the forecast's current weather within the
    /// hour it was made, and the hour's forecast after that.
    public func reading(at now: LocalDateTime) -> Reading {
        let made = current.time.minutesSince1970
        if now.minutesSince1970 - made < 60 {
            return Reading(
                temperature: current.temperature,
                condition: Condition(code: current.weatherCode ?? 3),
                isDay: (current.isDay ?? 1) != 0
            )
        }
        if let hour = hour(at: now) {
            return Reading(temperature: hour.temperature, condition: hour.condition, isDay: hour.isDay)
        }
        return Reading(
            temperature: current.temperature,
            condition: Condition(code: current.weatherCode ?? 3),
            isDay: (current.isDay ?? 1) != 0
        )
    }

    /// The hour `now` falls in.
    public func hour(at now: LocalDateTime) -> Hour? {
        let start = LocalDateTime(year: now.year, month: now.month, day: now.day, hour: now.hour)
        return hours.first { $0.time == start }
    }

    /// The days from `now`'s on.
    public func days(from now: LocalDateTime) -> [Day] {
        let today = now.startOfDay
        return self.days.filter { $0.date >= today }
    }

    /// The day `now` falls on.
    public func day(at now: LocalDateTime) -> Day? {
        days(from: now).first { $0.date == now.startOfDay }
    }

    /// The hours from the one `now` falls in, `count` after it, with the
    /// sunrises and sunsets between them.
    public func timeline(from now: LocalDateTime, hours count: Int = 24) -> [HourItem] {
        let start = LocalDateTime(year: now.year, month: now.month, day: now.day, hour: now.hour)
        let shown = self.hours.filter { $0.time >= start }.prefix(count + 1)
        guard let last = shown.last else { return [] }
        var items = shown.map { HourItem.hour($0, isNow: $0.time == start) }
        for day in self.days {
            if let sunrise = day.sunrise, sunrise > now, sunrise <= last.time {
                items.append(.sunrise(sunrise))
            }
            if let sunset = day.sunset, sunset > now, sunset <= last.time {
                items.append(.sunset(sunset))
            }
        }
        // The order is the time's; a sunrise on the hour comes after it.
        return items.enumerated().sorted { lhs, rhs in
            lhs.element.time != rhs.element.time ? lhs.element.time < rhs.element.time : lhs.offset < rhs.offset
        }.map(\.element)
    }
}

/// Where a day's low and high sit on a bar that runs from the coldest
/// low to the warmest high of the days shown.
public struct TemperatureBar: Equatable, Sendable {

    /// Where the day's low is, from 0 at the left to 1 at the right.
    public var start: Double

    /// Where the day's high is.
    public var end: Double

    public init(low: Double, high: Double, coldest: Double, warmest: Double) {
        let span = warmest - coldest
        guard span > 0 else {
            self.start = 0
            self.end = 1
            return
        }
        start = min(1, max(0, (low - coldest) / span))
        end = min(1, max(start, (high - coldest) / span))
    }

    /// The coldest low and warmest high of some days.
    public static func range(of days: [Day]) -> (coldest: Double, warmest: Double) {
        (days.map(\.low).min() ?? 0, days.map(\.high).max() ?? 0)
    }
}

extension Array {

    /// The element at `index`, if there is one.
    func element(_ index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
