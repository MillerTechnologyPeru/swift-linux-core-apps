//
//  WeatherService.swift
//  CoreApps
//

#if Native || Apple

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import WeatherCore

/// Why the weather couldn't be fetched.
enum WeatherError: Error, Equatable {
    case badAddress
    case offline(String)
    case server(Int)
    case unreadable

    var message: String {
        switch self {
        case .badAddress: "The forecast's address isn't valid."
        case let .offline(reason): reason
        case let .server(status): "The weather service answered with an error (\(status))."
        case .unreadable: "The weather service sent something that couldn't be read."
        }
    }
}

/// Fetches forecasts and finds places, from Open-Meteo.
struct WeatherService: Sendable {

    func forecast(for place: Place) async throws -> Forecast {
        try await fetch(OpenMeteo.forecastURL(for: place), as: Forecast.self)
    }

    func search(_ name: String) async throws -> [Place] {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        return try await fetch(OpenMeteo.searchURL(for: name, language: language), as: PlaceSearch.self).places
    }

    private func fetch<T: Decodable>(_ address: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: address) else { throw WeatherError.badAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await load(request)
        if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
            throw WeatherError.server(status)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WeatherError.unreadable
        }
    }

    /// A data task, awaited. Foundation on Linux has had no `data(for:)`
    /// in every version.
    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: WeatherError.offline(error.localizedDescription))
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: WeatherError.unreadable)
                }
            }
            task.resume()
        }
    }
}

#endif
