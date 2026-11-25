//
//  AccentColor.swift
//  CoreApps
//

/// The portal's `accent-color`: sRGB components from 0 to 1.
public struct AccentColor: Hashable, Sendable {

    public var red: Double

    public var green: Double

    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The accent a portal value is. The portal says components out of the
    /// range 0 to 1 mean no accent is set.
    public init?(portalRed red: Double, green: Double, blue: Double) {
        let range = 0.0 ... 1.0
        guard range.contains(red), range.contains(green), range.contains(blue) else {
            return nil
        }
        self.init(red: red, green: green, blue: blue)
    }

    /// The accent from 8-bit components, as in `#3584E4`.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Whether two accents look the same: within 0.006 on each component,
    /// so a value rounded to 8 bits, or to two places as the settings
    /// service's default blue is, still matches.
    public func matches(_ other: AccentColor) -> Bool {
        let tolerance = 0.006
        return abs(red - other.red) <= tolerance
            && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
    }

    /// The accent's name, if it's one of the palette's.
    public var name: String? {
        AccentColor.palette.first { $0.color.matches(self) }?.name
    }
}

public extension AccentColor {

    /// An accent of the palette, by name.
    struct Named: Identifiable, Hashable, Sendable {

        public let name: String

        public let color: AccentColor

        public var id: String { name }
    }

    /// The accents to choose from: GNOME's, so a GNOME app in a Flatpak
    /// has the same accent the other apps do.
    static let palette: [Named] = [
        Named(name: "Blue", color: AccentColor(hex: 0x3584E4)),
        Named(name: "Teal", color: AccentColor(hex: 0x2190A4)),
        Named(name: "Green", color: AccentColor(hex: 0x3A944A)),
        Named(name: "Yellow", color: AccentColor(hex: 0xC88800)),
        Named(name: "Orange", color: AccentColor(hex: 0xED5B00)),
        Named(name: "Red", color: AccentColor(hex: 0xE62D42)),
        Named(name: "Pink", color: AccentColor(hex: 0xD56199)),
        Named(name: "Purple", color: AccentColor(hex: 0x9141AC)),
        Named(name: "Slate", color: AccentColor(hex: 0x6F8396)),
    ]
}
