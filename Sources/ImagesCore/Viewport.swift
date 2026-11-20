//
//  Viewport.swift
//  CoreApps
//

/// How an image is shown in a view: how far it's zoomed, where it's been
/// dragged to, and which way up it is.
///
/// A zoom of 1 fits the whole image in the view; the offset is how far the
/// image's centre is from the view's, in points. The image never leaves
/// more of the view empty than it must: at a zoom of 1 it stays centred.
public struct Viewport: Equatable, Sendable {

    /// The image's size in pixels, as it's stored.
    public var imageWidth: Double

    public var imageHeight: Double

    /// The view's size in points.
    public var viewWidth: Double

    public var viewHeight: Double

    public private(set) var zoom: Double = 1

    public private(set) var offsetX: Double = 0

    public private(set) var offsetY: Double = 0

    /// Clockwise quarter turns, 0 to 3.
    public private(set) var quarterTurns = 0

    /// The most an image is zoomed, as a multiple of fitting.
    public static let maximumZoom = 16.0

    public init(imageWidth: Double, imageHeight: Double, viewWidth: Double = 0, viewHeight: Double = 0) {
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.viewWidth = viewWidth
        self.viewHeight = viewHeight
    }

    /// The image's size as it's turned.
    public var turnedWidth: Double {
        quarterTurns % 2 == 0 ? imageWidth : imageHeight
    }

    public var turnedHeight: Double {
        quarterTurns % 2 == 0 ? imageHeight : imageWidth
    }

    /// Points for each of the image's pixels when it just fits the view.
    public var fitScale: Double {
        guard turnedWidth > 0, turnedHeight > 0, viewWidth > 0, viewHeight > 0 else { return 1 }
        return min(viewWidth / turnedWidth, viewHeight / turnedHeight)
    }

    /// The image's size on screen, in points.
    public var displayWidth: Double {
        turnedWidth * fitScale * zoom
    }

    public var displayHeight: Double {
        turnedHeight * fitScale * zoom
    }

    /// Whether the image shows whole.
    public var isFitted: Bool {
        zoom <= 1
    }

    /// The zoom at which each pixel of the image is a point of the view.
    public var actualSizeZoom: Double {
        1 / fitScale
    }

    /// The zoom as a percentage of the image's own size.
    public var percentage: Int {
        Int((fitScale * zoom * 100).rounded())
    }

    /// The view was resized. The zoom stays; the offset is kept in bounds.
    public mutating func resize(viewWidth: Double, viewHeight: Double) {
        self.viewWidth = viewWidth
        self.viewHeight = viewHeight
        clamp()
    }

    /// Keeps the offset from showing more empty view than it must.
    private mutating func clamp() {
        let slackX = max(0, (displayWidth - viewWidth) / 2)
        let slackY = max(0, (displayHeight - viewHeight) / 2)
        offsetX = min(max(offsetX, -slackX), slackX)
        offsetY = min(max(offsetY, -slackY), slackY)
    }

    /// Sets the zoom, keeping the point of the image under a point of the
    /// view where it is: the middle of a pinch, or the pointer.
    ///
    /// - Parameters:
    ///   - x: The point, from the view's centre.
    public mutating func setZoom(_ newZoom: Double, aroundX x: Double = 0, y: Double = 0) {
        let target = min(max(newZoom, 1), Self.maximumZoom)
        guard zoom > 0 else { return }
        let ratio = target / zoom
        // The point's distance from the image's centre grows with the zoom.
        offsetX = x - (x - offsetX) * ratio
        offsetY = y - (y - offsetY) * ratio
        zoom = target
        clamp()
    }

    /// Zooms by a factor.
    public mutating func zoom(by factor: Double, aroundX x: Double = 0, y: Double = 0) {
        setZoom(zoom * factor, aroundX: x, y: y)
    }

    /// Drags the image.
    public mutating func pan(byX x: Double, y: Double) {
        offsetX += x
        offsetY += y
        clamp()
    }

    /// Shows the whole image.
    public mutating func fit() {
        zoom = 1
        offsetX = 0
        offsetY = 0
    }

    /// A double tap: zooms in on the point, or back out if zoomed. It
    /// zooms to the image's own size, or to double if that isn't larger.
    public mutating func toggleZoom(atX x: Double = 0, y: Double = 0) {
        if zoom > 1 {
            fit()
        } else {
            setZoom(max(2, min(actualSizeZoom, Self.maximumZoom)), aroundX: x, y: y)
        }
    }

    /// Turns the image a quarter turn, and shows it whole.
    public mutating func rotate(clockwise: Bool = true) {
        quarterTurns = (quarterTurns + (clockwise ? 1 : 3)) % 4
        fit()
    }
}
