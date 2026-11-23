//
//  KeyButton.swift
//  CoreApps
//

import AppUI

/// How much a key stands out among the others.
public enum KeyProminence: Sendable {

    /// A digit, or anything else typed into a value.
    case standard

    /// A key that changes the value: clear, sign, percent.
    case secondary

    /// A key that acts on the value: an operator, or equals.
    case primary
}

/// A large key on a pad, such as a calculator's or a dialer's: a filled,
/// rounded rectangle that takes the space its row gives it, at least as
/// tall as a finger needs.
public struct KeyButton: View {

    private let title: String

    private let prominence: KeyProminence

    private let identifier: String

    private let action: () -> Void

    public init(
        _ title: String,
        prominence: KeyProminence = .standard,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.prominence = prominence
        self.identifier = identifier ?? title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title)
                .foregroundStyle(foreground)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: Metrics.minimumTarget, maxHeight: .infinity)
                .background(fill)
                .cornerRadius(Metrics.keyCornerRadius)
        }
        .plainButton()
        #if !Native && !Apple
        // A guest's host draws its own buttons, which color their label
        // with the tint: the key's own color, not the accent.
        .tint(foreground)
        #endif
        .accessibilityIdentifier(identifier)
    }

    private var fill: Color {
        switch prominence {
        case .standard: Color(white: 0.5, opacity: 0.18)
        case .secondary: Color(white: 0.5, opacity: 0.35)
        case .primary: Self.accent
        }
    }

    /// The operators' fill. In a guest the button's tint is its label's
    /// color, which the accent color inside it would take too; and the
    /// Linux player knows no named color but black and white, so it's
    /// the system's blue by its components.
    #if !Native && !Apple
    private static let accent = Color(red: 0, green: 0.478, blue: 1)
    #else
    private static let accent = Color.accentColor
    #endif

    private var foreground: Color {
        prominence == .primary ? Color.white : Color.primary
    }
}
