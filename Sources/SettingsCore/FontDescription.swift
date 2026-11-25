//
//  FontDescription.swift
//  CoreApps
//

/// A font as GNOME's `font-name` names it, in Pango's syntax: a family,
/// perhaps with styles, and a size in points, as in `Inter 10` or
/// `JetBrains Mono Bold 11.5`.
public struct FontDescription: Hashable, Sendable, CustomStringConvertible {

    /// The family and any styles: everything before the size.
    public var family: String

    /// The size in points, or `nil` when the description has none.
    public var size: Double?

    public init(family: String, size: Double? = nil) {
        self.family = family
        self.size = size
    }

    /// The font a description names. The size is the last word, when it's
    /// a number.
    public init(_ text: String) {
        var words = text.split(whereSeparator: { $0 == " " || $0 == "\t" })
        var size: Double?
        if words.count > 1, let last = words.last, let number = Double(last), number > 0 {
            size = number
            words.removeLast()
        }
        self.init(family: words.joined(separator: " "), size: size)
    }

    public var description: String {
        guard let size else {
            return family
        }
        return "\(family) \(FontDescription.format(size))"
    }

    /// The size as a description writes it: `10`, or `10.5`.
    public static func format(_ size: Double) -> String {
        let rounded = (size * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    /// The sizes to choose from, in points.
    public static let sizes: [Double] = [8, 9, 10, 11, 12, 13, 14, 16, 18, 20]
}
