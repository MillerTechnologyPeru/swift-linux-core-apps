import Testing
@testable import TextCore

private func ascii(_ text: String) -> [UInt8] { Array(text.utf8) }

@Suite struct TextFileTests {

    @Test func plainTextIsUTF8WithLineFeeds() throws {
        let file = try TextFile(bytes: ascii("one\ntwo\n"))
        #expect(file.text == "one\ntwo\n")
        #expect(file.encoding == .utf8)
        #expect(file.lineEnding == .lineFeed)
        #expect(file.bytes == ascii("one\ntwo\n"))
    }

    @Test func anEmptyFileIsEmptyText() throws {
        let file = try TextFile(bytes: [])
        #expect(file.text == "")
        #expect(file.bytes == [])
    }

    @Test func windowsLineEndingsAreKeptForWritingBack() throws {
        let bytes = ascii("one\r\ntwo\r\nthree")
        let file = try TextFile(bytes: bytes)
        #expect(file.text == "one\ntwo\nthree")
        #expect(file.lineEnding == .carriageReturnLineFeed)
        #expect(file.bytes == bytes)
    }

    @Test func oldMacLineEndings() throws {
        let file = try TextFile(bytes: ascii("one\rtwo\r"))
        #expect(file.text == "one\ntwo\n")
        #expect(file.lineEnding == .carriageReturn)
        #expect(file.bytes == ascii("one\rtwo\r"))
    }

    @Test func mixedLineEndingsGoByTheMost() throws {
        let file = try TextFile(bytes: ascii("a\nb\nc\r\nd"))
        #expect(file.lineEnding == .lineFeed)
        #expect(file.text == "a\nb\nc\nd")
    }

    @Test func aByteOrderMarkIsKeptButNotShown() throws {
        let bytes: [UInt8] = [0xEF, 0xBB, 0xBF] + ascii("hi")
        let file = try TextFile(bytes: bytes)
        #expect(file.text == "hi")
        #expect(file.encoding == .utf8WithMark)
        #expect(file.bytes == bytes)
    }

    @Test func utf16OfEitherEnd() throws {
        let little: [UInt8] = [0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00, 0x0D, 0x00, 0x0A, 0x00]
        let file = try TextFile(bytes: little)
        #expect(file.text == "hi\n")
        #expect(file.encoding == .utf16LittleEndian)
        #expect(file.lineEnding == .carriageReturnLineFeed)
        #expect(file.bytes == little)

        let big: [UInt8] = [0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69]
        let other = try TextFile(bytes: big)
        #expect(other.text == "hi")
        #expect(other.encoding == .utf16BigEndian)
        #expect(other.bytes == big)
    }

    @Test func bytesThatAreNotUTF8AreLatin1() throws {
        let bytes: [UInt8] = [0x63, 0x61, 0x66, 0xE9]
        var file = try TextFile(bytes: bytes)
        #expect(file.text == "café")
        #expect(file.encoding == .latin1)
        #expect(file.bytes == bytes)
        #expect(file.canKeepEncoding)

        // A character Latin-1 hasn't got turns the file into UTF-8.
        file.text = "café €"
        #expect(!file.canKeepEncoding)
        #expect(file.bytes == ascii("café €"))
    }

    @Test func aFileWithZeroBytesIsNotText() {
        #expect(throws: TextFile.Failure.binary) {
            try TextFile(bytes: [0x7F, 0x45, 0x4C, 0x46, 0x00, 0x01])
        }
    }

    @Test func nonASCIITextRoundTrips() throws {
        let text = "naïve — 日本語 🎵\n"
        let file = try TextFile(bytes: ascii(text))
        #expect(file.text == text)
        #expect(file.bytes == ascii(text))
    }
}

@Suite struct TextSearchTests {

    private let text = "The cat sat.\nA Cat? No: concatenate.\ncat"

    @Test func matchesHaveTheirLineAndColumn() {
        let matches = TextSearch("cat").matches(in: text)
        #expect(matches.map(\.line) == [1, 2, 2, 3])
        #expect(matches.map(\.column) == [5, 3, 15, 1])
        #expect(matches[1].lineText == "A Cat? No: concatenate.")
    }

    @Test func capitalsCanBeMadeToMatter() {
        let search = TextSearch("cat", isCaseSensitive: true)
        #expect(search.matches(in: text).map(\.line) == [1, 2, 3])
        #expect(search.count(in: text) == 3)
    }

    @Test func wholeWordsLeaveOutLongerOnes() {
        let search = TextSearch("cat", matchesWholeWords: true)
        #expect(search.matches(in: text).map(\.column) == [5, 3, 1])
        #expect(TextSearch("cat", matchesWholeWords: true).count(in: "cat_1 cat-2 cats") == 1)
    }

    @Test func matchesDoNotOverlap() {
        #expect(TextSearch("aa").count(in: "aaaaa") == 2)
        #expect(TextSearch("aa").matches(in: "aaaaa").map(\.column) == [1, 3])
    }

    @Test func anEmptyPatternFindsNothing() {
        #expect(TextSearch("").matches(in: text).isEmpty)
        #expect(TextSearch("").count(in: text) == 0)
        #expect(TextSearch("").replacingAll(in: text, with: "x").count == 0)
    }

    @Test func theLimitStopsTheSearch() {
        #expect(TextSearch("a").matches(in: String(repeating: "a", count: 100), limit: 7).count == 7)
    }

    @Test func replacingAll() {
        let result = TextSearch("cat").replacingAll(in: text, with: "dog")
        #expect(result.count == 4)
        #expect(result.text == "The dog sat.\nA dog? No: condogenate.\ndog")

        let words = TextSearch("cat", matchesWholeWords: true).replacingAll(in: text, with: "")
        #expect(words.text == "The  sat.\nA ? No: concatenate.\n")
        #expect(TextSearch("zebra").replacingAll(in: text, with: "x").text == text)
    }

    @Test func replacingOneMatchLeavesTheOthers() {
        let search = TextSearch("cat")
        let second = search.matches(in: text)[1]
        let result = search.replacing(second, in: text, with: "Dog")
        #expect(result == "The cat sat.\nA Dog? No: concatenate.\ncat")
        // A match that's no longer there changes nothing.
        let stale = TextMatch(line: 1, column: 1, lineText: "")
        #expect(search.replacing(stale, in: text, with: "x") == text)
        #expect(search.replacing(TextMatch(line: 99, column: 1, lineText: ""), in: text, with: "x") == text)
    }

    @Test func searchesCountCharactersNotBytes() {
        let matches = TextSearch("b").matches(in: "é🎵b")
        #expect(matches.map(\.column) == [3])
        #expect(TextSearch("É").count(in: "éÉ") == 2)
    }
}

@Suite struct TextStatisticsTests {

    @Test func anEmptyTextHasOneEmptyLine() {
        let statistics = TextStatistics("")
        #expect(statistics.lines == 1)
        #expect(statistics.words == 0)
        #expect(statistics.characters == 0)
        #expect(statistics.bytes == 0)
    }

    @Test func wordsAreRunsBetweenSpaces() {
        let statistics = TextStatistics("  one two\n\nthree-four  five\t")
        #expect(statistics.words == 4)
        #expect(statistics.lines == 3)
        #expect(statistics.characters == 28)
        #expect(statistics.charactersWithoutSpaces == 20)
    }

    @Test func charactersAndBytesDiffer() {
        let statistics = TextStatistics("é🎵")
        #expect(statistics.characters == 2)
        #expect(statistics.bytes == 6)
    }
}

@Suite struct EditHistoryTests {

    @Test func aBurstOfTypingIsUndoneAtOnce() {
        var history = EditHistory("")
        history.record("h", at: 0)
        history.record("he", at: 0.2)
        history.record("hel", at: 0.5)
        #expect(history.undo() == "")
        #expect(!history.canUndo)
        #expect(history.redo() == "hel")
    }

    @Test func aPauseStartsANewState() {
        var history = EditHistory("")
        history.record("one", at: 0)
        history.record("one two", at: 5)
        #expect(history.undo() == "one")
        #expect(history.undo() == "")
        #expect(history.undo() == nil)
        #expect(history.redo() == "one")
        #expect(history.redo() == "one two")
        #expect(history.redo() == nil)
    }

    @Test func aSeparateChangeStandsByItself() {
        var history = EditHistory("a cat")
        history.record("a cat!", at: 0)
        history.record("a dog!", at: 0.1, isSeparate: true)
        history.record("a dog!!", at: 0.2)
        #expect(history.undo() == "a dog!")
        #expect(history.undo() == "a cat!")
        #expect(history.undo() == "a cat")
    }

    @Test func editingAfterUndoingForgetsWhatWasUndone() {
        var history = EditHistory("")
        history.record("one", at: 0)
        _ = history.undo()
        history.record("two", at: 10)
        #expect(!history.canRedo)
        #expect(history.current == "two")
    }

    @Test func typingAfterAnUndoDoesNotJoinTheBurstBefore() {
        var history = EditHistory("")
        history.record("one", at: 0)
        history.record("one two", at: 5)
        _ = history.undo()
        history.record("one x", at: 5.1)
        #expect(history.undo() == "one")
    }

    @Test func theSameTextIsNotAChange() {
        var history = EditHistory("same")
        history.record("same", at: 0)
        #expect(!history.canUndo)
        #expect(!history.isModified)
    }

    @Test func modifiedMeansDifferentFromWhatWasSaved() {
        var history = EditHistory("saved")
        history.record("changed", at: 0)
        #expect(history.isModified)
        history.markSaved()
        #expect(!history.isModified)
        _ = history.undo()
        #expect(history.isModified)
        _ = history.redo()
        #expect(!history.isModified)
    }

    @Test func onlySoManyStatesAreKept() {
        var history = EditHistory("0", limit: 3)
        for number in 1...10 {
            history.record("\(number)", at: Double(number) * 10)
        }
        var undone = 0
        while history.undo() != nil { undone += 1 }
        #expect(undone == 3)
        #expect(history.current == "7")
    }
}

@Suite struct DocumentNameTests {

    @Test func newDocumentsAreNumbered() {
        #expect(DocumentName.untitled(among: []) == "Untitled Document.txt")
        #expect(DocumentName.untitled(among: ["Untitled Document.txt"]) == "Untitled Document 2.txt")
        #expect(DocumentName.untitled(among: ["Untitled Document.txt", "Untitled Document 2.txt"], extension: "md") == "Untitled Document.md")
    }

    @Test func names() {
        #expect(DocumentName.problem(with: "notes.txt") == nil)
        #expect(DocumentName.problem(with: "") != nil)
        #expect(DocumentName.problem(with: "a/b") != nil)
        #expect(DocumentName.problem(with: "..") != nil)
        #expect(DocumentName.problem(with: String(repeating: "a", count: 256)) != nil)
    }
}
