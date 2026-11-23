//
//  CatalogSearch.swift
//  CoreApps
//

/// Finding apps in a catalog by what's typed.
public enum CatalogSearch {

    /// The apps matching every word of `query`, best first: an app named
    /// just that, then by how well each word matches. A word matches a word
    /// of the name (best), the start of one, a keyword, or the start of a
    /// word of the summary, the developer or the identifier. Case and
    /// accents are ignored.
    public static func search(_ query: String, in apps: [CatalogApp], limit: Int = 100) -> [CatalogApp] {
        let words = Self.words(query)
        guard !words.isEmpty else { return [] }
        let whole = words.joined(separator: " ")
        var scored: [(app: CatalogApp, score: Int, index: Int)] = []
        for (index, app) in apps.enumerated() {
            let fields = Fields(app)
            var total = 0
            for word in words {
                let score = fields.score(word)
                guard score > 0 else {
                    total = 0
                    break
                }
                total += score
            }
            if total > 0 {
                // The app named just what was typed comes first.
                if fields.name.joined(separator: " ") == whole {
                    total += 100
                }
                scored.append((app, total, index))
            }
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.prefix(limit).map { $0.app }
    }

    /// The apps in a category, by name.
    public static func apps(in category: AppCategory, from apps: [CatalogApp]) -> [CatalogApp] {
        apps.filter { $0.isGraphical && category.contains($0.categories) }
            .sorted { fold($0.name) < fold($1.name) }
    }

    /// The apps with the newest stable releases, newest first.
    public static func recentlyUpdated(_ apps: [CatalogApp], limit: Int = 12) -> [CatalogApp] {
        apps.filter { $0.isGraphical && ($0.latestRelease?.timestamp ?? 0) > 0 }
            .sorted { ($0.latestRelease?.timestamp ?? 0) > ($1.latestRelease?.timestamp ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Lowercased, without accents: `Café` is `cafe`.
    static func fold(_ text: String) -> String {
        var output = ""
        for scalar in text.lowercased().unicodeScalars {
            // Combining marks, which decomposed accented letters leave.
            if (0x300...0x36F).contains(scalar.value) { continue }
            output.unicodeScalars.append(Self.base(scalar))
        }
        return output
    }

    /// Latin letters with accents as their base letters.
    private static func base(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar {
        case "à", "á", "â", "ã", "ä", "å": "a"
        case "ç": "c"
        case "è", "é", "ê", "ë": "e"
        case "ì", "í", "î", "ï": "i"
        case "ñ": "n"
        case "ò", "ó", "ô", "õ", "ö", "ø": "o"
        case "ù", "ú", "û", "ü": "u"
        case "ý", "ÿ": "y"
        default: scalar
        }
    }

    /// Folded words: letters and digits, split at anything else.
    static func words(_ text: String) -> [String] {
        fold(text).split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    private struct Fields {
        let name: [String]
        let keywords: [String]
        let other: [String]
        let id: String

        init(_ app: CatalogApp) {
            name = CatalogSearch.words(app.name)
            keywords = app.keywords.flatMap(CatalogSearch.words)
            other = CatalogSearch.words(app.summary) + CatalogSearch.words(app.developer)
            id = CatalogSearch.fold(app.id)
        }

        func score(_ word: String) -> Int {
            if name.contains(word) { return 8 }
            if name.contains(where: { $0.hasPrefix(word) }) { return 6 }
            if keywords.contains(where: { $0.hasPrefix(word) }) { return 4 }
            if other.contains(where: { $0.hasPrefix(word) }) { return 2 }
            if id.contains(word) { return 1 }
            return 0
        }
    }
}
