//
//  Services.swift
//  CoreApps
//

/// A place on the map: one found by a search, or one kept.
public struct MapPlace: Identifiable, Hashable, Codable, Sendable {

    public var id: String

    public var name: String

    /// Where it is, in words: the street, town and country.
    public var address: String

    public var coordinate: Coordinate

    /// What it is: `museum`, `city`, `restaurant`.
    public var kind: String

    public init(id: String, name: String, address: String, coordinate: Coordinate, kind: String = "") {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.kind = kind
    }

    /// What it is in words: `Museum`, `Bus stop`.
    public var kindName: String {
        guard let first = kind.first else { return "" }
        return String(first).uppercased() + String(kind.dropFirst()).replacingAll("_", with: " ")
    }
}

/// One of Nominatim's results, as its `jsonv2` format gives it.
public struct NominatimResult: Decodable, Sendable {

    public var placeID: Int?
    public var lat: String
    public var lon: String
    public var name: String?
    public var displayName: String
    public var category: String?
    public var type: String?

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case lat
        case lon
        case name
        case displayName = "display_name"
        case category
        case type
    }

    /// The result as a place: named by its own name, or the first part of
    /// its address, with the rest of the address after.
    public var place: MapPlace? {
        guard let latitude = Double(lat), let longitude = Double(lon) else { return nil }
        let parts = displayName.split(separator: ",").map { String($0).trimmed }
        let name = (self.name?.isEmpty == false ? self.name : nil) ?? parts.first ?? displayName
        let rest = parts.first == name ? Array(parts.dropFirst()) : parts
        return MapPlace(
            id: placeID.map { "nominatim:\($0)" } ?? "\(lat),\(lon)",
            name: name,
            address: rest.joined(separator: ", "),
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            kind: type ?? ""
        )
    }
}

/// How to get somewhere.
public enum TravelMode: String, CaseIterable, Codable, Sendable {
    case car
    case bike
    case foot

    public var title: String {
        switch self {
        case .car: "Drive"
        case .bike: "Cycle"
        case .foot: "Walk"
        }
    }
}

/// A way from one place to another.
public struct Route: Equatable, Sendable {

    /// Metres.
    public var distance: Double

    /// Seconds.
    public var duration: Double

    public var path: [Coordinate]

    public var steps: [RouteStep]
}

/// One instruction of a route.
public struct RouteStep: Equatable, Sendable {

    public var instruction: String

    /// Metres until the next one.
    public var distance: Double

    public var location: Coordinate
}

/// An OSRM `route` response.
public struct OSRMResponse: Decodable, Sendable {

    public var code: String
    public var message: String?
    public var routes: [OSRMRoute]?

    public struct OSRMRoute: Decodable, Sendable {
        public var distance: Double
        public var duration: Double
        public var geometry: String
        public var legs: [Leg]
    }

    public struct Leg: Decodable, Sendable {
        public var steps: [Step]
    }

    public struct Step: Decodable, Sendable {
        public var name: String?
        public var ref: String?
        public var distance: Double
        public var maneuver: Maneuver
        public var rotaryName: String?

        enum CodingKeys: String, CodingKey {
            case name, ref, distance, maneuver
            case rotaryName = "rotary_name"
        }
    }

    public struct Maneuver: Decodable, Sendable {
        public var type: String
        public var modifier: String?
        public var location: [Double]
        public var bearingAfter: Double?
        public var exit: Int?

        enum CodingKeys: String, CodingKey {
            case type, modifier, location, exit
            case bearingAfter = "bearing_after"
        }
    }

    /// The first route, with its steps in words.
    public var route: Route? {
        guard code == "Ok", let first = routes?.first else { return nil }
        let steps = first.legs.flatMap(\.steps).map { step in
            RouteStep(
                instruction: Self.instruction(step),
                distance: step.distance,
                location: Coordinate(
                    latitude: step.maneuver.location.count > 1 ? step.maneuver.location[1] : 0,
                    longitude: step.maneuver.location.first ?? 0
                )
            )
        }
        return Route(distance: first.distance, duration: first.duration, path: Polyline.decode(first.geometry), steps: steps)
    }

    /// A step in words, from its maneuver: `Turn left onto High Street`.
    static func instruction(_ step: Step) -> String {
        let maneuver = step.maneuver
        let road = [step.name, step.ref].compactMap { $0 }.first { !$0.isEmpty }
        let onto = road.map { " onto \($0)" } ?? ""
        let direction = maneuver.modifier.map(Self.direction) ?? ""
        switch maneuver.type {
        case "depart":
            let heading = maneuver.bearingAfter.map { "Head \(MapsText.cardinal($0))" } ?? "Start"
            return heading + (road.map { " on \($0)" } ?? "")
        case "arrive":
            switch maneuver.modifier {
            case "left": return "Arrive at the destination, on the left"
            case "right": return "Arrive at the destination, on the right"
            default: return "Arrive at the destination"
            }
        case "turn", "end of road":
            if maneuver.modifier == "uturn" { return "Make a U-turn" + onto }
            return "Turn \(direction)" + onto
        case "new name":
            return "Continue" + onto
        case "continue":
            if maneuver.modifier == "uturn" { return "Make a U-turn" + onto }
            return maneuver.modifier == "straight" || maneuver.modifier == nil ? "Continue" + onto : "Keep \(direction)" + onto
        case "merge":
            return "Merge" + (direction.isEmpty ? "" : " \(direction)") + onto
        case "on ramp":
            return "Take the ramp" + (direction.isEmpty ? "" : " on the \(direction)") + onto
        case "off ramp":
            return "Take the exit" + (direction.isEmpty ? "" : " on the \(direction)") + onto
        case "fork":
            return "Keep \(direction.isEmpty ? "straight" : direction) at the fork" + onto
        case "roundabout", "rotary":
            let place = step.rotaryName.map { " \($0)" } ?? " the roundabout"
            if let exit = maneuver.exit { return "At\(place), take the \(MapsText.ordinal(exit)) exit" + onto }
            return "Go round\(place)" + onto
        case "roundabout turn", "exit roundabout", "exit rotary":
            return "Leave the roundabout" + onto
        default:
            return "Continue" + onto
        }
    }

    static func direction(_ modifier: String) -> String {
        switch modifier {
        case "sharp left": "sharply left"
        case "sharp right": "sharply right"
        case "slight left": "slightly left"
        case "slight right": "slightly right"
        case "straight": "straight"
        case "uturn": "around"
        default: modifier
        }
    }
}

/// The services' addresses: OpenStreetMap's tiles, Nominatim's search and
/// FOSSGIS's OSRM routing, all free and without a key.
public enum OpenStreetMap {

    /// The tile server's address template.
    public static let tiles = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"

    /// The attribution OpenStreetMap's licence asks for, on the map.
    public static let attribution = "© OpenStreetMap contributors"

    /// Places matching `query`: only those within `area` when it's given
    /// and `bounded`, or those in it first when not.
    public static func searchURL(
        _ query: String, area: (west: Double, north: Double, east: Double, south: Double)? = nil,
        bounded: Bool = false, limit: Int = 10
    ) -> String {
        var url = "https://nominatim.openstreetmap.org/search?q=\(percentEncoded(query))&format=jsonv2&limit=\(limit)"
        if let area {
            url += "&viewbox=\(area.west),\(area.north),\(area.east),\(area.south)"
            if bounded { url += "&bounded=1" }
        }
        return url
    }

    /// What's at a coordinate.
    public static func reverseURL(_ coordinate: Coordinate) -> String {
        "https://nominatim.openstreetmap.org/reverse?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&format=jsonv2&zoom=18"
    }

    /// A route between two places.
    public static func routeURL(from: Coordinate, to: Coordinate, mode: TravelMode) -> String {
        "https://routing.openstreetmap.de/routed-\(mode.rawValue)/route/v1/driving/"
            + "\(from.longitude),\(from.latitude);\(to.longitude),\(to.latitude)"
            + "?overview=full&geometries=polyline&steps=true"
    }

    /// `text` with everything but letters, digits and `-._~` escaped.
    public static func percentEncoded(_ text: String) -> String {
        let hex = Array("0123456789ABCDEF")
        var result = ""
        for byte in text.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"), UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "~"):
                result.append(Character(Unicode.Scalar(byte)))
            default:
                result.append("%")
                result.append(hex[Int(byte >> 4)])
                result.append(hex[Int(byte & 0xF)])
            }
        }
        return result
    }
}

extension String {

    var trimmed: String {
        var scalars = Substring(self)
        while let first = scalars.first, first.isWhitespace { scalars.removeFirst() }
        while let last = scalars.last, last.isWhitespace { scalars.removeLast() }
        return String(scalars)
    }
}
