//
//  Viewport.swift
//  CoreApps
//

// The C library's trigonometry, for the projection: no Foundation.
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// A place on Earth, in degrees.
public struct Coordinate: Hashable, Codable, Sendable {

    public var latitude: Double

    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// A point on the screen, in points from the top left.
public struct ScreenPoint: Hashable, Sendable {

    public var x: Double

    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Web Mercator, the projection map tiles are drawn in: the world as a
/// square from 0 to 1 on each side, north at the top.
public enum Mercator {

    /// The latitude where the square ends, north and south.
    public static let maxLatitude = 85.051_128_779_806_59

    /// Where a coordinate falls on the unit square.
    public static func project(_ coordinate: Coordinate) -> (x: Double, y: Double) {
        let latitude = min(maxLatitude, max(-maxLatitude, coordinate.latitude))
        let x = (coordinate.longitude + 180) / 360
        let radians = latitude * .pi / 180
        let y = (1 - log(tan(radians) + 1 / cos(radians)) / .pi) / 2
        return (x, y)
    }

    /// The coordinate at a point on the unit square.
    public static func unproject(x: Double, y: Double) -> Coordinate {
        let longitude = x * 360 - 180
        let n = Double.pi - 2 * Double.pi * y
        let latitude = 180 / Double.pi * atan(0.5 * (exp(n) - exp(-n)))
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}

/// A map tile: its zoom level and its column and row there.
public struct TileKey: Hashable, Sendable, CustomStringConvertible {

    public var zoom: Int

    public var x: Int

    public var y: Int

    public init(zoom: Int, x: Int, y: Int) {
        self.zoom = zoom
        self.x = x
        self.y = y
    }

    /// The tile's address from a template with `{z}`, `{x}` and `{y}` in it.
    public func url(_ template: String) -> String {
        template
            .replacingAll("{z}", with: String(zoom))
            .replacingAll("{x}", with: String(x))
            .replacingAll("{y}", with: String(y))
    }

    public var description: String { "\(zoom)/\(x)/\(y)" }
}

/// A tile where the screen shows it.
public struct PlacedTile: Hashable, Sendable {

    public var key: TileKey

    /// Its top-left corner on the screen.
    public var origin: ScreenPoint

    /// Its width and height on the screen.
    public var size: Double
}

/// What part of the map the screen shows: a center and a zoom level, at
/// which the world is 256 × 2^zoom points across.
public struct Viewport: Hashable, Codable, Sendable {

    public var center: Coordinate

    public var zoom: Double

    public static let tileSize = 256.0

    public static let zoomRange = 1.0...19.0

    public init(center: Coordinate, zoom: Double) {
        self.center = center
        self.zoom = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom))
    }

    /// The world's width in points at this zoom.
    public var worldSize: Double {
        Self.tileSize * pow(2, zoom)
    }

    /// Where a coordinate is on the screen.
    public func point(of coordinate: Coordinate, width: Double, height: Double) -> ScreenPoint {
        let center = Mercator.project(self.center)
        let point = Mercator.project(coordinate)
        var dx = point.x - center.x
        // The shorter way round: a place across the date line is near.
        if dx > 0.5 { dx -= 1 } else if dx < -0.5 { dx += 1 }
        return ScreenPoint(x: width / 2 + dx * worldSize, y: height / 2 + (point.y - center.y) * worldSize)
    }

    /// The coordinate at a point on the screen.
    public func coordinate(at point: ScreenPoint, width: Double, height: Double) -> Coordinate {
        let center = Mercator.project(self.center)
        let x = center.x + (point.x - width / 2) / worldSize
        let y = center.y + (point.y - height / 2) / worldSize
        return Self.wrapped(Mercator.unproject(x: x, y: min(1, max(0, y))))
    }

    /// The map moved with a finger: the ground under it follows it by
    /// `dx`, `dy` points.
    public func panned(dx: Double, dy: Double) -> Viewport {
        let center = Mercator.project(self.center)
        let x = center.x - dx / worldSize
        // The poles stop the map; it goes round east and west.
        let y = min(1, max(0, center.y - dy / worldSize))
        return Viewport(center: Self.wrapped(Mercator.unproject(x: x, y: y)), zoom: zoom)
    }

    /// Zoomed by `factor` (2 to zoom in a level) keeping the ground at
    /// `anchor` where it is on the screen.
    public func zoomed(by factor: Double, around anchor: ScreenPoint, width: Double, height: Double) -> Viewport {
        let target = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom + log2(max(factor, 0.0001))))
        let fixed = coordinate(at: anchor, width: width, height: height)
        var zoomed = Viewport(center: center, zoom: target)
        // Move so the anchored ground is back under the anchor.
        let moved = zoomed.point(of: fixed, width: width, height: height)
        zoomed = zoomed.panned(dx: anchor.x - moved.x, dy: anchor.y - moved.y)
        return zoomed
    }

    /// The tiles that cover a screen of this size, at the nearest zoom
    /// level, scaled to fit: never more than 1.41 times their size, so
    /// their text stays sharp.
    public func tiles(width: Double, height: Double) -> [PlacedTile] {
        let level = min(Int(Self.zoomRange.upperBound), Int(zoom.rounded()))
        let count = 1 << level
        let scale = pow(2, zoom - Double(level))
        let size = Self.tileSize * scale
        let center = Mercator.project(self.center)
        // The screen's top-left corner in tile units at this level.
        let left = center.x * Double(count) - width / 2 / size
        let top = center.y * Double(count) - height / 2 / size
        let firstColumn = Int(left.rounded(.down))
        let firstRow = max(0, Int(top.rounded(.down)))
        let lastColumn = Int((left + width / size).rounded(.up)) - 1
        let lastRow = min(count - 1, Int((top + height / size).rounded(.up)) - 1)
        guard firstRow <= lastRow, firstColumn <= lastColumn else { return [] }
        var tiles: [PlacedTile] = []
        for row in firstRow...lastRow {
            for column in firstColumn...lastColumn {
                let x = ((column % count) + count) % count
                tiles.append(PlacedTile(
                    key: TileKey(zoom: level, x: x, y: row),
                    origin: ScreenPoint(x: (Double(column) - left) * size, y: (Double(row) - top) * size),
                    size: size
                ))
            }
        }
        return tiles
    }

    /// A viewport that shows all the coordinates, with `padding` points
    /// around them, no closer than `maxZoom`.
    public static func fitting(_ coordinates: [Coordinate], width: Double, height: Double, padding: Double = 40, maxZoom: Double = 17) -> Viewport? {
        guard let first = coordinates.first else { return nil }
        let points = coordinates.map(Mercator.project)
        var minX = points[0].x, maxX = points[0].x, minY = points[0].y, maxY = points[0].y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let spanX = max(maxX - minX, 1e-9)
        let spanY = max(maxY - minY, 1e-9)
        let usableWidth = max(1, width - 2 * padding)
        let usableHeight = max(1, height - 2 * padding)
        let zoom = log2(min(usableWidth / (spanX * tileSize), usableHeight / (spanY * tileSize)))
        let center = coordinates.count == 1 ? first : Mercator.unproject(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        return Viewport(center: center, zoom: min(maxZoom, zoom))
    }

    /// Longitudes kept to -180…180.
    static func wrapped(_ coordinate: Coordinate) -> Coordinate {
        var longitude = coordinate.longitude.truncatingRemainder(dividingBy: 360)
        if longitude > 180 { longitude -= 360 } else if longitude < -180 { longitude += 360 }
        return Coordinate(latitude: coordinate.latitude, longitude: longitude)
    }
}

/// Google's encoded polyline format, which OSRM gives routes in.
public enum Polyline {

    /// The coordinates in an encoded polyline, with `precision` decimal
    /// places (5 for OSRM's `polyline`, 6 for `polyline6`).
    public static func decode(_ text: String, precision: Int = 5) -> [Coordinate] {
        let factor = pow(10, Double(precision))
        var coordinates: [Coordinate] = []
        var latitude = 0
        var longitude = 0
        var bytes = Array(text.utf8)[...]
        func next() -> Int? {
            var result = 0
            var shift = 0
            while let byte = bytes.popFirst() {
                let chunk = Int(byte) - 63
                guard chunk >= 0 else { return nil }
                result |= (chunk & 0x1F) << shift
                shift += 5
                if chunk < 0x20 {
                    return (result & 1) != 0 ? ~(result >> 1) : result >> 1
                }
            }
            return nil
        }
        while !bytes.isEmpty {
            guard let dLatitude = next(), let dLongitude = next() else { break }
            latitude += dLatitude
            longitude += dLongitude
            coordinates.append(Coordinate(latitude: Double(latitude) / factor, longitude: Double(longitude) / factor))
        }
        return coordinates
    }

    /// The coordinates encoded, the other way.
    public static func encode(_ coordinates: [Coordinate], precision: Int = 5) -> String {
        let factor = pow(10, Double(precision))
        var result = ""
        var lastLatitude = 0
        var lastLongitude = 0
        func append(_ value: Int) {
            var value = value < 0 ? ~(value << 1) : value << 1
            while value >= 0x20 {
                result.append(Character(Unicode.Scalar(UInt8((0x20 | (value & 0x1F)) + 63))))
                value >>= 5
            }
            result.append(Character(Unicode.Scalar(UInt8(value + 63))))
        }
        for coordinate in coordinates {
            let latitude = Int((coordinate.latitude * factor).rounded())
            let longitude = Int((coordinate.longitude * factor).rounded())
            append(latitude - lastLatitude)
            append(longitude - lastLongitude)
            lastLatitude = latitude
            lastLongitude = longitude
        }
        return result
    }
}

extension String {

    /// The string with every `target` replaced.
    func replacingAll(_ target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }
        var result = ""
        var rest = self[...]
        while let range = rest.range(of: target) {
            result += rest[..<range.lowerBound]
            result += replacement
            rest = rest[range.upperBound...]
        }
        return result + rest
    }
}

extension Substring {

    /// Where `target` first is, by its characters.
    func range(of target: String) -> Range<Index>? {
        let needle = Array(target)
        guard !needle.isEmpty else { return nil }
        var index = startIndex
        while index < endIndex {
            if self[index] == needle[0] {
                var probe = index
                var matched = 0
                while probe < endIndex, matched < needle.count, self[probe] == needle[matched] {
                    probe = self.index(after: probe)
                    matched += 1
                }
                if matched == needle.count { return index..<probe }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
