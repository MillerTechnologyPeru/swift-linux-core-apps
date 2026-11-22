//
//  MapsService.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MapsCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Why a search or route failed.
enum MapsError: Error, Equatable {
    case offline(String)
    case server(Int)
    case unreadable
    case noRoute(String?)

    var message: String {
        switch self {
        case let .offline(reason): reason
        case let .server(status): "The map service answered with an error (\(status))."
        case .unreadable: "The map service sent something that couldn't be read."
        case let .noRoute(reason): reason ?? "There's no route between those places."
        }
    }
}

/// Fetches from OpenStreetMap's services.
///
/// Their usage policies ask each app to say who it is, to keep the tiles
/// it fetches, and to search no more than once a second.
struct MapsService: Sendable {

    static let userAgent = "SwiftLinuxMaps/0.1 (+https://github.com/MillerTechnologyPeru/swift-linux-core-apps)"

    /// The tile server, which `MAPS_TILE_URL` can change, as a template.
    static let tileTemplate = ProcessInfo.processInfo.environment["MAPS_TILE_URL"] ?? OpenStreetMap.tiles

    func search(_ query: String, area: (west: Double, north: Double, east: Double, south: Double)?, bounded: Bool) async throws -> [MapPlace] {
        let data = try await fetch(OpenStreetMap.searchURL(query, area: area, bounded: bounded))
        guard let results = try? JSONDecoder().decode([NominatimResult].self, from: data) else { throw MapsError.unreadable }
        return results.compactMap(\.place)
    }

    func route(from: Coordinate, to: Coordinate, mode: TravelMode) async throws -> Route {
        let data = try await fetch(OpenStreetMap.routeURL(from: from, to: to, mode: mode), allowing: [400])
        guard let response = try? JSONDecoder().decode(OSRMResponse.self, from: data) else { throw MapsError.unreadable }
        guard let route = response.route else { throw MapsError.noRoute(response.message) }
        return route
    }

    func tile(_ key: TileKey) async throws -> Data {
        try await fetch(key.url(Self.tileTemplate))
    }

    private func fetch(_ address: String, allowing statuses: Set<Int> = []) async throws -> Data {
        guard let url = URL(string: address) else { throw MapsError.unreadable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: MapsError.offline(error.localizedDescription))
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: MapsError.unreadable)
                }
            }.resume()
        }
        if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status), !statuses.contains(status) {
            throw MapsError.server(status)
        }
        return data
    }
}

/// The map's tiles: those drawn, kept in memory, and those fetched, kept
/// on disk so a place seen before draws again without the network.
@MainActor
final class TileStore: ObservableObject {

    @Published private(set) var images: [TileKey: Image] = [:]

    private var loading: Set<TileKey> = []

    private var failed: [TileKey: Date] = [:]

    /// Tiles in memory, oldest first, to let go of the oldest.
    private var order: [TileKey] = []

    private let service = MapsService()

    private let folder: URL

    static let memoryLimit = 400

    init() {
        #if canImport(Darwin)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        #else
        var base = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(".cache", isDirectory: true)
        if let path = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"], path.hasPrefix("/") {
            base = URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        folder = base.appendingPathComponent("maps", isDirectory: true).appendingPathComponent("tiles", isDirectory: true)
    }

    /// Fetches the tiles not yet here.
    func request(_ keys: [TileKey]) {
        for key in keys where images[key] == nil && !loading.contains(key) {
            if let failure = failed[key], Date().timeIntervalSince(failure) < 30 { continue }
            loading.insert(key)
            Task { await load(key) }
        }
    }

    private func load(_ key: TileKey) async {
        defer { loading.remove(key) }
        let file = folder.appendingPathComponent("\(key.zoom)/\(key.x)/\(key.y).png")
        var data = try? Data(contentsOf: file)
        if data == nil {
            do {
                let fetched = try await service.tile(key)
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fetched.write(to: file, options: .atomic)
                data = fetched
            } catch {
                failed[key] = Date()
                return
            }
        }
        guard let data, let image = Self.image(data) else {
            failed[key] = Date()
            return
        }
        images[key] = image
        order.append(key)
        if order.count > Self.memoryLimit {
            let dropped = order.removeFirst()
            images[dropped] = nil
        }
    }

    /// A tile's PNG as an image: Cacao decodes PNG itself; Apple's systems
    /// decode anything.
    static func image(_ data: Data) -> Image? {
        #if Native
        return Image(pngData: data)
        #elseif canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }
}

#endif
