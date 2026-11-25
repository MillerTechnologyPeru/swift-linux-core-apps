//
//  ButtonLayout.swift
//  CoreApps
//

/// Which buttons title bars show and at which end, in GNOME's
/// `button-layout` syntax: names separated by commas, the leading end's
/// before a colon and the trailing end's after it, as in
/// `close,minimize,maximize:` or `appmenu:close`.
public struct ButtonLayout: Hashable, Sendable {

    /// The names at the leading end, from the edge in.
    public var leading: [String]

    /// The names at the trailing end, in order toward the edge.
    public var trailing: [String]

    public init(leading: [String], trailing: [String] = []) {
        self.leading = leading
        self.trailing = trailing
    }

    /// The layout a setting describes. Names other than the window
    /// buttons, such as `appmenu`, `icon` or `spacer`, are kept, as other
    /// desktops read them. A setting without a colon is all leading.
    public init(setting: String) {
        let ends = setting.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        func names(_ end: Substring?) -> [String] {
            guard let end else { return [] }
            return end.split(separator: ",").compactMap { name in
                let trimmed = name.filter { $0 != " " && $0 != "\t" }
                return trimmed.isEmpty ? nil : String(trimmed)
            }
        }
        self.init(leading: names(ends.first), trailing: names(ends.count > 1 ? ends[1] : nil))
    }

    /// The layout as a `button-layout` setting.
    public var setting: String {
        leading.joined(separator: ",") + ":" + trailing.joined(separator: ",")
    }

    /// The preset this is, if it's one.
    public var preset: Preset? {
        Preset.allCases.first { $0.layout == self }
    }
}

public extension ButtonLayout {

    /// The layouts to choose from.
    enum Preset: String, CaseIterable, Hashable, Sendable, Identifiable {

        /// Close, minimize and maximize at the left: Cacao's.
        case left

        /// Minimize, maximize and close at the right.
        case right

        /// GNOME's: the app's menu at the left and close at the right.
        case gnome

        public var id: String { rawValue }

        public var layout: ButtonLayout {
            switch self {
            case .left: ButtonLayout(leading: ["close", "minimize", "maximize"])
            case .right: ButtonLayout(leading: [], trailing: ["minimize", "maximize", "close"])
            case .gnome: ButtonLayout(leading: ["appmenu"], trailing: ["close"])
            }
        }

        public var title: String {
            switch self {
            case .left: "Left"
            case .right: "Right"
            case .gnome: "Close Only"
            }
        }

        public var detail: String {
            switch self {
            case .left: "Close, minimize and maximize at the left"
            case .right: "Minimize, maximize and close at the right"
            case .gnome: "Close at the right, as GNOME has it"
            }
        }
    }
}
