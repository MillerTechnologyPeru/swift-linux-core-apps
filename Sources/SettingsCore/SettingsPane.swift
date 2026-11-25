//
//  SettingsPane.swift
//  CoreApps
//

/// A pane of Settings: what the sidebar lists.
public enum SettingsPane: String, CaseIterable, Hashable, Sendable, Identifiable {

    case wifi
    case bluetooth
    case displays
    case sound
    case power
    case appearance
    case defaultApps
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .bluetooth: "Bluetooth"
        case .displays: "Displays"
        case .sound: "Sound"
        case .power: "Power"
        case .appearance: "Appearance"
        case .defaultApps: "Default Apps"
        case .about: "About"
        }
    }

    /// An SF Symbols name, which Cacao draws too.
    public var symbolName: String {
        switch self {
        case .wifi: "wifi"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .displays: "display"
        case .sound: "speaker.wave.2"
        case .power: "battery.100percent"
        case .appearance: "circle.lefthalf.filled"
        case .defaultApps: "square.grid.2x2"
        case .about: "info.circle"
        }
    }

    /// Whether the pane does anything yet. The others are listed so the
    /// sidebar has the shape it will, and say they aren't here yet.
    public var isAvailable: Bool {
        self == .appearance
    }

    /// What a pane will need, for one that isn't here yet.
    public var plannedService: String? {
        switch self {
        case .wifi: "joining networks through NetworkManager"
        case .bluetooth: "pairing devices through BlueZ"
        case .displays: "arranging screens through the window server"
        case .sound: "choosing outputs and inputs through PipeWire"
        case .power: "the battery and sleep through UPower and logind"
        case .defaultApps: "choosing apps for files and links through launch services"
        case .about: "the device and system, from os-release and the hardware"
        case .appearance: nil
        }
    }

    /// The sidebar's groups, in order.
    public static let groups: [(title: String, panes: [SettingsPane])] = [
        ("Connections", [.wifi, .bluetooth]),
        ("Device", [.displays, .sound, .power]),
        ("Personal", [.appearance, .defaultApps]),
        ("System", [.about]),
    ]
}
