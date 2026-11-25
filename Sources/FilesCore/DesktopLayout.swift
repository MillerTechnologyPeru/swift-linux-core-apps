//
//  DesktopLayout.swift
//  CoreApps
//

import Foundation

/// A place for an icon on the desktop: a column from the left and a row
/// from the top of its grid.
public struct DesktopSlot: Hashable, Codable, Sendable {

    public var column: Int

    public var row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

/// Where the desktop's icons go: a grid inside the screen, clear of the
/// menu bar and the dock, filled down each column from the top left.
///
/// Icons the user has moved keep their places, by name. The rest take the
/// free places in order, so a new file lands after the others.
public struct DesktopLayout: Hashable, Sendable {

    /// How big each place is, in points.
    public var cellSize: (width: Double, height: Double)

    /// The space kept clear at each edge: under the menu bar, over the dock.
    public var insets: (top: Double, left: Double, bottom: Double, right: Double)

    /// The size of the screen, in points.
    public var size: (width: Double, height: Double)

    public init(
        size: (width: Double, height: Double),
        cellSize: (width: Double, height: Double) = (96, 92),
        insets: (top: Double, left: Double, bottom: Double, right: Double) = (44, 12, 96, 12)
    ) {
        self.size = size
        self.cellSize = cellSize
        self.insets = insets
    }

    public static func == (lhs: DesktopLayout, rhs: DesktopLayout) -> Bool {
        lhs.size == rhs.size && lhs.cellSize == rhs.cellSize && lhs.insets == rhs.insets
    }

    public func hash(into hasher: inout Hasher) {
        for value in [size.width, size.height, cellSize.width, cellSize.height, insets.top, insets.left, insets.bottom, insets.right] {
            hasher.combine(value)
        }
    }

    /// How many places fit across and down. Never fewer than one, so a
    /// tiny screen still shows its icons, overlapping.
    public var columns: Int {
        max(1, Int((size.width - insets.left - insets.right) / cellSize.width))
    }

    public var rows: Int {
        max(1, Int((size.height - insets.top - insets.bottom) / cellSize.height))
    }

    /// The middle of a place, in points from the screen's top left.
    public func center(of slot: DesktopSlot) -> (x: Double, y: Double) {
        (
            insets.left + (Double(slot.column) + 0.5) * cellSize.width,
            insets.top + (Double(slot.row) + 0.5) * cellSize.height
        )
    }

    /// The place nearest a point, kept inside the grid: where a dragged
    /// icon is dropped.
    public func slot(nearest point: (x: Double, y: Double)) -> DesktopSlot {
        let column = Int(((point.x - insets.left) / cellSize.width).rounded(.down))
        let row = Int(((point.y - insets.top) / cellSize.height).rounded(.down))
        return DesktopSlot(column: min(max(column, 0), columns - 1), row: min(max(row, 0), rows - 1))
    }

    /// The places in the order they're filled: down the first column, then
    /// the next.
    public var slots: [DesktopSlot] {
        (0 ..< columns).flatMap { column in
            (0 ..< rows).map { row in DesktopSlot(column: column, row: row) }
        }
    }

    /// Places for icons, by name.
    ///
    /// - Parameters:
    ///   - names: The icons, in the order the free places go to them.
    ///   - saved: Where icons were put before. A saved place outside the
    ///     grid, as after the screen got smaller, or one another icon
    ///     already has, is given up.
    /// - Returns: A place for every name. Once the grid is full, the rest
    ///   share its last place.
    public func arrange(_ names: [String], saved: [String: DesktopSlot] = [:]) -> [String: DesktopSlot] {
        var placed: [String: DesktopSlot] = [:]
        var taken: Set<DesktopSlot> = []
        for name in names {
            guard let slot = saved[name], slot.column < columns, slot.row < rows, slot.column >= 0, slot.row >= 0,
                  taken.insert(slot).inserted else { continue }
            placed[name] = slot
        }
        var free = slots.filter { !taken.contains($0) }.makeIterator()
        let last = DesktopSlot(column: columns - 1, row: rows - 1)
        for name in names where placed[name] == nil {
            placed[name] = free.next() ?? last
        }
        return placed
    }

    /// Moves an icon to a place. An icon already there swaps with it, so
    /// two never share one.
    public static func move(_ name: String, to slot: DesktopSlot, in placed: [String: DesktopSlot]) -> [String: DesktopSlot] {
        var placed = placed
        guard let previous = placed[name], previous != slot else { return placed }
        if let other = placed.first(where: { $0.key != name && $0.value == slot })?.key {
            placed[other] = previous
        }
        placed[name] = slot
        return placed
    }
}

/// What the desktop keeps between launches: the wallpaper, and where icons
/// were moved to.
public struct DesktopPreferences: Hashable, Codable, Sendable {

    /// The PNG drawn behind the icons; the accent gradient when `nil`.
    public var wallpaper: String?

    /// Icons the user moved, by file name.
    public var positions: [String: DesktopSlot]

    public init(wallpaper: String? = nil, positions: [String: DesktopSlot] = [:]) {
        self.wallpaper = wallpaper
        self.positions = positions
    }

    /// Where they're kept: `files/desktop.json` in `$XDG_CONFIG_HOME`,
    /// which is `~/.config` unless set.
    public static func file(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        var config = homeDirectory.appendingPathComponent(".config", isDirectory: true)
        if let path = environment["XDG_CONFIG_HOME"], path.hasPrefix("/") {
            config = URL(fileURLWithPath: path, isDirectory: true)
        }
        return config.appendingPathComponent("files/desktop.json")
    }

    /// The preferences in a file: the defaults if it's missing or can't be
    /// read.
    public static func load(from file: URL) -> DesktopPreferences {
        guard let data = try? Data(contentsOf: file),
              let preferences = try? JSONDecoder().decode(DesktopPreferences.self, from: data) else {
            return DesktopPreferences()
        }
        return preferences
    }

    public func save(to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: file, options: .atomic)
    }

    /// The wallpaper to draw: the one named on the command line with
    /// `--wallpaper`, else the saved one. Either only if it's a PNG that
    /// exists.
    public func wallpaper(arguments: [String]) -> URL? {
        var path = wallpaper
        if let index = arguments.firstIndex(of: "--wallpaper"), arguments.indices.contains(index + 1) {
            path = arguments[index + 1]
        }
        guard let path, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard url.pathExtension.lowercased() == "png", FileManager.default.isReadableFile(atPath: url.path) else {
            return nil
        }
        return url
    }

    /// Drops the places of icons that are gone, so the file doesn't grow
    /// with every file ever on the desktop.
    public mutating func forget(allBut names: Set<String>) {
        positions = positions.filter { names.contains($0.key) }
    }
}
