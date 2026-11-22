//
//  MapModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import Foundation
import MapsCore

/// What the maps keep between launches.
private struct Saved: Codable {
    var viewport: Viewport
    var places: [MapPlace]
}

/// Directions being planned or shown.
struct Directions: Equatable {
    var origin: MapPlace?
    var destination: MapPlace
    var mode: TravelMode
    var route: Route?
    var isLoading = false
    var failure: String?
}

/// Where the map is, what's picked on it, what a search found, and the
/// directions shown.
@MainActor
final class MapModel: ObservableObject {

    @Published var viewport: Viewport { didSet { scheduleSave() } }

    /// Places kept, to go back to.
    @Published private(set) var savedPlaces: [MapPlace] { didSet { save() } }

    @Published var selected: MapPlace?

    @Published private(set) var results: [MapPlace] = []

    @Published private(set) var isSearching = false

    @Published var searchFailure: String?

    @Published var directions: Directions?

    /// The size the map was last drawn at, for fitting places into it.
    var size = (width: 360.0, height: 640.0)

    let usesMiles = MapsText.usesMiles(region: Locale.current.region?.identifier)

    private let service = MapsService()

    private let file: URL

    private var saveTask: Task<Void, Never>?

    private var lastSearch = Date.distantPast

    static let world = Viewport(center: Coordinate(latitude: 25, longitude: 0), zoom: 2)

    init() {
        #if canImport(Darwin)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        var base = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(".config", isDirectory: true)
        if let path = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], path.hasPrefix("/") {
            base = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        file = base.appendingPathComponent("maps", isDirectory: true).appendingPathComponent("maps.json")
        let saved = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) }
        viewport = saved?.viewport ?? Self.world
        savedPlaces = saved?.places ?? []
    }

    // MARK: Keeping

    private func save() {
        guard let data = try? JSONEncoder().encode(Saved(viewport: viewport, places: savedPlaces)) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    /// Saves the viewport once the map stops moving.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func isSaved(_ place: MapPlace) -> Bool {
        savedPlaces.contains { $0.id == place.id }
    }

    func toggleSaved(_ place: MapPlace) {
        if isSaved(place) {
            savedPlaces.removeAll { $0.id == place.id }
        } else {
            savedPlaces.append(place)
        }
    }

    // MARK: Moving

    func zoom(by factor: Double) {
        viewport = viewport.zoomed(by: factor, around: ScreenPoint(x: size.width / 2, y: size.height / 2), width: size.width, height: size.height)
    }

    /// Shows a place and picks it.
    func show(_ place: MapPlace) {
        selected = place
        results = []
        viewport = Viewport(center: place.coordinate, zoom: max(viewport.zoom, 16))
    }

    /// The area around what the map shows, four zoom levels out (16
    /// times as wide), for searching near it; none when the map shows a
    /// continent or more.
    private var nearbyArea: (west: Double, north: Double, east: Double, south: Double)? {
        guard viewport.zoom >= 9 else { return nil }
        let around = Viewport(center: viewport.center, zoom: viewport.zoom - 4)
        let topLeft = around.coordinate(at: ScreenPoint(x: 0, y: 0), width: size.width, height: size.height)
        let bottomRight = around.coordinate(at: ScreenPoint(x: size.width, y: size.height), width: size.width, height: size.height)
        return (topLeft.longitude, topLeft.latitude, bottomRight.longitude, bottomRight.latitude)
    }

    // MARK: Searching

    func search(_ query: String) async -> [MapPlace] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        // Nominatim asks for no more than a search a second.
        let wait = 1 - Date().timeIntervalSince(lastSearch)
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        lastSearch = Date()
        isSearching = true
        searchFailure = nil
        defer { isSearching = false }
        do {
            // Near the map first; the whole world if nothing's near.
            var found: [MapPlace] = []
            if let area = nearbyArea {
                found = try await service.search(text, area: area, bounded: true)
                if found.isEmpty {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    lastSearch = Date()
                }
            }
            if found.isEmpty {
                found = try await service.search(text, area: nil, bounded: false)
            }
            if found.isEmpty { searchFailure = "Nothing was found for “\(text)”." }
            return found
        } catch {
            searchFailure = (error as? MapsError)?.message ?? error.localizedDescription
            return []
        }
    }

    /// Searches and shows what's found.
    func find(_ query: String) async {
        results = await search(query)
        if results.count == 1 { show(results[0]) }
    }

    func clearResults() {
        results = []
        searchFailure = nil
    }

    // MARK: Directions

    /// Starts directions to a place; the start is asked for.
    func directions(to place: MapPlace) {
        directions = Directions(origin: nil, destination: place, mode: .car)
    }

    func setOrigin(_ place: MapPlace) async {
        directions?.origin = place
        await route()
    }

    func setMode(_ mode: TravelMode) async {
        directions?.mode = mode
        await route()
    }

    /// Swaps the start and the end.
    func reverse() async {
        guard let current = directions, let origin = current.origin else { return }
        directions?.origin = current.destination
        directions?.destination = origin
        await route()
    }

    private func route() async {
        guard let current = directions, let origin = current.origin else { return }
        directions?.isLoading = true
        directions?.failure = nil
        directions?.route = nil
        do {
            let route = try await service.route(from: origin.coordinate, to: current.destination.coordinate, mode: current.mode)
            guard directions?.destination == current.destination, directions?.mode == current.mode else { return }
            directions?.route = route
            directions?.isLoading = false
            // Fit the route between the top of the screen and the
            // directions' card, which covers about the lower half.
            let top = 80.0
            let bottom = size.height * 0.5
            if bottom > top, let fitted = Viewport.fitting(route.path, width: size.width, height: bottom - top, padding: 24) {
                viewport = fitted.panned(dx: 0, dy: (top + bottom) / 2 - size.height / 2)
            }
        } catch {
            directions?.isLoading = false
            directions?.failure = (error as? MapsError)?.message ?? error.localizedDescription
        }
    }

    func endDirections() {
        directions = nil
    }
}

#endif
