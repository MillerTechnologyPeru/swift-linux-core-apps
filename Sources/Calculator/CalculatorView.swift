//
//  CalculatorView.swift
//  CoreApps
//

import AppUI
import CoreAppsUI
import CalculatorCore

/// The calculator's screen: what it shows, above its keys.
public struct CalculatorView: View {

    @State private var calculator = CalculatorCore.Calculator()

    public init() { }

    public var body: some View {
        VStack(spacing: Metrics.keySpacing) {
            HStack {
                Spacer()
                Text(calculator.display)
                    .font(.system(size: 56, weight: .light))
                    .lineLimit(1)
                    .accessibilityIdentifier("display")
            }
            .frame(minHeight: 96, maxHeight: .infinity, alignment: .bottomTrailing)
            row([
                (calculator.clearsEntry ? "C" : "AC", .secondary, .clear, "clear"),
                ("±", .secondary, .negate, "negate"),
                ("%", .secondary, .percent, "percent"),
                ("÷", .primary, .operation(.divide), "divide"),
            ])
            row([
                ("7", .standard, .digit(7), "7"),
                ("8", .standard, .digit(8), "8"),
                ("9", .standard, .digit(9), "9"),
                ("×", .primary, .operation(.multiply), "multiply"),
            ])
            row([
                ("4", .standard, .digit(4), "4"),
                ("5", .standard, .digit(5), "5"),
                ("6", .standard, .digit(6), "6"),
                ("−", .primary, .operation(.subtract), "subtract"),
            ])
            row([
                ("1", .standard, .digit(1), "1"),
                ("2", .standard, .digit(2), "2"),
                ("3", .standard, .digit(3), "3"),
                ("+", .primary, .operation(.add), "add"),
            ])
            row([
                ("←", .standard, .delete, "delete"),
                ("0", .standard, .digit(0), "0"),
                (".", .standard, .decimalPoint, "decimal"),
                ("=", .primary, .equals, "equals"),
            ])
        }
        .padding(Metrics.screenPadding)
    }

    private typealias KeySpec = (title: String, prominence: KeyProminence, key: CalculatorCore.Calculator.Key, identifier: String)

    /// A row of four keys, each as wide as the others.
    private func row(_ keys: [KeySpec]) -> some View {
        HStack(spacing: Metrics.keySpacing) {
            ForEach(0..<keys.count, id: \.self) { index in
                let spec = keys[index]
                KeyButton(spec.title, prominence: spec.prominence, identifier: spec.identifier) {
                    calculator.press(spec.key)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
