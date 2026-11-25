import Foundation
import Testing
@testable import FilesCore

@Suite struct DesktopLayoutTests {

    /// A 1280 × 800 screen: 13 columns of 96 and 7 rows of 92 fit between
    /// the menu bar and the dock.
    let layout = DesktopLayout(size: (1280, 800))

    @Test func theGridFitsBetweenTheBars() {
        #expect(layout.columns == 13)
        #expect(layout.rows == 7)
    }

    @Test func aTinyScreenStillHasAPlace() {
        let tiny = DesktopLayout(size: (40, 40))
        #expect(tiny.columns == 1)
        #expect(tiny.rows == 1)
        #expect(tiny.arrange(["a", "b"]) == ["a": DesktopSlot(column: 0, row: 0), "b": DesktopSlot(column: 0, row: 0)])
    }

    @Test func iconsFillTheFirstColumnDownward() {
        let placed = layout.arrange(["a", "b", "c"])
        #expect(placed["a"] == DesktopSlot(column: 0, row: 0))
        #expect(placed["b"] == DesktopSlot(column: 0, row: 1))
        #expect(placed["c"] == DesktopSlot(column: 0, row: 2))
    }

    @Test func aFullColumnMovesOnToTheNext() {
        let names = (0 ..< 9).map { "item \($0)" }
        let placed = layout.arrange(names)
        #expect(placed["item 6"] == DesktopSlot(column: 0, row: 6))
        #expect(placed["item 7"] == DesktopSlot(column: 1, row: 0))
    }

    @Test func movedIconsKeepTheirPlacesAndTheRestFlowAroundThem() {
        let saved = ["b": DesktopSlot(column: 0, row: 0)]
        let placed = layout.arrange(["a", "b", "c"], saved: saved)
        #expect(placed["b"] == DesktopSlot(column: 0, row: 0))
        #expect(placed["a"] == DesktopSlot(column: 0, row: 1))
        #expect(placed["c"] == DesktopSlot(column: 0, row: 2))
    }

    @Test func aPlaceOffTheGridOrTakenIsGivenUp() {
        let saved = [
            "a": DesktopSlot(column: 40, row: 0),
            "b": DesktopSlot(column: 2, row: 2),
            "c": DesktopSlot(column: 2, row: 2),
        ]
        let placed = layout.arrange(["a", "b", "c"], saved: saved)
        #expect(placed["b"] == DesktopSlot(column: 2, row: 2))
        #expect(placed["a"] == DesktopSlot(column: 0, row: 0))
        #expect(placed["c"] == DesktopSlot(column: 0, row: 1))
    }

    @Test func droppingOnAnotherIconSwapsThem() {
        let placed = layout.arrange(["a", "b"])
        let moved = DesktopLayout.move("a", to: DesktopSlot(column: 0, row: 1), in: placed)
        #expect(moved["a"] == DesktopSlot(column: 0, row: 1))
        #expect(moved["b"] == DesktopSlot(column: 0, row: 0))
    }

    @Test func aDropPointFindsItsPlaceInsideTheGrid() {
        let center = layout.center(of: DesktopSlot(column: 3, row: 2))
        #expect(center.x == 12 + 3.5 * 96)
        #expect(center.y == 44 + 2.5 * 92)
        #expect(layout.slot(nearest: center) == DesktopSlot(column: 3, row: 2))
        #expect(layout.slot(nearest: (-500, -500)) == DesktopSlot(column: 0, row: 0))
        #expect(layout.slot(nearest: (5000, 5000)) == DesktopSlot(column: 12, row: 6))
    }
}

@Suite struct DesktopPreferencesTests {

    @Test func theFileIsInTheConfigFolder() {
        let home = URL(fileURLWithPath: "/home/someone", isDirectory: true)
        #expect(DesktopPreferences.file(homeDirectory: home, environment: [:]).path == "/home/someone/.config/files/desktop.json")
        #expect(DesktopPreferences.file(homeDirectory: home, environment: ["XDG_CONFIG_HOME": "/tmp/config"]).path == "/tmp/config/files/desktop.json")
    }

    @Test func savedAndLoadedAlike() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("desktop-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("files/desktop.json")
        #expect(DesktopPreferences.load(from: file) == DesktopPreferences())
        let preferences = DesktopPreferences(wallpaper: "/pictures/sky.png", positions: ["Notes.txt": DesktopSlot(column: 2, row: 1)])
        try preferences.save(to: file)
        #expect(DesktopPreferences.load(from: file) == preferences)
    }

    @Test func theWallpaperIsAPNGThatExists() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("wallpaper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let png = folder.appendingPathComponent("sky.png")
        let jpeg = folder.appendingPathComponent("sea.jpg")
        try Data([0x89]).write(to: png)
        try Data([0xFF]).write(to: jpeg)

        #expect(DesktopPreferences().wallpaper(arguments: []) == nil)
        #expect(DesktopPreferences(wallpaper: png.path).wallpaper(arguments: [])?.path == png.path)
        #expect(DesktopPreferences(wallpaper: jpeg.path).wallpaper(arguments: []) == nil)
        #expect(DesktopPreferences(wallpaper: folder.appendingPathComponent("gone.png").path).wallpaper(arguments: []) == nil)
        // The command line's wins over the saved one.
        let other = folder.appendingPathComponent("other.png")
        try Data([0x89]).write(to: other)
        #expect(DesktopPreferences(wallpaper: png.path).wallpaper(arguments: ["files", "--desktop", "--wallpaper", other.path])?.path == other.path)
    }

    @Test func iconsThatAreGoneAreForgotten() {
        var preferences = DesktopPreferences(positions: ["a": DesktopSlot(column: 0, row: 0), "b": DesktopSlot(column: 1, row: 0)])
        preferences.forget(allBut: ["b"])
        #expect(preferences.positions == ["b": DesktopSlot(column: 1, row: 0)])
    }
}
