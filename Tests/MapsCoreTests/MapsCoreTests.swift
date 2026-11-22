//
//  MapsCoreTests.swift
//  CoreApps
//

import Foundation
import Testing
@testable import MapsCore

func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-6) -> Bool {
    abs(a - b) <= tolerance
}

@Suite struct ProjectionTests {

    @Test func putsTheOriginInTheMiddle() {
        let point = Mercator.project(Coordinate(latitude: 0, longitude: 0))
        #expect(close(point.x, 0.5) && close(point.y, 0.5))
        let corner = Mercator.project(Coordinate(latitude: Mercator.maxLatitude, longitude: -180))
        #expect(close(corner.x, 0) && close(corner.y, 0))
    }

    @Test func goesBothWays() {
        let london = Coordinate(latitude: 51.5194, longitude: -0.127)
        let point = Mercator.project(london)
        let back = Mercator.unproject(x: point.x, y: point.y)
        #expect(close(back.latitude, london.latitude) && close(back.longitude, london.longitude))
    }

    @Test func clampsThePoles() {
        let north = Mercator.project(Coordinate(latitude: 90, longitude: 0))
        #expect(close(north.y, 0))
    }
}

@Suite struct ViewportTests {

    let london = Coordinate(latitude: 51.5194, longitude: -0.127)

    @Test func putsTheCenterInTheMiddle() {
        let viewport = Viewport(center: london, zoom: 12)
        let point = viewport.point(of: london, width: 400, height: 600)
        #expect(close(point.x, 200) && close(point.y, 300))
        let back = viewport.coordinate(at: ScreenPoint(x: 37, y: 501), width: 400, height: 600)
        let again = viewport.point(of: back, width: 400, height: 600)
        #expect(close(again.x, 37, 1e-6) && close(again.y, 501, 1e-6))
    }

    @Test func pansWithTheFinger() {
        // At zoom 1 the world is 512 points across: a quarter is 90°.
        let viewport = Viewport(center: Coordinate(latitude: 0, longitude: 0), zoom: 1).panned(dx: 128, dy: 0)
        #expect(close(viewport.center.longitude, -90))
        #expect(close(viewport.center.latitude, 0))
        let around = Viewport(center: Coordinate(latitude: 0, longitude: 170), zoom: 1).panned(dx: -128, dy: 0)
        #expect(close(around.center.longitude, -100))
    }

    @Test func zoomsAroundTheFingers() {
        let viewport = Viewport(center: london, zoom: 10)
        let centered = viewport.zoomed(by: 2, around: ScreenPoint(x: 200, y: 300), width: 400, height: 600)
        #expect(close(centered.zoom, 11))
        #expect(close(centered.center.latitude, london.latitude) && close(centered.center.longitude, london.longitude))
        let anchor = ScreenPoint(x: 50, y: 80)
        let ground = viewport.coordinate(at: anchor, width: 400, height: 600)
        let zoomed = viewport.zoomed(by: 3, around: anchor, width: 400, height: 600)
        let stays = zoomed.point(of: ground, width: 400, height: 600)
        #expect(close(stays.x, anchor.x, 1e-3) && close(stays.y, anchor.y, 1e-3))
        #expect(Viewport(center: london, zoom: 30).zoom == 19)
    }

    @Test func coversTheScreenWithTiles() {
        let viewport = Viewport(center: Coordinate(latitude: 0, longitude: 0), zoom: 1)
        let tiles = viewport.tiles(width: 512, height: 512)
        #expect(Set(tiles.map(\.key)) == [
            TileKey(zoom: 1, x: 0, y: 0), TileKey(zoom: 1, x: 1, y: 0),
            TileKey(zoom: 1, x: 0, y: 1), TileKey(zoom: 1, x: 1, y: 1),
        ])
        #expect(tiles.allSatisfy { $0.size == 256 })
        #expect(tiles.first { $0.key == TileKey(zoom: 1, x: 0, y: 0) }?.origin == ScreenPoint(x: 0, y: 0))
    }

    @Test func scalesTilesBetweenLevels() {
        let viewport = Viewport(center: Coordinate(latitude: 0, longitude: 0), zoom: 2.4)
        let tiles = viewport.tiles(width: 300, height: 300)
        #expect(tiles.allSatisfy { $0.key.zoom == 2 })
        #expect(close(tiles[0].size, 256 * pow(2, 0.4)))
        // Past halfway, the next level, drawn smaller.
        let finer = Viewport(center: Coordinate(latitude: 0, longitude: 0), zoom: 2.6).tiles(width: 300, height: 300)
        #expect(finer.allSatisfy { $0.key.zoom == 3 })
        #expect(close(finer[0].size, 256 * pow(2, -0.4)))
    }

    @Test func wrapsTilesAcrossTheDateLine() {
        let viewport = Viewport(center: Coordinate(latitude: 0, longitude: 179), zoom: 3)
        let columns = Set(viewport.tiles(width: 600, height: 256).map(\.key.x))
        #expect(columns.contains(0))
        #expect(columns.contains(7))
        #expect(columns.allSatisfy { (0..<8).contains($0) })
    }

    @Test func leavesOutRowsPastThePoles() {
        let viewport = Viewport(center: Coordinate(latitude: 80, longitude: 0), zoom: 1)
        #expect(viewport.tiles(width: 512, height: 1024).allSatisfy { (0..<2).contains($0.key.y) })
    }

    @Test func fitsCoordinates() {
        let a = Coordinate(latitude: 51.5194, longitude: -0.127)
        let b = Coordinate(latitude: 51.5007, longitude: -0.1246)
        let viewport = Viewport.fitting([a, b], width: 400, height: 600, padding: 40)
        #expect(viewport != nil)
        let top = viewport!.point(of: a, width: 400, height: 600)
        let bottom = viewport!.point(of: b, width: 400, height: 600)
        #expect(top.y >= 39.9 && bottom.y <= 560.1)
        #expect(Viewport.fitting([a], width: 400, height: 600)?.zoom == 17)
        #expect(Viewport.fitting([], width: 400, height: 600) == nil)
    }

    @Test func namesTiles() {
        #expect(TileKey(zoom: 12, x: 2046, y: 1362).url(OpenStreetMap.tiles) == "https://tile.openstreetmap.org/12/2046/1362.png")
    }
}

@Suite struct PolylineTests {

    @Test func decodesGooglesExample() {
        let points = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        #expect(points.count == 3)
        #expect(close(points[0].latitude, 38.5) && close(points[0].longitude, -120.2))
        #expect(close(points[1].latitude, 40.7) && close(points[1].longitude, -120.95))
        #expect(close(points[2].latitude, 43.252) && close(points[2].longitude, -126.453))
    }

    @Test func encodesWhatItDecodes() {
        let points = [Coordinate(latitude: 38.5, longitude: -120.2), Coordinate(latitude: 40.7, longitude: -120.95)]
        #expect(Polyline.encode(points) == "_p~iF~ps|U_ulLnnqC")
        #expect(Polyline.decode("").isEmpty)
    }
}

@Suite struct ServiceTests {

    @Test func readsNominatim() throws {
        let json = """
        [{"place_id":280311785,"lat":"51.5193118","lon":"-0.1267051","category":"tourism","type":"museum",
        "name":"British Museum","display_name":"British Museum, Great Russell Street, Bloomsbury, London, WC1B 3DG, United Kingdom"},
        {"place_id":1,"lat":"51.5","lon":"-0.12","type":"house","name":"","display_name":"10, Downing Street, London"}]
        """
        let places = try JSONDecoder().decode([NominatimResult].self, from: Data(json.utf8)).compactMap(\.place)
        #expect(places.count == 2)
        #expect(places[0].name == "British Museum")
        #expect(places[0].address == "Great Russell Street, Bloomsbury, London, WC1B 3DG, United Kingdom")
        #expect(places[0].kindName == "Museum")
        #expect(places[0].id == "nominatim:280311785")
        #expect(close(places[0].coordinate.latitude, 51.5193118))
        #expect(places[1].name == "10")
        #expect(places[1].address == "Downing Street, London")
    }

    @Test func readsAnOSRMRoute() throws {
        let json = """
        {"code":"Ok","routes":[{"distance":2291.5,"duration":1835.3,"geometry":"_p~iF~ps|U_ulLnnqC","legs":[{"steps":[
        {"name":"Great Russell Street","distance":58.8,"maneuver":{"bearing_after":145,"location":[-0.126274,51.518846],"type":"depart"}},
        {"name":"","distance":17.2,"maneuver":{"modifier":"right","location":[-0.125732,51.518468],"type":"end of road"}},
        {"name":"Bloomsbury Way","ref":"A40","distance":10.8,"maneuver":{"modifier":"slight left","location":[-0.1259,51.5183],"type":"fork"}},
        {"name":"","distance":100,"maneuver":{"exit":2,"location":[-0.1259,51.5183],"type":"roundabout"}},
        {"name":"","distance":0,"maneuver":{"modifier":"right","location":[-0.124594,51.500807],"type":"arrive"}}]}]}]}
        """
        let route = try JSONDecoder().decode(OSRMResponse.self, from: Data(json.utf8)).route
        #expect(route?.distance == 2291.5)
        #expect(route?.path.count == 2)
        #expect(route?.steps.map(\.instruction) == [
            "Head southeast on Great Russell Street",
            "Turn right",
            "Keep slightly left at the fork onto Bloomsbury Way",
            "At the roundabout, take the 2nd exit",
            "Arrive at the destination, on the right",
        ])
        #expect(close(route?.steps[0].location.latitude ?? 0, 51.518846))
    }

    @Test func saysWhenThereIsNoRoute() throws {
        let json = #"{"code":"NoRoute","message":"Impossible route between points","routes":[]}"#
        let response = try JSONDecoder().decode(OSRMResponse.self, from: Data(json.utf8))
        #expect(response.route == nil)
        #expect(response.message == "Impossible route between points")
    }

    @Test func buildsAddresses() {
        #expect(OpenStreetMap.searchURL("British Museum") == "https://nominatim.openstreetmap.org/search?q=British%20Museum&format=jsonv2&limit=10")
        #expect(OpenStreetMap.searchURL("Café", area: (west: -1, north: 52, east: 1, south: 51), limit: 5)
            == "https://nominatim.openstreetmap.org/search?q=Caf%C3%A9&format=jsonv2&limit=5&viewbox=-1.0,52.0,1.0,51.0")
        #expect(OpenStreetMap.searchURL("Café", area: (west: -1, north: 52, east: 1, south: 51), bounded: true, limit: 5)
            .hasSuffix("&viewbox=-1.0,52.0,1.0,51.0&bounded=1"))
        #expect(OpenStreetMap.routeURL(from: Coordinate(latitude: 51.5, longitude: -0.12), to: Coordinate(latitude: 51.4, longitude: -0.1), mode: .foot)
            == "https://routing.openstreetmap.de/routed-foot/route/v1/driving/-0.12,51.5;-0.1,51.4?overview=full&geometries=polyline&steps=true")
    }
}

@Suite struct MapsTextTests {

    @Test func writesDistances() {
        #expect(MapsText.distance(350, usesMiles: false) == "350 m")
        #expect(MapsText.distance(87, usesMiles: false) == "90 m")
        #expect(MapsText.distance(3, usesMiles: false) == "10 m")
        #expect(MapsText.distance(0, usesMiles: false) == "0 m")
        #expect(MapsText.distance(1234, usesMiles: false) == "1.2 km")
        #expect(MapsText.distance(12_345, usesMiles: false) == "12 km")
        #expect(MapsText.distance(30, usesMiles: true) == "100 ft")
        #expect(MapsText.distance(1609.344 * 0.3, usesMiles: true) == "0.3 mi")
        #expect(MapsText.distance(1609.344 * 12.4, usesMiles: true) == "12 mi")
    }

    @Test func writesTimes() {
        #expect(MapsText.duration(1835.3) == "31 min")
        #expect(MapsText.duration(5000) == "1 hr 23 min")
        #expect(MapsText.duration(7200) == "2 hr")
        #expect(MapsText.duration(5) == "1 min")
    }

    @Test func writesDirectionsAndPlaces() {
        #expect(MapsText.cardinal(145) == "southeast")
        #expect(MapsText.cardinal(350) == "north")
        #expect(MapsText.ordinal(2) == "2nd")
        #expect(MapsText.ordinal(11) == "11th")
        #expect(MapsText.coordinate(Coordinate(latitude: 51.5194, longitude: -0.127)) == "51.5194° N, 0.1270° W")
        #expect(MapsText.usesMiles(region: "gb"))
        #expect(!MapsText.usesMiles(region: "FR"))
    }
}
