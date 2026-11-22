//
//  WeatherCoreTests.swift
//  CoreApps
//

import Foundation
import Testing
@testable import WeatherCore

/// A forecast as Open-Meteo sends it, cut down: London on an evening in
/// November, three days and the hours around sunset and sunrise.
let londonJSON = """
{
  "latitude": 51.51, "longitude": -0.13, "utc_offset_seconds": 0, "timezone": "Europe/London",
  "current": {
    "time": "2026-11-22T20:30", "interval": 900, "temperature_2m": 6.9, "relative_humidity_2m": 71,
    "apparent_temperature": 3.8, "is_day": 0, "precipitation": 0.0, "weather_code": 1,
    "pressure_msl": 1016.0, "wind_speed_10m": 9.4, "wind_direction_10m": 47
  },
  "hourly": {
    "time": ["2026-11-22T19:00", "2026-11-22T20:00", "2026-11-22T21:00", "2026-11-22T22:00",
             "2026-11-22T23:00", "2026-11-23T00:00", "2026-11-23T07:00", "2026-11-23T08:00"],
    "temperature_2m": [7.4, 7.0, 6.4, null, 5.6, 5.1, 2.9, 3.4],
    "weather_code": [2, 1, 3, 3, 61, 63, 0, 0],
    "precipitation_probability": [5, 5, 10, 20, 55, 70, null, 0],
    "is_day": [0, 0, 0, 0, 0, 0, 0, 1]
  },
  "daily": {
    "time": ["2026-11-22", "2026-11-23", "2026-11-24"],
    "weather_code": [3, 63, 0],
    "temperature_2m_max": [9.1, 8.0, 11.2],
    "temperature_2m_min": [3.2, 1.5, 4.0],
    "sunrise": ["2026-11-22T07:28", "2026-11-23T07:30", "2026-11-24T07:31"],
    "sunset": ["2026-11-22T16:01", "2026-11-23T16:00", "2026-11-24T15:59"],
    "uv_index_max": [0.9, 0.6, 1.0],
    "precipitation_probability_max": [10, 80, 0],
    "precipitation_sum": [0.0, 6.3, null]
  }
}
"""

func london() throws -> Forecast {
    try JSONDecoder().decode(Forecast.self, from: Data(londonJSON.utf8))
}

@Suite struct ConditionTests {

    @Test func codesNameTheWeather() {
        #expect(Condition(code: 0) == .clear)
        #expect(Condition(code: 2) == .partlyCloudy)
        #expect(Condition(code: 48) == .fog)
        #expect(Condition(code: 65) == .rain(.heavy))
        #expect(Condition(code: 81) == .showers(.moderate))
        #expect(Condition(code: 99) == .thunderstormWithHail)
    }

    @Test func anUnknownCodeIsCloud() {
        #expect(Condition(code: 42) == .cloudy)
    }

    @Test func aClearSkyIsSunnyByDay() {
        #expect(Condition.clear.name(isDay: true) == "Sunny")
        #expect(Condition.clear.name(isDay: false) == "Clear")
        #expect(Condition.clear.glyph(isDay: false) == .moon)
        #expect(Condition.mostlyClear.glyph(isDay: true) == .partlySun)
    }

    @Test func heavyRainHasItsOwnPicture() {
        #expect(Condition.rain(.heavy).glyph() == .heavyRain)
        #expect(Condition.showers(.light).glyph() == .rain)
        #expect(Condition.freezingRain.glyph() == .sleet)
        #expect(Condition.snowShowers.glyph() == .snow)
    }
}

@Suite struct LocalDateTimeTests {

    @Test func readsOpenMeteoTimes() {
        #expect(LocalDateTime("2026-11-22T20:30") == LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 30))
        #expect(LocalDateTime("2026-11-22") == LocalDateTime(year: 2026, month: 11, day: 22))
        #expect(LocalDateTime("2026-13-01") == nil)
        #expect(LocalDateTime("") == nil)
        #expect(LocalDateTime("2026-11-22T7") == nil)
    }

    @Test func writesWhatItReads() {
        #expect(LocalDateTime("2026-01-05T07:03")?.description == "2026-01-05T07:03")
    }

    @Test func knowsTheDayOfTheWeek() {
        // 22 November 2026 is a Sunday; 1 January 2000 a Saturday.
        #expect(LocalDateTime(year: 2026, month: 11, day: 22).weekday == 0)
        #expect(LocalDateTime(year: 2000, month: 1, day: 1).weekday == 6)
        #expect(LocalDateTime(year: 1969, month: 12, day: 31).weekday == 3)
    }

    @Test func turnsAMomentIntoAPlacesTime() {
        // 2026-11-22T20:30Z.
        let moment = 1_795_379_400
        #expect(LocalDateTime(secondsSince1970: moment) == LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 30))
        // Tokyo, nine hours ahead, is already in the next day.
        #expect(LocalDateTime(secondsSince1970: moment, offset: 9 * 3600) == LocalDateTime(year: 2026, month: 11, day: 23, hour: 5, minute: 30))
        // Before 1970.
        #expect(LocalDateTime(secondsSince1970: -60) == LocalDateTime(year: 1969, month: 12, day: 31, hour: 23, minute: 59))
    }

    @Test func comparesByTime() {
        let evening = LocalDateTime(year: 2026, month: 11, day: 22, hour: 20)
        let morning = LocalDateTime(year: 2026, month: 11, day: 23, hour: 7)
        #expect(evening < morning)
        #expect(morning.startOfDay == LocalDateTime(year: 2026, month: 11, day: 23))
    }
}

@Suite struct ForecastTests {

    @Test func decodesOpenMeteo() throws {
        let forecast = try london()
        #expect(forecast.timezone == "Europe/London")
        #expect(forecast.current.temperature == 6.9)
        #expect(forecast.current.humidity == 71)
        #expect(forecast.current.time == LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 30))
    }

    @Test func survivesBeingKept() throws {
        let forecast = try london()
        let data = try JSONEncoder().encode(forecast)
        let kept = try JSONDecoder().decode(Forecast.self, from: data)
        #expect(kept == forecast)
    }

    @Test func leavesOutHoursWithNoTemperature() throws {
        let hours = try london().hours
        #expect(hours.count == 7)
        #expect(!hours.contains { $0.time.hour == 22 })
        #expect(hours[4].precipitationChance == 70)
        #expect(hours[5].precipitationChance == nil)
    }

    @Test func readsTheDays() throws {
        let days = try london().days
        #expect(days.count == 3)
        #expect(days[1].condition == .rain(.moderate))
        #expect(days[1].precipitation == 6.3)
        #expect(days[2].precipitation == nil)
        #expect(days[0].sunset == LocalDateTime(year: 2026, month: 11, day: 22, hour: 16, minute: 1))
    }

    @Test func readsNowFromTheCurrentWeather() throws {
        let forecast = try london()
        let reading = forecast.reading(at: LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 50))
        #expect(reading.temperature == 6.9)
        #expect(reading.condition == .mostlyClear)
        #expect(!reading.isDay)
    }

    @Test func readsLaterFromTheHours() throws {
        let forecast = try london()
        let reading = forecast.reading(at: LocalDateTime(year: 2026, month: 11, day: 23, hour: 0, minute: 10))
        #expect(reading.temperature == 5.1)
        #expect(reading.condition == .rain(.moderate))
    }

    @Test func theTimelineStartsNowAndHasTheSunrise() throws {
        let forecast = try london()
        let items = forecast.timeline(from: LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 30), hours: 24)
        guard case let .hour(first, isNow) = items.first else {
            Issue.record("The first column isn't an hour")
            return
        }
        #expect(isNow)
        #expect(first.time.hour == 20)
        #expect(items.contains(.sunrise(LocalDateTime(year: 2026, month: 11, day: 23, hour: 7, minute: 30))))
        // Tonight's sunset has gone, and the hour at 19:00 with it.
        #expect(!items.contains { if case .sunset = $0 { true } else { false } })
        #expect(!items.contains { $0.time.hour == 19 })
        // The sunrise comes between seven and eight.
        let sunrise = items.firstIndex { if case .sunrise = $0 { true } else { false } }
        #expect(sunrise.map { items[$0 - 1].time.hour } == 7)
        #expect(sunrise.map { items[$0 + 1].time.hour } == 8)
    }

    @Test func theTimelineStopsAfterItsHours() throws {
        let forecast = try london()
        let items = forecast.timeline(from: LocalDateTime(year: 2026, month: 11, day: 22, hour: 20), hours: 2)
        #expect(items.map(\.id) == ["hour 2026-11-22T20:00", "hour 2026-11-22T21:00", "hour 2026-11-22T23:00"])
    }

    @Test func daysStartToday() throws {
        let forecast = try london()
        let days = forecast.days(from: LocalDateTime(year: 2026, month: 11, day: 23, hour: 9))
        #expect(days.count == 2)
        #expect(forecast.day(at: LocalDateTime(year: 2026, month: 11, day: 23, hour: 9))?.high == 8.0)
    }

    @Test func aPlaceIsOnItsOwnClock() throws {
        let forecast = try london()
        #expect(forecast.localTime(secondsSince1970: 1_795_379_400) == LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 30))
    }
}

@Suite struct TemperatureBarTests {

    @Test func placesTheDayOnTheWeek() {
        let bar = TemperatureBar(low: 5, high: 10, coldest: 0, warmest: 20)
        #expect(bar.start == 0.25)
        #expect(bar.end == 0.5)
    }

    @Test func aWeekOfOneTemperatureFillsTheBar() {
        let bar = TemperatureBar(low: 4, high: 4, coldest: 4, warmest: 4)
        #expect(bar.start == 0)
        #expect(bar.end == 1)
    }

    @Test func findsTheWeeksRange() throws {
        let range = TemperatureBar.range(of: try london().days)
        #expect(range.coldest == 1.5)
        #expect(range.warmest == 11.2)
    }
}

@Suite struct PlaceTests {

    @Test func decodesASearch() throws {
        let json = """
        {"results":[{"id":2643743,"name":"London","latitude":51.50853,"longitude":-0.12574,"elevation":25.0,
        "country_code":"GB","timezone":"Europe/London","country":"United Kingdom","admin1":"England"},
        {"id":2950159,"name":"Berlin","latitude":52.52,"longitude":13.41,"country":"Germany","admin1":"Berlin"}]}
        """
        let places = try JSONDecoder().decode(PlaceSearch.self, from: Data(json.utf8)).places
        #expect(places.count == 2)
        #expect(places[0].subtitle == "England, United Kingdom")
        // A region named as its city isn't said twice.
        #expect(places[1].subtitle == "Germany")
    }

    @Test func anEmptySearchHasNoResults() throws {
        let search = try JSONDecoder().decode(PlaceSearch.self, from: Data(#"{"generationtime_ms":0.12}"#.utf8))
        #expect(search.places.isEmpty)
    }

    @Test func escapesTheSearch() {
        #expect(OpenMeteo.percentEncoded("São Paulo") == "S%C3%A3o%20Paulo")
        #expect(OpenMeteo.percentEncoded("a&b=c") == "a%26b%3Dc")
        #expect(OpenMeteo.searchURL(for: "New York", count: 5).hasSuffix("?name=New%20York&count=5&language=en&format=json"))
    }

    @Test func asksForTheForecastOnThePlacesClock() {
        let url = OpenMeteo.forecastURL(for: Place(id: 1, name: "London", latitude: 51.5, longitude: -0.125))
        #expect(url.hasPrefix("https://api.open-meteo.com/v1/forecast?latitude=51.5&longitude=-0.125&current="))
        #expect(url.contains("&timezone=auto&forecast_days=10"))
        #expect(url.contains("weather_code"))
    }
}

@Suite struct WeatherTextTests {

    @Test func roundsTemperatures() {
        #expect(WeatherText.temperature(6.9, in: .metric) == "7°")
        #expect(WeatherText.temperature(-0.4, in: .metric) == "0°")
        #expect(WeatherText.temperature(-3.6, in: .metric) == "-4°")
        #expect(WeatherText.temperature(20, in: .us) == "68°")
        #expect(WeatherText.highLow(high: 9.1, low: 3.2, in: .metric) == "H:9° L:3°")
    }

    @Test func writesHoursAndTimes() {
        let evening = LocalDateTime(year: 2026, month: 11, day: 22, hour: 20, minute: 5)
        let midnight = LocalDateTime(year: 2026, month: 11, day: 23)
        #expect(WeatherText.hour(evening, uses24Hour: false) == "8 PM")
        #expect(WeatherText.hour(midnight, uses24Hour: false) == "12 AM")
        #expect(WeatherText.hour(evening, uses24Hour: true) == "20")
        #expect(WeatherText.hour(midnight, uses24Hour: true) == "00")
        #expect(WeatherText.time(evening, uses24Hour: false) == "8:05 PM")
        #expect(WeatherText.time(evening, uses24Hour: true) == "20:05")
    }

    @Test func namesTheDays() {
        let today = LocalDateTime(year: 2026, month: 11, day: 22, hour: 20)
        #expect(WeatherText.day(LocalDateTime(year: 2026, month: 11, day: 22), today: today) == "Today")
        #expect(WeatherText.day(LocalDateTime(year: 2026, month: 11, day: 23), today: today) == "Mon")
    }

    @Test func pointsTheCompass() {
        #expect(WeatherText.compass(0) == "N")
        #expect(WeatherText.compass(47) == "NE")
        #expect(WeatherText.compass(350) == "N")
        #expect(WeatherText.compass(200) == "SSW")
        #expect(WeatherText.compass(-90) == "W")
    }

    @Test func convertsUnits() {
        #expect(WeatherText.windSpeed(9.4, in: .metric) == "9 km/h")
        #expect(WeatherText.windSpeed(16.1, in: .us) == "10 mph")
        #expect(WeatherText.precipitation(6.3, in: .metric) == "6.3 mm")
        #expect(WeatherText.precipitation(12.4, in: .metric) == "12 mm")
        #expect(WeatherText.precipitation(25.4, in: .us) == "1.00 in")
        #expect(WeatherText.pressure(1016, in: .metric) == "1016 hPa")
        #expect(WeatherText.pressure(1016, in: .us) == "30.00 inHg")
    }

    @Test func writesDecimals() {
        #expect(WeatherText.decimal(0.05, places: 2) == "0.05")
        #expect(WeatherText.decimal(-1.25, places: 1) == "-1.3")
        #expect(WeatherText.decimal(-0.01, places: 1) == "0.0")
        #expect(WeatherText.decimal(3.7, places: 0) == "4")
    }

    @Test func gradesTheSun() {
        #expect(WeatherText.uvLevel(0.9) == "Low")
        #expect(WeatherText.uvLevel(5.4) == "Moderate")
        #expect(WeatherText.uvLevel(7) == "High")
        #expect(WeatherText.uvLevel(11.2) == "Extreme")
    }

    @Test func picksUnitsByRegion() {
        #expect(UnitSystem(region: "US") == .us)
        #expect(UnitSystem(region: "gb") == .metric)
        #expect(UnitSystem(region: nil) == .metric)
    }
}
