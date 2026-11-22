//
//  TextSearch.swift
//  CoreApps
//

/// A place a search found its text.
public struct TextMatch: Hashable, Sendable {

    /// The line it's on, counting from 1.
    public var line: Int

    /// The character of the line it starts at, counting from 1.
    public var column: Int

    /// The line's text, for showing the match where it is.
    public var lineText: String

    public init(line: Int, column: Int, lineText: String) {
        self.line = line
        self.column = column
        self.lineText = lineText
    }
}

/// Finding and replacing text.
public struct TextSearch: Hashable, Sendable {

    public var pattern: String

    /// Whether capitals must match.
    public var isCaseSensitive: Bool

    /// Whether the text must stand as a word, not inside a longer one.
    public var matchesWholeWords: Bool

    public init(_ pattern: String, isCaseSensitive: Bool = false, matchesWholeWords: Bool = false) {
        self.pattern = pattern
        self.isCaseSensitive = isCaseSensitive
        self.matchesWholeWords = matchesWholeWords
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private func same(_ a: Character, _ b: Character) -> Bool {
        isCaseSensitive ? a == b : a == b || a.lowercased() == b.lowercased()
    }

    /// Where the pattern starts in a run of characters, each match after
    /// the end of the one before.
    private func starts(in characters: [Character]) -> [Int] {
        let wanted = Array(pattern)
        guard !wanted.isEmpty, characters.count >= wanted.count else { return [] }
        var found: [Int] = []
        var index = 0
        let last = characters.count - wanted.count
        while index <= last {
            var matches = true
            for offset in wanted.indices where !same(characters[index + offset], wanted[offset]) {
                matches = false
                break
            }
            if matches, matchesWholeWords {
                let before = index > 0 && Self.isWordCharacter(characters[index - 1])
                let after = index + wanted.count < characters.count && Self.isWordCharacter(characters[index + wanted.count])
                matches = !before && !after
            }
            if matches {
                found.append(index)
                index += wanted.count
            } else {
                index += 1
            }
        }
        return found
    }

    /// Every place the pattern is in a text. A pattern is looked for
    /// within lines: one with a line break in it finds nothing.
    ///
    /// - Parameter limit: The most places to find.
    public func matches(in text: String, limit: Int = 10_000) -> [TextMatch] {
        guard !pattern.isEmpty else { return [] }
        var found: [TextMatch] = []
        var number = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            number += 1
            let characters = Array(line)
            for start in starts(in: characters) {
                found.append(TextMatch(line: number, column: start + 1, lineText: String(line)))
                if found.count >= limit { return found }
            }
        }
        return found
    }

    /// How many places the pattern is in a text.
    public func count(in text: String) -> Int {
        guard !pattern.isEmpty else { return 0 }
        return starts(in: Array(text)).count
    }

    /// A text with every place the pattern is replaced.
    ///
    /// - Returns: The new text, and how many places were replaced.
    public func replacingAll(in text: String, with replacement: String) -> (text: String, count: Int) {
        guard !pattern.isEmpty else { return (text, 0) }
        let characters = Array(text)
        let found = starts(in: characters)
        guard !found.isEmpty else { return (text, 0) }
        let length = pattern.count
        var result = ""
        var index = 0
        for start in found {
            result.append(contentsOf: characters[index..<start])
            result.append(replacement)
            index = start + length
        }
        result.append(contentsOf: characters[index...])
        return (result, found.count)
    }

    /// A text with one match replaced: the one at a line and column.
    public func replacing(_ match: TextMatch, in text: String, with replacement: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.indices.contains(match.line - 1) else { return text }
        let characters = Array(lines[match.line - 1])
        let start = match.column - 1
        guard starts(in: characters).contains(start) else { return text }
        lines[match.line - 1] = String(characters[..<start]) + replacement + String(characters[(start + pattern.count)...])
        return lines.joined(separator: "\n")
    }
}

/// What a text amounts to.
public struct TextStatistics: Hashable, Sendable {

    public var lines: Int

    public var words: Int

    public var characters: Int

    /// The characters that aren't spaces or line breaks.
    public var charactersWithoutSpaces: Int

    /// The text's size as UTF-8.
    public var bytes: Int

    public init(_ text: String) {
        var words = 0, characters = 0, solid = 0, lines = 1
        var inWord = false
        for character in text {
            characters += 1
            if character == "\n" { lines += 1 }
            if character.isWhitespace {
                inWord = false
            } else {
                solid += 1
                if !inWord { words += 1 }
                inWord = true
            }
        }
        self.lines = lines
        self.words = words
        self.characters = characters
        self.charactersWithoutSpaces = solid
        self.bytes = text.utf8.count
    }
}
