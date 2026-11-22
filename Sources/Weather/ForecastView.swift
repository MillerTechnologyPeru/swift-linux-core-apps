//
//  ForecastView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation
import WeatherCore

/// A place's weather: now, by the hour, by the day, and the details.
struct ForecastView: View {

    @EnvironmentObject private var model: WeatherModel

    let place: Place

    var body: some View {
        content
            .navigationTitle("")
            // The sky shows through the bar.
            #if Apple && os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if model.loading.contains(place.id) {
                        ProgressView()
                    } else {
                        Button {
                            Task { await model.refresh(place, force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await model.refresh(place)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let forecast = model.forecast(for: place) {
            // Once a minute, so the hours and "now" move on.
            TimelineView(.everyMinute) { context in
                ForecastBody(
                    place: place,
                    forecast: forecast,
                    now: forecast.localTime(secondsSince1970: Int(context.date.timeIntervalSince1970))
                )
            }
        } else if model.loading.contains(place.id) {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                EmptyState("No Forecast", message: model.failures[place.id] ?? "The forecast hasn't been fetched.")
                    .frame(maxHeight: 160)
                Button("Try Again") {
                    Task { await model.refresh(place, force: true) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The forecast itself, over a sky the color of the weather.
private struct ForecastBody: View {

    @EnvironmentObject private var model: WeatherModel

    let place: Place

    let forecast: Forecast

    let now: LocalDateTime

    private var units: UnitSystem { model.units }

    var body: some View {
        let reading = forecast.reading(at: now)
        let days = forecast.days(from: now)
        ScrollView {
            VStack(spacing: 14) {
                header(reading, today: days.first)
                if let failure = model.failures[place.id] {
                    Text("Showing the last forecast fetched. \(failure)")
                        .font(.caption)
                        .foregroundStyle(Self.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Self.cardFill))
                }
                hourly(reading)
                if !days.isEmpty {
                    daily(days, reading: reading)
                }
                details(days.first)
                footer
            }
            .padding(Metrics.screenPadding)
        }
        .foregroundStyle(Color.white)
        .background(sky(reading).ignoresSafeArea())
    }

    // MARK: Now

    private func header(_ reading: Reading, today: Day?) -> some View {
        VStack(spacing: 2) {
            Text(place.name)
                .font(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(WeatherText.temperature(reading.temperature, in: units))
                .font(.system(size: 88, weight: .thin))
                .monospacedDigit()
            Text(reading.condition.name(isDay: reading.isDay))
                .font(.title3)
            if let today {
                Text(WeatherText.highLow(high: today.high, low: today.low, in: units))
                    .font(.title3)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: Hours

    private func hourly(_ reading: Reading) -> some View {
        Card(title: "Hourly Forecast", symbol: Symbols.clock) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(forecast.timeline(from: now), id: \.id) { item in
                        HourColumn(item: item, now: reading, units: units, uses24Hour: model.uses24Hour)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Days

    private func daily(_ days: [Day], reading: Reading) -> some View {
        let range = TemperatureBar.range(of: days)
        return Card(title: "\(days.count)-Day Forecast", symbol: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    if index > 0 {
                        Rectangle()
                            .fill(Self.divider)
                            .frame(height: 1)
                    }
                    DayRow(
                        day: day,
                        name: WeatherText.day(day.date, today: now),
                        bar: TemperatureBar(low: day.low, high: day.high, coldest: range.coldest, warmest: range.warmest),
                        current: index == 0
                            ? TemperatureBar(low: reading.temperature, high: reading.temperature, coldest: range.coldest, warmest: range.warmest).start
                            : nil,
                        units: units
                    )
                }
            }
        }
    }

    // MARK: Details

    private func details(_ today: Day?) -> some View {
        let current = forecast.current
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            if let apparent = current.apparentTemperature {
                Tile(
                    title: "Feels Like", symbol: Symbols.feelsLike,
                    value: WeatherText.temperature(apparent, in: units),
                    caption: WeatherText.feelsLike(apparent, actual: current.temperature)
                )
            }
            if let humidity = current.humidity {
                Tile(title: "Humidity", symbol: Symbols.humidity, value: WeatherText.percent(humidity), caption: nil)
            }
            if let speed = current.windSpeed {
                Tile(
                    title: "Wind", symbol: Symbols.wind,
                    value: WeatherText.windSpeed(speed, in: units),
                    caption: current.windDirection.map { "From the \(WeatherText.compass($0))" }
                )
            }
            if let uv = today?.uvIndex {
                Tile(title: "UV Index", symbol: "sun.max", value: "\(Int(uv.rounded()))", caption: WeatherText.uvLevel(uv))
            }
            if let sun = sunTile {
                sun
            }
            if let precipitation = today?.precipitation {
                Tile(
                    title: "Precipitation", symbol: Symbols.precipitation,
                    value: WeatherText.precipitation(precipitation, in: units),
                    caption: "Expected today."
                )
            }
            if let pressure = current.pressure {
                Tile(title: "Pressure", symbol: Symbols.pressure, value: WeatherText.pressure(pressure, in: units), caption: nil)
            }
        }
    }

    /// The next sunrise or sunset, and the other after it.
    private var sunTile: Tile? {
        let events = forecast.days.flatMap { day -> [(String, LocalDateTime)] in
            [day.sunrise.map { ("Sunrise", $0) }, day.sunset.map { ("Sunset", $0) }].compactMap { $0 }
        }
        .filter { $0.1 > now }
        .sorted { $0.1 < $1.1 }
        guard let next = events.first else { return nil }
        let after = events.dropFirst().first
        return Tile(
            title: next.0, symbol: Symbols.sun(rising: next.0 == "Sunrise"),
            value: WeatherText.time(next.1, uses24Hour: model.uses24Hour),
            caption: after.map { "\($0.0): \(WeatherText.time($0.1, uses24Hour: model.uses24Hour))" }
        )
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let fetched = model.forecasts[place.id]?.fetched {
                Text("Updated \(fetched.formatted(date: .omitted, time: .shortened))")
            }
            Text(OpenMeteo.attribution)
        }
        .font(.caption)
        .foregroundStyle(Self.secondary)
        .padding(.top, 4)
    }

    // MARK: Colors

    static let secondary = Color.white.opacity(0.72)
    static let cardFill = Color.white.opacity(0.16)
    static let divider = Color.white.opacity(0.18)

    /// A clear blue by day, navy by night, and grey under cloud.
    private func sky(_ reading: Reading) -> LinearGradient {
        let colors: [Color] = switch (reading.condition.isClear, reading.isDay) {
        case (true, true): [Color(red: 0.2, green: 0.5, blue: 0.85), Color(red: 0.45, green: 0.7, blue: 0.95)]
        case (true, false): [Color(red: 0.05, green: 0.09, blue: 0.22), Color(red: 0.17, green: 0.22, blue: 0.4)]
        case (false, true): [Color(red: 0.36, green: 0.45, blue: 0.56), Color(red: 0.56, green: 0.63, blue: 0.71)]
        case (false, false): [Color(red: 0.12, green: 0.15, blue: 0.2), Color(red: 0.26, green: 0.3, blue: 0.36)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// The symbols the forecast's cards use: SF Symbols on Apple's SwiftUI,
/// and the nearest Cacao has.
enum Symbols {
    #if Apple
    static let clock = "clock"
    static let feelsLike = "thermometer.medium"
    static let humidity = "humidity"
    static let wind = "wind"
    static let precipitation = "drop.fill"
    static let pressure = "gauge.medium"
    static func sun(rising: Bool) -> String { rising ? "sunrise" : "sunset" }
    #else
    static let clock = "clock"
    static let feelsLike = "person"
    static let humidity = "circle"
    static let wind = "flag"
    static let precipitation = "arrow.down"
    static let pressure = "arrow.down"
    static func sun(rising: Bool) -> String { rising ? "arrow.up" : "arrow.down" }
    #endif
}

/// A titled card over the sky.
private struct Card<Content: View>: View {

    let title: String

    let symbol: String

    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title.uppercased())
            }
            .font(.caption)
            .foregroundStyle(ForecastBody.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(ForecastBody.cardFill))
    }
}

/// A column of the hour-by-hour strip.
private struct HourColumn: View {

    let item: HourItem

    /// What it's like now, which the first column shows.
    let now: Reading

    let units: UnitSystem

    let uses24Hour: Bool

    var body: some View {
        VStack(spacing: 6) {
            switch item {
            case let .hour(hour, isNow):
                Text(isNow ? "Now" : WeatherText.hour(hour.time, uses24Hour: uses24Hour))
                    .font(.subheadline)
                if isNow {
                    glyph(now.condition.glyph(isDay: now.isDay), chance: hour.precipitationChance)
                    Text(WeatherText.temperature(now.temperature, in: units))
                        .font(.title3)
                } else {
                    glyph(hour.condition.glyph(isDay: hour.isDay), chance: hour.precipitationChance)
                    Text(WeatherText.temperature(hour.temperature, in: units))
                        .font(.title3)
                }
            case let .sunrise(time), let .sunset(time):
                Text(WeatherText.time(time, uses24Hour: uses24Hour))
                    .font(.subheadline)
                glyph(.sun, chance: nil)
                Text(isSunrise ? "Sunrise" : "Sunset")
                    .font(.subheadline)
            }
        }
        .frame(minWidth: 44)
    }

    private var isSunrise: Bool {
        if case .sunrise = item { true } else { false }
    }

    private func glyph(_ glyph: Glyph, chance: Int?) -> some View {
        VStack(spacing: 0) {
            WeatherGlyphView(glyph: glyph, size: 28)
            Text(chance.map { $0 >= 20 ? "\($0)%" : " " } ?? " ")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DayRow.rainColor)
        }
        .frame(height: 44)
    }
}

/// A day of the forecast, with its low and high on the week's bar.
private struct DayRow: View {

    let day: Day

    let name: String

    let bar: TemperatureBar

    /// Where the temperature now sits on the bar, for today.
    let current: Double?

    let units: UnitSystem

    static let rainColor = Color(red: 0.78, green: 0.93, blue: 1.0)

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .lineLimit(1)
                .frame(width: 60, alignment: .leading)
            VStack(spacing: 0) {
                WeatherGlyphView(glyph: day.condition.glyph(), size: 24)
                if let chance = day.precipitationChance, chance >= 20 {
                    Text("\(chance)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Self.rainColor)
                }
            }
            .frame(width: 34)
            Text(WeatherText.temperature(day.low, in: units))
                .monospacedDigit()
                .foregroundStyle(ForecastBody.secondary)
                .frame(width: 38, alignment: .trailing)
            RangeBar(bar: bar, current: current)
                .frame(height: 6)
            Text(WeatherText.temperature(day.high, in: units))
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .frame(minHeight: Metrics.minimumTarget)
    }
}

/// The week's span of temperatures, with the day's part of it filled.
private struct RangeBar: View {

    let bar: TemperatureBar

    let current: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.45, green: 0.85, blue: 0.75), Color(red: 1.0, green: 0.8, blue: 0.25), Color(red: 1.0, green: 0.55, blue: 0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(6, width * (bar.end - bar.start)))
                    .offset(x: width * bar.start)
                if let current {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: min(width - 8, max(0, width * current - 4)))
                }
            }
        }
    }
}

/// A detail: its name, its value and a word on it.
struct Tile: View {

    let title: String

    let symbol: String

    let value: String

    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title.uppercased())
            }
            .font(.caption)
            .foregroundStyle(ForecastBody.secondary)
            Text(value)
                .font(.title)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16).fill(ForecastBody.cardFill))
    }
}

#endif
