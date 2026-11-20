//
//  Calculator.swift
//  CoreApps
//

/// A four-function calculator: what its keys do, and what it shows.
///
/// It works as desk calculators do: an operator applies to what's shown and
/// the next number entered, operators chain from left to right, and equals
/// pressed again repeats the last operation. It uses no Foundation, so it
/// builds for a guest.
public struct Calculator: Equatable, Sendable {

    public enum Operation: Equatable, Sendable {
        case add
        case subtract
        case multiply
        case divide
    }

    public enum Key: Equatable, Sendable {
        /// A digit, 0 through 9.
        case digit(Int)
        case decimalPoint
        case operation(Operation)
        case equals
        /// Clears the entry, or everything when there's no entry.
        case clear
        /// Removes the entry's last digit.
        case delete
        case negate
        case percent
    }

    /// The most digits an entry can have.
    public static let maximumDigits = 12

    /// The number being typed, as its digits, or `nil` when showing a result.
    private var entry: String?

    /// The value shown when no number is being typed.
    private var value: Double = 0

    /// The left side of a pending operation.
    private var accumulator: Double?

    private var pending: Operation?

    /// The last operation and its right side, which equals repeats.
    private var last: (operation: Operation, operand: Double)?

    /// Whether the last result couldn't be computed.
    public private(set) var isError = false

    public init() { }

    public static func == (lhs: Calculator, rhs: Calculator) -> Bool {
        lhs.entry == rhs.entry && lhs.value == rhs.value && lhs.accumulator == rhs.accumulator
            && lhs.pending == rhs.pending && lhs.isError == rhs.isError
            && lhs.last?.operation == rhs.last?.operation && lhs.last?.operand == rhs.last?.operand
    }

    /// What the calculator shows.
    public var display: String {
        if isError {
            return "Error"
        }
        if let entry {
            return entry
        }
        return Self.format(value)
    }

    /// The operation waiting for its right side, for a key to show as active.
    public var pendingOperation: Operation? {
        entry == nil ? pending : nil
    }

    /// Whether clear will remove only the entry.
    public var clearsEntry: Bool {
        entry != nil && !isError
    }

    private var current: Double {
        entry.map(Self.parse) ?? value
    }

    public mutating func press(_ key: Key) {
        if isError, key != .clear {
            // Anything but clear starts over from the error.
            self = Calculator()
            if case .operation = key { return }
            if key == .equals || key == .negate || key == .percent || key == .delete { return }
        }
        switch key {
        case let .digit(digit):
            guard (0...9).contains(digit) else { return }
            var text = entry ?? ""
            if text == "0" {
                text = ""
            } else if text == "-0" {
                text = "-"
            }
            guard text.filter({ $0 != "-" && $0 != "." }).count < Self.maximumDigits else { return }
            text += "\(digit)"
            entry = text
        case .decimalPoint:
            var text = entry ?? "0"
            guard !text.contains(".") else { return }
            text += "."
            entry = text
        case let .operation(operation):
            if entry != nil || accumulator == nil {
                apply()
            }
            guard !isError else { return }
            accumulator = value
            pending = operation
            entry = nil
        case .equals:
            if pending != nil {
                apply()
            } else if let last {
                value = compute(current, last.operation, last.operand)
                entry = nil
            } else {
                value = current
                entry = nil
            }
        case .clear:
            if clearsEntry {
                entry = nil
                value = 0
            } else {
                self = Calculator()
            }
        case .delete:
            guard var text = entry else { return }
            text.removeLast()
            entry = text.isEmpty || text == "-" ? "0" : text
        case .negate:
            if let text = entry {
                entry = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
            } else if value == 0 {
                // Before a number is typed, the sign waits for it.
                entry = "-0"
            } else {
                value = -value
            }
        case .percent:
            // Of the left side when there is one, as on a desk calculator:
            // 200 + 10 % is 200 + 20.
            let base = pending != nil ? (accumulator ?? 0) : 1
            value = current / 100 * base
            entry = nil
        }
    }

    /// Carries out the pending operation with what's shown as its right side.
    private mutating func apply() {
        let operand = current
        if let operation = pending, let left = accumulator {
            value = compute(left, operation, operand)
            last = (operation, operand)
        } else {
            value = operand
        }
        accumulator = nil
        pending = nil
        entry = nil
    }

    private mutating func compute(_ left: Double, _ operation: Operation, _ right: Double) -> Double {
        let result: Double
        switch operation {
        case .add: result = left + right
        case .subtract: result = left - right
        case .multiply: result = left * right
        case .divide:
            guard right != 0 else {
                isError = true
                return 0
            }
            result = left / right
        }
        guard result.isFinite, abs(result) < 1e15 else {
            isError = true
            return 0
        }
        return result
    }

    // MARK: Text

    /// The value of an entry's digits.
    static func parse(_ text: String) -> Double {
        var result = 0.0
        var scale = 0.0
        var negative = false
        for character in text.utf8 {
            switch character {
            case UInt8(ascii: "-"):
                negative = true
            case UInt8(ascii: "."):
                scale = 1
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                let digit = Double(character - UInt8(ascii: "0"))
                if scale == 0 {
                    result = result * 10 + digit
                } else {
                    scale *= 10
                    result += digit / scale
                }
            default:
                break
            }
        }
        return negative ? -result : result
    }

    /// A value as the display shows it: up to ten decimal places, without
    /// trailing zeros, so that 0.1 + 0.2 shows 0.3.
    static func format(_ value: Double) -> String {
        let places = 10
        var scale = 1.0
        for _ in 0..<places {
            scale *= 10
        }
        let negative = value < 0
        let magnitude = negative ? -value : value
        var whole = magnitude.rounded(.down)
        var fraction = ((magnitude - whole) * scale).rounded()
        if fraction >= scale {
            whole += 1
            fraction = 0
        }
        var text = "\(Int64(whole))"
        if fraction > 0 {
            var digits = "\(Int64(fraction))"
            while digits.utf8.count < places {
                digits = "0" + digits
            }
            while digits.hasSuffix("0") {
                digits.removeLast()
            }
            text += "." + digits
        }
        return negative && text != "0" ? "-" + text : text
    }
}
