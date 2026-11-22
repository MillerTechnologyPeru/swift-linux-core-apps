//
//  MapsApp.swift
//  CoreApps
//

// The maps fetch their tiles, searches and routes over HTTP, which a guest
// can't yet: a program for now, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation
import MapsCore

/// The maps.
public struct MapsApp: App {

    /// A place to find at launch: `maps British Museum`.
    private let finding: String?

    public init() {
        // Only Cacao's program reads its arguments: Apple's systems pass
        // their own to an app.
        #if Native
        let arguments = CommandLine.arguments.dropFirst()
        finding = arguments.isEmpty ? nil : arguments.joined(separator: " ")
        #else
        finding = nil
        #endif
    }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Maps") {
            MapsView(finding: finding)
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            MapsView(finding: finding)
        }
        #endif
    }
}

/// The map, with a search above it and a card below for the place picked
/// or the directions to it.
public struct MapsView: View {

    @StateObject private var model = MapModel()

    @State private var query = ""

    @State private var showsSaved = false

    private let finding: String?

    public init(finding: String? = nil) {
        self.finding = finding
    }

    public var body: some View {
        ZStack {
            MapCanvas()
                .ignoresSafeArea()
            VStack(spacing: 8) {
                if model.directions == nil {
                    searchBar
                    if showsSaved {
                        savedPanel
                    } else if !model.results.isEmpty || model.isSearching || model.searchFailure != nil {
                        resultsPanel
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(OpenStreetMap.attribution)
                        .font(.caption2)
                        .foregroundStyle(Color.black.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.8)))
                    Spacer()
                    zoomButtons
                }
                if let directions = model.directions {
                    DirectionsCard(directions: directions)
                } else if let place = model.selected {
                    placeCard(place)
                }
            }
            .padding(Metrics.screenPadding / 2)
        }
        // The map's light tiles go with light cards.
        .preferredColorScheme(.light)
        .environmentObject(model)
        .task {
            if let finding {
                query = finding
                await model.find(finding)
            }
        }
    }

    // MARK: Searching

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.secondary)
            TextField("Search for a place", text: $query)
                // The card is the field's frame.
                .textFieldStyle(.plain)
                .onSubmit {
                    showsSaved = false
                    Task { await model.find(query) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    model.clearResults()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                showsSaved.toggle()
            } label: {
                Image(systemName: "star")
                    .foregroundStyle(showsSaved ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: Metrics.minimumTarget)
        .background(Card.background)
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let failure = model.searchFailure {
                Text(failure)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .padding()
            } else {
                placeList(model.results) { place in
                    model.show(place)
                }
            }
        }
        .background(Card.background)
    }

    private var savedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.savedPlaces.isEmpty {
                Text("Places you save are kept here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .padding()
            } else {
                placeList(model.savedPlaces) { place in
                    showsSaved = false
                    model.show(place)
                }
            }
        }
        .background(Card.background)
    }

    private func placeList(_ places: [MapPlace], pick: @escaping (MapPlace) -> Void) -> some View {
        PlaceList(places: places, maxHeight: 260, pick: pick)
    }

    // MARK: Moving

    private var zoomButtons: some View {
        VStack(spacing: 0) {
            Button {
                model.zoom(by: 2)
            } label: {
                Image(systemName: "plus")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 28, height: 1)
            Button {
                model.zoom(by: 0.5)
            } label: {
                Image(systemName: "minus")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.primary)
        .background(Card.background)
    }

    // MARK: A place

    private func placeCard(_ place: MapPlace) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Text([place.kindName, place.address].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 8)
                Button {
                    model.selected = nil
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            Text(MapsText.coordinate(place.coordinate))
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            HStack(spacing: 10) {
                Card.button("Directions", prominent: true) { model.directions(to: place) }
                Card.button(model.isSaved(place) ? "Saved" : "Save", prominent: false) { model.toggleSaved(place) }
            }
        }
        .padding(14)
        .background(Card.background)
    }
}

/// Places to pick from: a few as they are, more in a scroll view no
/// taller than `maxHeight`, which would otherwise fill it.
struct PlaceList: View {

    let places: [MapPlace]

    let maxHeight: CGFloat

    let pick: (MapPlace) -> Void

    var body: some View {
        if places.count <= 4 {
            rows
        } else {
            ScrollView { rows }
                .frame(maxHeight: maxHeight)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(places) { place in
                Button {
                    pick(place)
                } label: {
                    PlaceRow(place: place)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A place in a list: its name, and what and where it is.
struct PlaceRow: View {

    let place: MapPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .lineLimit(1)
            Text([place.kindName, place.address].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Directions to a place: the start to search for, how to travel, and
/// the route's steps.
struct DirectionsCard: View {

    @EnvironmentObject private var model: MapModel

    let directions: Directions

    @State private var originQuery = ""

    @State private var originResults: [MapPlace] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("To \(directions.destination.name)")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    model.endDirections()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            Picker("Travel", selection: Binding(
                get: { directions.mode },
                set: { mode in Task { await model.setMode(mode) } }
            )) {
                ForEach(TravelMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            if let origin = directions.origin {
                HStack {
                    Text("From \(origin.name)")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Swap") { Task { await model.reverse() } }
                        .font(.subheadline)
                    Button("Change") {
                        model.directions?.origin = nil
                        model.directions?.route = nil
                    }
                    .font(.subheadline)
                }
                routeDetails
            } else {
                originSearch
            }
        }
        .padding(14)
        .background(Card.background)
    }

    private var originSearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Starting point", text: $originQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { originResults = await model.search(originQuery) }
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            if model.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if !originResults.isEmpty {
                PlaceList(places: originResults, maxHeight: 200) { place in
                    originResults = []
                    Task { await model.setOrigin(place) }
                }
            } else if let failure = model.searchFailure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            } else {
                Text("Search for where you're starting from.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var routeDetails: some View {
        if directions.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if let failure = directions.failure {
            Text(failure)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        } else if let route = directions.route {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MapsText.duration(route.duration))
                    .font(.title2.weight(.semibold))
                Text(MapsText.distance(route.distance, usesMiles: model.usesMiles))
                    .foregroundStyle(Color.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(route.steps.enumerated()), id: \.offset) { _, step in
                        HStack(alignment: .top) {
                            Text(step.instruction)
                                .font(.subheadline)
                            Spacer(minLength: 8)
                            if step.distance > 0 {
                                Text(MapsText.distance(step.distance, usesMiles: model.usesMiles))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }
}

/// The cards over the map.
@MainActor
enum Card {

    static var background: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 1)
    }

    static func button(_ title: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(prominent ? Color.white : Color.accentColor)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(prominent ? Color.accentColor : Color.accentColor.opacity(0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#endif
