//
//  MapCanvas.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import MapsCore

/// The map: tiles placed by the viewport, a route over them, and pins.
/// A finger pans it, two pinch it, and a double tap zooms in.
struct MapCanvas: View {

    @EnvironmentObject private var model: MapModel

    @StateObject private var tiles = TileStore()

    @State private var lastDrag: CGSize = .zero

    @State private var lastMagnification: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let width = Double(geometry.size.width)
            let height = Double(geometry.size.height)
            let placed = model.viewport.tiles(width: width, height: height)
            ZStack(alignment: .topLeading) {
                Color(red: 0.93, green: 0.92, blue: 0.89)
                ForEach(placed, id: \.key) { tile in
                    tileView(tile)
                }
                if let route = model.directions?.route {
                    routeLine(route, width: width, height: height)
                }
                pins(width: width, height: height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let dx = Double(value.translation.width - lastDrag.width)
                        let dy = Double(value.translation.height - lastDrag.height)
                        lastDrag = value.translation
                        model.viewport = model.viewport.panned(dx: dx, dy: dy)
                    }
                    .onEnded { _ in lastDrag = .zero }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let factor = Double(value.magnification / lastMagnification)
                        lastMagnification = value.magnification
                        model.zoom(by: factor)
                    }
                    .onEnded { _ in lastMagnification = 1 }
            )
            .onTapGesture(count: 2) {
                model.zoom(by: 2)
            }
            .onAppear {
                model.size = (width, height)
                tiles.request(placed.map(\.key))
            }
            .onChange(of: model.viewport) { _, viewport in
                tiles.request(viewport.tiles(width: width, height: height).map(\.key))
            }
            .onChange(of: geometry.size) { _, size in
                model.size = (Double(size.width), Double(size.height))
                tiles.request(model.viewport.tiles(width: Double(size.width), height: Double(size.height)).map(\.key))
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: PlacedTile) -> some View {
        // A hair over size, so seams between tiles don't show.
        let side = CGFloat(tile.size) + 0.5
        let x = CGFloat(tile.origin.x + tile.size / 2)
        let y = CGFloat(tile.origin.y + tile.size / 2)
        if let image = tiles.images[tile.key] {
            image
                .resizable()
                .frame(width: side, height: side)
                .position(x: x, y: y)
        } else {
            Rectangle()
                .fill(Color(red: 0.9, green: 0.89, blue: 0.86))
                .frame(width: side, height: side)
                .position(x: x, y: y)
        }
    }

    private func routeLine(_ route: Route, width: Double, height: Double) -> some View {
        let points = route.path.map { model.viewport.point(of: $0, width: width, height: height) }
        return Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x, y: first.y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
        }
        .stroke(Color(red: 0.16, green: 0.45, blue: 0.95), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func pins(width: Double, height: Double) -> some View {
        if let directions = model.directions {
            if let origin = directions.origin {
                pin(at: origin.coordinate, color: Color(red: 0.2, green: 0.7, blue: 0.35), width: width, height: height)
            }
            pin(at: directions.destination.coordinate, color: Color.red, width: width, height: height)
        } else if let selected = model.selected {
            pin(at: selected.coordinate, color: Color.red, width: width, height: height)
        }
    }

    private func pin(at coordinate: Coordinate, color: Color, width: Double, height: Double) -> some View {
        let point = model.viewport.point(of: coordinate, width: width, height: height)
        return Circle()
            .fill(color)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(radius: 2)
            .position(x: CGFloat(point.x), y: CGFloat(point.y))
            .allowsHitTesting(false)
    }
}

#endif
