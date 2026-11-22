//
//  WeatherApp.swift
//  CoreApps
//

// The weather asks Open-Meteo over HTTP, which a guest can't yet: it's a
// program for now, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation
import WeatherCore

/// The weather.
public struct WeatherApp: App {

    /// The kept place to open at launch, by name: `weather London`.
    private let opening: String?

    public init() {
        // Only Cacao's program reads its arguments: Apple's systems pass
        // their own to an app.
        #if Native
        let arguments = CommandLine.arguments.dropFirst()
        opening = arguments.isEmpty ? nil : arguments.joined(separator: " ")
        #else
        opening = nil
        #endif
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Weather") {
            WeatherView(opening: opening)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            WeatherView(opening: opening)
        }
        #endif
    }
}

/// The places kept, a search for more, and each place's forecast.
public struct WeatherView: View {

    @StateObject private var model = WeatherModel()

    @State private var path: [Place] = []

    @State private var query = ""

    private let opening: String?

    public init(opening: String? = nil) {
        self.opening = opening
    }

    public var body: some View {
        NavigationStack(path: $path) {
            PlacesView(query: $query) { place in
                path.append(place)
            }
            .navigationTitle("Weather")
            .searchable(text: $query, prompt: Text("Search for a city"))
            .navigationDestination(for: Place.self) { place in
                ForecastView(place: place)
            }
        }
        #if Apple && os(iOS)
        // A forecast's bar buttons go white over its sky, which iOS shows
        // through the bar. Cacao's bar is opaque.
        .tint(path.last.flatMap(model.forecast(for:)) == nil ? nil : Color.white)
        #endif
        .environmentObject(model)
        .task {
            if let opening, let place = await model.place(named: opening) {
                path = [place]
            }
            await model.refreshAll()
        }
    }
}

/// The places kept, or what a search finds.
struct PlacesView: View {

    @EnvironmentObject private var model: WeatherModel

    @Binding var query: String

    let open: (Place) -> Void

    @State private var found: [Place] = []

    @State private var isSearching = false

    @State private var searchFailure: String?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Refresh") {
                            Task { await model.refreshAll(force: true) }
                        }
                        Picker("Units", selection: $model.units) {
                            ForEach(UnitSystem.allCases, id: \.self) { units in
                                Text(units.name).tag(units)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .refreshable {
                await model.refreshAll(force: true)
            }
            .task(id: trimmedQuery) {
                await search(trimmedQuery)
            }
    }

    @ViewBuilder
    private var content: some View {
        if !trimmedQuery.isEmpty {
            results
        } else if model.places.isEmpty {
            EmptyState("No Places", message: "Search for a city to see its weather.")
        } else {
            List {
                ForEach(model.places) { place in
                    Button {
                        open(place)
                    } label: {
                        PlaceRow(place: place)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Remove", role: .destructive) { model.remove(place) }
                    }
                    .contextMenu {
                        Button("Move Up") { model.move(place, by: -1) }
                        Button("Move Down") { model.move(place, by: 1) }
                        Button("Remove", role: .destructive) { model.remove(place) }
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text(OpenMeteo.attribution)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if let searchFailure {
            EmptyState("Can't Search", message: searchFailure)
        } else if found.isEmpty {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState("No Results", message: "No city is named “\(trimmedQuery)”.")
            }
        } else {
            List(found) { place in
                Button {
                    model.add(place)
                    query = ""
                    open(place)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.headline)
                            if !place.subtitle.isEmpty {
                                Text(place.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        Spacer()
                        if model.places.contains(where: { $0.id == place.id }) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Searches after a moment's pause in typing; a new query cancels it.
    private func search(_ name: String) async {
        searchFailure = nil
        guard !name.isEmpty else {
            found = []
            return
        }
        isSearching = true
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard !Task.isCancelled else { return }
        do {
            let places = try await model.search(name)
            guard !Task.isCancelled else { return }
            found = places
        } catch {
            guard !Task.isCancelled else { return }
            found = []
            searchFailure = (error as? WeatherError)?.message ?? error.localizedDescription
        }
        isSearching = false
    }
}

/// A place in the list: its time, its weather now, and today's high and
/// low.
struct PlaceRow: View {

    @EnvironmentObject private var model: WeatherModel

    let place: Place

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let forecast = model.forecast(for: place), let now = model.now(at: place) {
                let reading = forecast.reading(at: now)
                WeatherGlyphView(glyph: reading.condition.glyph(isDay: reading.isDay), size: 30)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(WeatherText.temperature(reading.temperature, in: model.units))
                        .font(.system(size: 30, weight: .light))
                        .monospacedDigit()
                    if let today = forecast.day(at: now) {
                        Text(WeatherText.highLow(high: today.high, low: today.low, in: model.units))
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            } else if model.loading.contains(place.id) {
                ProgressView()
            } else if model.failures[place.id] != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var detail: String {
        guard let forecast = model.forecast(for: place), let now = model.now(at: place) else {
            if let failure = model.failures[place.id] { return failure }
            return place.subtitle
        }
        let reading = forecast.reading(at: now)
        return "\(WeatherText.time(now, uses24Hour: model.uses24Hour)) · \(reading.condition.name(isDay: reading.isDay))"
    }
}

#endif
