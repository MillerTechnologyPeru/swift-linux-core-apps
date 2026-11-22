//
//  WeatherModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import Foundation
import WeatherCore

/// A forecast and when it was fetched.
struct KeptForecast: Codable, Equatable {
    var forecast: Forecast
    var fetched: Date
}

/// What the weather keeps between launches.
private struct Saved: Codable {
    var places: [Place]
    var units: UnitSystem?
}

/// The places shown and their forecasts.
@MainActor
final class WeatherModel: ObservableObject {

    @Published var places: [Place] { didSet { save() } }

    @Published var units: UnitSystem { didSet { save() } }

    /// Whether times are written on a 24-hour clock, as the locale does.
    let uses24Hour: Bool

    /// The last forecast fetched for each place, by the place's id, kept
    /// so a place shows something while offline.
    @Published private(set) var forecasts: [Int: KeptForecast]

    /// The places being fetched.
    @Published private(set) var loading: Set<Int> = []

    /// Why each place's last fetch failed.
    @Published private(set) var failures: [Int: String] = [:]

    /// How old a forecast may be before opening the app fetches it again.
    static let freshness: TimeInterval = 15 * 60

    private let service = WeatherService()

    private let file: URL

    private let cacheFile: URL

    init() {
        file = Self.folder(environment: "XDG_CONFIG_HOME", fallback: ".config").appendingPathComponent("weather.json")
        cacheFile = Self.folder(environment: "XDG_CACHE_HOME", fallback: ".cache").appendingPathComponent("forecasts.json")
        let saved = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        places = saved?.places ?? []
        units = saved?.units ?? UnitSystem(region: Locale.current.region?.identifier)
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        uses24Hour = !format.contains("a")
        let cached = (try? Data(contentsOf: cacheFile)).flatMap { try? JSONDecoder().decode([String: KeptForecast].self, from: $0) }
        var forecasts: [Int: KeptForecast] = [:]
        for (key, value) in cached ?? [:] {
            if let id = Int(key) { forecasts[id] = value }
        }
        self.forecasts = forecasts
    }

    // MARK: Keeping

    /// The weather's folder for settings or caches: XDG's on Linux,
    /// Application Support or Caches on Apple's systems.
    private static func folder(environment variable: String, fallback: String) -> URL {
        #if canImport(Darwin)
        let directory: FileManager.SearchPathDirectory = variable == "XDG_CACHE_HOME" ? .cachesDirectory : .applicationSupportDirectory
        let base = FileManager.default.urls(for: directory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        var base = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(fallback, isDirectory: true)
        if let path = ProcessInfo.processInfo.environment[variable], path.hasPrefix("/") {
            base = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        return base.appendingPathComponent("weather", isDirectory: true)
    }

    private func save() {
        write(Saved(places: places, units: units), to: file)
    }

    private func saveCache() {
        // Only the places still shown.
        let shown = Set(places.map(\.id))
        var cache: [String: KeptForecast] = [:]
        for (id, kept) in forecasts where shown.contains(id) {
            cache[String(id)] = kept
        }
        write(cache, to: cacheFile)
    }

    private func write<T: Encodable>(_ value: T, to file: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    // MARK: Places

    /// The kept place with a name, in any case.
    func place(named name: String) -> Place? {
        places.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    func add(_ place: Place) {
        guard !places.contains(where: { $0.id == place.id }) else { return }
        places.append(place)
        Task { await refresh(place, force: true) }
    }

    func remove(_ place: Place) {
        places.removeAll { $0.id == place.id }
        forecasts[place.id] = nil
        failures[place.id] = nil
        saveCache()
    }

    func move(_ place: Place, by offset: Int) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        let target = index + offset
        guard places.indices.contains(target) else { return }
        places.swapAt(index, target)
    }

    // MARK: Forecasts

    func forecast(for place: Place) -> Forecast? {
        forecasts[place.id]?.forecast
    }

    /// The time at the place now, once its forecast says how far its clock
    /// is from UTC.
    func now(at place: Place) -> LocalDateTime? {
        forecast(for: place)?.localTime(secondsSince1970: Int(Date().timeIntervalSince1970))
    }

    /// Fetches every place's forecast that's older than `freshness`, or all
    /// of them when forced.
    func refreshAll(force: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for place in places {
                group.addTask { await self.refresh(place, force: force) }
            }
        }
    }

    func refresh(_ place: Place, force: Bool = false) async {
        if !force, let kept = forecasts[place.id], Date().timeIntervalSince(kept.fetched) < Self.freshness {
            return
        }
        guard !loading.contains(place.id) else { return }
        loading.insert(place.id)
        defer { loading.remove(place.id) }
        do {
            let forecast = try await service.forecast(for: place)
            forecasts[place.id] = KeptForecast(forecast: forecast, fetched: Date())
            failures[place.id] = nil
            saveCache()
        } catch let error as WeatherError {
            failures[place.id] = error.message
        } catch {
            failures[place.id] = error.localizedDescription
        }
    }

    func search(_ name: String) async throws -> [Place] {
        try await service.search(name)
    }
}

#endif
