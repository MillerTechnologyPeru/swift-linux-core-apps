import Testing
@testable import ImagesCore

@Suite struct ImageFormatTests {

    @Test func formatsAreKnownByTheirFirstBytes() {
        #expect(ImageFormat(header: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]) == .png)
        #expect(ImageFormat(header: [0xFF, 0xD8, 0xFF, 0xE0]) == .jpeg)
        #expect(ImageFormat(header: Array("GIF89a".utf8)) == .gif)
        #expect(ImageFormat(header: Array("RIFF____WEBPVP8 ".utf8)) == .webp)
        #expect(ImageFormat(header: Array("BM".utf8) + [0, 0]) == .bmp)
        #expect(ImageFormat(header: [0x49, 0x49, 0x2A, 0x00]) == .tiff)
        #expect(ImageFormat(header: [0x4D, 0x4D, 0x00, 0x2A]) == .tiff)
        #expect(ImageFormat(header: [0, 0, 0, 24] + Array("ftypheic".utf8)) == .heif)
        #expect(ImageFormat(header: [0, 0, 0, 24] + Array("ftypavif".utf8)) == .heif)
    }

    @Test func otherFilesAreNotImages() {
        #expect(ImageFormat(header: []) == nil)
        #expect(ImageFormat(header: Array("hello world".utf8)) == nil)
        // A video of the same family as HEIF.
        #expect(ImageFormat(header: [0, 0, 0, 24] + Array("ftypisom".utf8)) == nil)
        #expect(ImageFormat(header: Array("RIFF____WAVE".utf8)) == nil)
        #expect(ImageFormat(header: [0x89, 0x50]) == nil)
    }
}

@Suite struct PixelSizeTests {

    private func big32(_ value: Int) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private func little(_ value: Int, bytes: Int) -> [UInt8] {
        (0..<bytes).map { UInt8(value >> ($0 * 8) & 0xFF) }
    }

    @Test func png() {
        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + big32(13) + Array("IHDR".utf8) + big32(1920) + big32(1080)
        #expect(PixelSize(header: header) == PixelSize(width: 1920, height: 1080))
        // Cut short before the height.
        #expect(PixelSize(header: Array(header.dropLast(2))) == nil)
    }

    @Test func gif() {
        let header = Array("GIF89a".utf8) + little(320, bytes: 2) + little(200, bytes: 2)
        #expect(PixelSize(header: header) == PixelSize(width: 320, height: 200))
    }

    @Test func bmpWithRowsStoredEitherWay() {
        let start = Array("BM".utf8) + [UInt8](repeating: 0, count: 16)
        #expect(PixelSize(header: start + little(640, bytes: 4) + little(480, bytes: 4)) == PixelSize(width: 640, height: 480))
        let topFirst = start + little(640, bytes: 4) + [0x20, 0xFE, 0xFF, 0xFF]
        #expect(PixelSize(header: topFirst) == PixelSize(width: 640, height: 480))
    }

    @Test func jpegFindsTheFrameAfterOtherSegments() {
        var bytes: [UInt8] = [0xFF, 0xD8]
        // An application segment of 16 bytes, then a quantization table.
        bytes += [0xFF, 0xE0, 0x00, 0x10] + [UInt8](repeating: 0, count: 14)
        bytes += [0xFF, 0xDB, 0x00, 0x05, 1, 2, 3]
        // The frame: length, precision, height, width.
        bytes += [0xFF, 0xC2, 0x00, 0x11, 0x08, 0x02, 0x58, 0x03, 0x20]
        #expect(PixelSize(header: bytes) == PixelSize(width: 800, height: 600))
    }

    @Test func jpegWithoutAFrameHasNoSize() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0, 0]
        #expect(PixelSize(header: bytes) == nil)
    }

    @Test func webpInItsThreeForms() {
        let riff = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WEBP".utf8)
        let extended = riff + Array("VP8X".utf8) + [10, 0, 0, 0, 0, 0, 0, 0] + little(1023, bytes: 3) + little(767, bytes: 3)
        #expect(PixelSize(header: extended) == PixelSize(width: 1024, height: 768))

        let lossy = riff + Array("VP8 ".utf8) + [0, 0, 0, 0] + [0, 0, 0, 0x9D, 0x01, 0x2A] + little(400, bytes: 2) + little(300, bytes: 2)
        #expect(PixelSize(header: lossy) == PixelSize(width: 400, height: 300))

        // 14 bits of width less one, then 14 of height less one.
        let bits = (99) | (49 << 14)
        let lossless = riff + Array("VP8L".utf8) + [0, 0, 0, 0] + [0x2F] + little(bits, bytes: 4)
        #expect(PixelSize(header: lossless) == PixelSize(width: 100, height: 50))
    }

    @Test func formatsWhoseHeadersAreNotRead() {
        #expect(PixelSize(header: [0x49, 0x49, 0x2A, 0x00, 8, 0, 0, 0]) == nil)
        #expect(PixelSize(header: Array("not an image".utf8)) == nil)
    }
}

@Suite struct ViewportTests {

    /// A wide image in a tall view: it fits by its width.
    private var viewport: Viewport {
        Viewport(imageWidth: 2000, imageHeight: 1000, viewWidth: 400, viewHeight: 800)
    }

    @Test func anImageFitsByItsTighterSide() {
        let viewport = viewport
        #expect(viewport.fitScale == 0.2)
        #expect(viewport.displayWidth == 400)
        #expect(viewport.displayHeight == 200)
        #expect(viewport.isFitted)
        #expect(viewport.percentage == 20)
        #expect(viewport.actualSizeZoom == 5)
    }

    @Test func aFittedImageStaysCentred() {
        var viewport = viewport
        viewport.pan(byX: 50, y: 50)
        #expect(viewport.offsetX == 0)
        #expect(viewport.offsetY == 0)
    }

    @Test func zoomIsHeldBetweenFittingAndTheMost() {
        var viewport = viewport
        viewport.setZoom(0.2)
        #expect(viewport.zoom == 1)
        viewport.setZoom(100)
        #expect(viewport.zoom == Viewport.maximumZoom)
    }

    @Test func aZoomedImageCanBeDraggedOnlyToItsEdges() {
        var viewport = viewport
        viewport.setZoom(2)
        // 800 wide in a view of 400: 200 either way. 400 tall in 800: none.
        viewport.pan(byX: -500, y: 300)
        #expect(viewport.offsetX == -200)
        #expect(viewport.offsetY == 0)
        viewport.pan(byX: 150, y: 0)
        #expect(viewport.offsetX == -50)
    }

    @Test func zoomingKeepsThePointUnderTheFingersWhereItIs() {
        var viewport = viewport
        // 100 points right of centre is 100 / 0.2 = 500 pixels right of the
        // image's centre. After doubling, that pixel is still under it.
        viewport.setZoom(2, aroundX: 100, y: 0)
        #expect(viewport.offsetX == -100)
        let pixel = (100 - viewport.offsetX) / (viewport.fitScale * viewport.zoom)
        #expect(pixel == 500)
    }

    @Test func aDoubleTapZoomsToTheImagesOwnSizeAndBack() {
        var viewport = viewport
        viewport.toggleZoom()
        #expect(viewport.zoom == 5)
        #expect(viewport.percentage == 100)
        viewport.toggleZoom()
        #expect(viewport.zoom == 1)
        #expect(viewport.offsetX == 0)
    }

    @Test func aSmallImageDoublesOnADoubleTap() {
        var viewport = Viewport(imageWidth: 100, imageHeight: 100, viewWidth: 400, viewHeight: 400)
        #expect(viewport.actualSizeZoom == 0.25)
        viewport.toggleZoom()
        #expect(viewport.zoom == 2)
    }

    @Test func turningSwapsTheSidesAndFitsAgain() {
        var viewport = viewport
        viewport.setZoom(3)
        viewport.rotate()
        #expect(viewport.quarterTurns == 1)
        #expect(viewport.zoom == 1)
        #expect(viewport.turnedWidth == 1000)
        #expect(viewport.turnedHeight == 2000)
        #expect(viewport.fitScale == 0.4)
        viewport.rotate(clockwise: false)
        #expect(viewport.quarterTurns == 0)
        viewport.rotate(clockwise: false)
        #expect(viewport.quarterTurns == 3)
    }

    @Test func resizingTheViewKeepsTheOffsetInBounds() {
        var viewport = viewport
        viewport.setZoom(4)
        viewport.pan(byX: -600, y: 0)
        #expect(viewport.offsetX == -600)
        viewport.resize(viewWidth: 800, viewHeight: 400)
        // Now it fits by its height: 0.4 a pixel, 3200 wide, 1200 either way.
        #expect(viewport.fitScale == 0.4)
        #expect(viewport.offsetX == -600)
        viewport.resize(viewWidth: 3000, viewHeight: 400)
        #expect(viewport.offsetX == -100)
    }

    @Test func aViewWithNoSizeYetDoesNotDivideByZero() {
        let viewport = Viewport(imageWidth: 100, imageHeight: 100)
        #expect(viewport.fitScale == 1)
    }
}

@Suite struct ImageSequenceTests {

    @Test func itStartsAtTheItemAskedFor() {
        let sequence = ImageSequence(["a", "b", "c"], current: "b")
        #expect(sequence.current == "b")
        #expect(sequence.position == "2 of 3")
        #expect(ImageSequence(["a", "b"], current: "z").current == "a")
    }

    @Test func itStopsAtEitherEnd() {
        var sequence = ImageSequence(["a", "b"])
        #expect(!sequence.hasPrevious && sequence.hasNext)
        sequence.previous()
        #expect(sequence.current == "a")
        sequence.next()
        sequence.next()
        #expect(sequence.current == "b")
        #expect(sequence.hasPrevious && !sequence.hasNext)
    }

    @Test func removingShowsTheNextOrTheOneBefore() {
        var sequence = ImageSequence(["a", "b", "c"], current: "b")
        sequence.removeCurrent()
        #expect(sequence.current == "c")
        sequence.removeCurrent()
        #expect(sequence.current == "a")
        sequence.removeCurrent()
        #expect(sequence.current == nil)
        #expect(sequence.isEmpty)
        #expect(sequence.position == "")
        sequence.removeCurrent()
        #expect(sequence.isEmpty)
    }

    @Test func showingAnItemGoesToIt() {
        var sequence = ImageSequence([1, 2, 3])
        sequence.show(3)
        #expect(sequence.current == 3)
        sequence.show(9)
        #expect(sequence.current == 3)
    }
}
