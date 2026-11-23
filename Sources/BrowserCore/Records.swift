//
//  Records.swift
//  CoreApps
//

/// Rows of text fields, as one string for the app's defaults: a field
/// after each tab, a row after each newline, with a backslash before a
/// tab, newline or backslash in a field.
public enum Records {

    public static func encode(_ rows: [[String]]) -> String {
        var output: [UInt8] = []
        for row in rows {
            for (index, field) in row.enumerated() {
                if index > 0 {
                    output.append(UInt8(ascii: "\t"))
                }
                for byte in field.utf8 {
                    switch byte {
                    case UInt8(ascii: "\\"): output += [UInt8(ascii: "\\"), UInt8(ascii: "\\")]
                    case UInt8(ascii: "\t"): output += [UInt8(ascii: "\\"), UInt8(ascii: "t")]
                    case UInt8(ascii: "\n"): output += [UInt8(ascii: "\\"), UInt8(ascii: "n")]
                    case UInt8(ascii: "\r"): output += [UInt8(ascii: "\\"), UInt8(ascii: "r")]
                    default: output.append(byte)
                    }
                }
            }
            output.append(UInt8(ascii: "\n"))
        }
        return String(decoding: output, as: UTF8.self)
    }

    public static func decode(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var escaped = false
        for byte in text.utf8 {
            if escaped {
                switch byte {
                case UInt8(ascii: "t"): field.append(UInt8(ascii: "\t"))
                case UInt8(ascii: "n"): field.append(UInt8(ascii: "\n"))
                case UInt8(ascii: "r"): field.append(UInt8(ascii: "\r"))
                default: field.append(byte)
                }
                escaped = false
                continue
            }
            switch byte {
            case UInt8(ascii: "\\"):
                escaped = true
            case UInt8(ascii: "\t"):
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll()
            case UInt8(ascii: "\n"):
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll()
                rows.append(row)
                row.removeAll()
            default:
                field.append(byte)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(String(decoding: field, as: UTF8.self))
            rows.append(row)
        }
        return rows
    }
}

// MARK: - What the browser keeps

extension Bookmarks {

    /// A row for each bookmark: its title and address.
    public var record: String {
        Records.encode(items.map { [$0.title, $0.url] })
    }

    public init(record: String) {
        var items: [Bookmark] = []
        for row in Records.decode(record) where row.count >= 2 && !row[1].isEmpty {
            items.append(Bookmark(id: items.count + 1, title: row[0], url: row[1]))
        }
        self.init(items)
    }
}

extension History {

    /// A row for each page, latest first: its address, title and count.
    public var record: String {
        Records.encode(visits.map { [$0.url, $0.title, String($0.count)] })
    }

    public init(record: String, limit: Int = 1000) {
        var visits: [Visit] = []
        for row in Records.decode(record) where !row.isEmpty && !row[0].isEmpty && visits.count < limit {
            let title = row.count > 1 ? row[1] : ""
            let count = row.count > 2 ? Int(row[2]) ?? 1 : 1
            visits.append(Visit(url: row[0], title: title, count: max(count, 1)))
        }
        self.init(visits: visits, limit: limit)
    }
}

extension Tabs {

    /// The tabs to open again next time: a row for each, its address and
    /// title, and `selected` before the one shown.
    public var record: String {
        Records.encode(items.map { tab in
            [tab.id == selectedID ? "selected" : "", tab.url ?? "", tab.title]
        })
    }

    public init(record: String) {
        var items: [BrowserTab] = []
        var selectedID: Int?
        for row in Records.decode(record) where row.count >= 2 {
            let tab = BrowserTab(id: items.count + 1, url: row[1].isEmpty ? nil : row[1], title: row.count > 2 ? row[2] : "")
            if row[0] == "selected" {
                selectedID = tab.id
            }
            items.append(tab)
        }
        self.init(items, selectedID: selectedID)
    }
}
