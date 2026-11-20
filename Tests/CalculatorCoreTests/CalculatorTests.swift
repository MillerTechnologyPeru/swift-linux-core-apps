import Testing
@testable import CalculatorCore

@Suite struct CalculatorTests {

    /// Presses keys written as text: digits, `.`, `+ - * /`, `=`, `c` for
    /// clear, `n` for negate, `%`, and `<` for delete.
    private func pressing(_ keys: String, on calculator: Calculator = Calculator()) -> Calculator {
        var calculator = calculator
        for character in keys {
            let key: Calculator.Key? = switch character {
            case "0"..."9": .digit(Int(String(character))!)
            case ".": .decimalPoint
            case "+": .operation(.add)
            case "-": .operation(.subtract)
            case "*": .operation(.multiply)
            case "/": .operation(.divide)
            case "=": .equals
            case "c": .clear
            case "n": .negate
            case "%": .percent
            case "<": .delete
            default: nil
            }
            if let key {
                calculator.press(key)
            }
        }
        return calculator
    }

    private func display(_ keys: String) -> String {
        pressing(keys).display
    }

    // MARK: Entry

    @Test func startsAtZero() {
        #expect(Calculator().display == "0")
    }

    @Test func digitsAppend() {
        #expect(display("123") == "123")
        #expect(display("007") == "7")
        #expect(display("0") == "0")
    }

    @Test func oneDecimalPoint() {
        #expect(display(".5") == "0.5")
        #expect(display("1.2.3") == "1.23")
        #expect(display("3.") == "3.")
        #expect(display("1.50") == "1.50")
    }

    @Test func entryStopsAtTheMostDigits() {
        #expect(display("1234567890123456") == "123456789012")
    }

    @Test func deleteRemovesTheLastDigit() {
        #expect(display("123<") == "12")
        #expect(display("1<") == "0")
        #expect(display("1.5<<") == "1")
        // A result isn't an entry.
        #expect(display("1+2=<") == "3")
    }

    @Test func negateFlipsTheSign() {
        #expect(display("5n") == "-5")
        #expect(display("5nn") == "5")
        #expect(display("1+2=n") == "-3")
        #expect(display("n5") == "-5")
    }

    // MARK: Arithmetic

    @Test func theFourOperations() {
        #expect(display("2+3=") == "5")
        #expect(display("9-4=") == "5")
        #expect(display("6*7=") == "42")
        #expect(display("8/2=") == "4")
        #expect(display("1/4=") == "0.25")
    }

    @Test func operatorsChainFromLeftToRight() {
        #expect(display("2+3*4=") == "20")
        // The running result shows as the next operator is pressed.
        #expect(display("2+3*") == "5")
    }

    @Test func aSecondOperatorReplacesTheFirst() {
        #expect(display("2+*3=") == "6")
    }

    @Test func equalsRepeatsTheLastOperation() {
        #expect(display("2+3==") == "8")
        #expect(display("2*3===") == "54")
    }

    @Test func aNewNumberAfterEqualsStartsOver() {
        #expect(display("2+3=4") == "4")
        #expect(display("2+3=4+1=") == "5")
    }

    @Test func aResultCarriesIntoTheNextOperation() {
        #expect(display("2+3=*2=") == "10")
    }

    @Test func fractionsShowWithoutBinaryNoise() {
        #expect(display(".1+.2=") == "0.3")
        #expect(display("1/3=") == "0.3333333333")
        #expect(display("2/3=") == "0.6666666667")
        #expect(display("0-.5=") == "-0.5")
    }

    @Test func percent() {
        #expect(display("50%") == "0.5")
        // Of the left side, when there is one.
        #expect(display("200+10%") == "20")
        #expect(display("200+10%=") == "220")
    }

    // MARK: Clearing and errors

    @Test func clearRemovesTheEntryThenEverything() {
        var calculator = pressing("2+3")
        #expect(calculator.clearsEntry)
        calculator.press(.clear)
        #expect(calculator.display == "0")
        // The addition is still pending.
        #expect(pressing("4=", on: calculator).display == "6")
        calculator.press(.clear)
        #expect(pressing("4=", on: calculator).display == "4")
        #expect(calculator == Calculator())
    }

    @Test func dividingByZeroIsAnError() {
        let calculator = pressing("5/0=")
        #expect(calculator.isError)
        #expect(calculator.display == "Error")
        // A digit starts over; an operator doesn't act on the error.
        #expect(pressing("7", on: calculator).display == "7")
        #expect(pressing("+2=", on: calculator).display == "2")
        #expect(pressing("c", on: calculator) == Calculator())
    }

    @Test func aResultTooLargeIsAnError() {
        #expect(pressing("999999999999*999999999999=").isError)
    }

    @Test func thePendingOperationShowsUntilANumberIsTyped() {
        #expect(pressing("2+").pendingOperation == .add)
        #expect(pressing("2+3").pendingOperation == nil)
        #expect(pressing("2+3=").pendingOperation == nil)
    }

    // MARK: Text

    @Test func formatting() {
        #expect(Calculator.format(0) == "0")
        #expect(Calculator.format(-0.0) == "0")
        #expect(Calculator.format(1234567) == "1234567")
        #expect(Calculator.format(-2.5) == "-2.5")
        #expect(Calculator.format(0.00001) == "0.00001")
        #expect(Calculator.format(1.99999999999) == "2")
        #expect(Calculator.parse("-12.75") == -12.75)
    }
}
