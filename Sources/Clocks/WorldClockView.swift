//
//  WorldClockView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ClocksCore
import CoreAppsUI
import Foundation

/// The time here and in the places the user keeps.
struct WorldClockView: View {

    @EnvironmentObject private var model: ClocksModel

    @State private var isAdding = false

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            List {
                Section("Here") {
                    row(TimeZone.current.identifier, at: context.date, isHere: true)
                }
                if !model.cities.isEmpty {
                    Section("Places") {
                        ForEach(model.cities, id: \.self) { identifier in
                            row(identifier, at: context.date, isHere: false)
                                .contextMenu {
                                    Button("Remove", role: .destructive) {
                                        model.cities.removeAll { $0 == identifier }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("World Clock")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add a Place") { isAdding = true }
                    Toggle("24-Hour Time", isOn: $model.uses24Hour)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            PlacePicker(chosen: Set(model.cities)) { identifier in
                isAdding = false
                if let identifier, !model.cities.contains(identifier) {
                    model.cities.append(identifier)
                }
            }
        }
    }

    private func row(_ identifier: String, at date: Date, isHere: Bool) -> some View {
        let zone = TimeZone(identifier: identifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute, .day], from: date)
        let here = Calendar.current.dateComponents([.day, .month, .year], from: date)
        let there = calendar.dateComponents([.day, .month, .year], from: date)
        let dayDifference = Self.dayNumber(there) - Self.dayNumber(here)
        let offset = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        let detail = isHere
            ? (zone.abbreviation(for: date) ?? identifier)
            : "\(TimeText.day(dayDifference)), \(TimeText.offset(offset).lowercased())"
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isHere ? TimeText.city(identifier) : TimeText.city(identifier))
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Text(TimeText.timeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0, uses24Hour: model.uses24Hour))
                .font(.system(size: 32, weight: .light).monospacedDigit())
        }
        .frame(minHeight: Metrics.minimumTarget)
    }

    /// A date's day, counted so that consecutive days differ by one.
    private static func dayNumber(_ parts: DateComponents) -> Int {
        (parts.year ?? 0) * 372 + (parts.month ?? 0) * 31 + (parts.day ?? 0)
    }
}

/// Picks a place to add, from the system's time zones.
struct PlacePicker: View {

    /// The places already shown, which aren't offered again.
    let chosen: Set<String>

    /// Called with the place's time zone, or `nil` if none was picked.
    let done: (String?) -> Void

    @State private var searchText = ""

    private static let identifiers = TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") && !$0.hasPrefix("Etc/") && !$0.hasPrefix("SystemV/") }
        .sorted { TimeText.city($0) < TimeText.city($1) }

    var body: some View {
        let wanted = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let places = Self.identifiers.filter { identifier in
            !chosen.contains(identifier)
                && (wanted.isEmpty || TimeText.city(identifier).lowercased().contains(wanted) || identifier.lowercased().contains(wanted))
        }
        return NavigationStack {
            List {
                ForEach(places.prefix(300), id: \.self) { identifier in
                    Button {
                        done(identifier)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TimeText.city(identifier))
                                .foregroundStyle(Color.primary)
                            Text(TimeText.region(identifier))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: Metrics.minimumTarget - 8, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .plainButton()
                }
            }
            .searchable(text: $searchText, prompt: Text("Search places"))
            .navigationTitle("Add a Place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(nil) }
                }
            }
        }
    }
}

#endif
