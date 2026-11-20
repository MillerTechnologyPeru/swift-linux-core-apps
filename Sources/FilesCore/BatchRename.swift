//
//  BatchRename.swift
//  CoreApps
//

import Foundation

/// How several items are renamed at once.
public enum BatchRename: Hashable, Sendable {

    /// Each name is made from a template, in which `[Original]` stands for
    /// the item's name without its extension and `[1]`, `[01]` or `[001]`
    /// for the item's number, padded to that many digits. Extensions stay.
    case template(String)

    /// A text is replaced wherever it appears in each name.
    case replace(String, with: String)

    /// The new names of items, in their order.
    public func names(for items: [String]) -> [String] {
        switch self {
        case let .template(template):
            return items.enumerated().map { index, name in
                var stem = name, suffix = ""
                if let dot = name.lastIndex(of: "."), dot != name.startIndex {
                    stem = String(name[..<dot])
                    suffix = String(name[dot...])
                }
                var result = template.replacingOccurrences(of: "[Original]", with: stem)
                for (token, digits) in [("[001]", 3), ("[01]", 2), ("[1]", 1)] {
                    let number = String(index + 1)
                    let padded = String(repeating: "0", count: max(0, digits - number.count)) + number
                    result = result.replacingOccurrences(of: token, with: padded)
                }
                return result + suffix
            }
        case let .replace(text, replacement):
            guard !text.isEmpty else { return items }
            return items.map { $0.replacingOccurrences(of: text, with: replacement) }
        }
    }

    /// What stops the renaming: a bad name, or one that two items would
    /// share or another item of the folder has.
    ///
    /// - Parameter others: The names in the folder that aren't being
    ///   renamed.
    public func problem(for items: [String], among others: Set<String> = []) -> String? {
        let names = names(for: items).map(FileName.cleaned)
        var seen = others
        for name in names {
            if let problem = FileName.problem(with: name) { return problem.localizedDescription }
            if !seen.insert(name).inserted { return "Two items would be named “\(name)”." }
        }
        return nil
    }

    /// Renames items.
    ///
    /// - Returns: Where each went, for undoing.
    public func apply(to items: [URL]) throws -> [Transfer] {
        let names = names(for: items.map(\.lastPathComponent)).map(FileName.cleaned)
        guard let folder = items.first?.deletingLastPathComponent() else { return [] }
        let renamed = Set(items.map(\.lastPathComponent))
        let others = FileOperations.names(in: folder).subtracting(renamed)
        if let problem = problem(for: items.map(\.lastPathComponent), among: others) {
            throw FileOperations.Failure.unsupported(problem)
        }
        // Through names of their own first, so that swapping two names, or
        // shifting a numbered run by one, can't collide half way.
        var staged: [(URL, URL, URL)] = []
        for (item, name) in zip(items, names) where name != item.lastPathComponent {
            let temporary = folder.appendingPathComponent(".rename-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: item, to: temporary)
            staged.append((item, temporary, folder.appendingPathComponent(name)))
        }
        var transfers: [Transfer] = []
        for (source, temporary, destination) in staged {
            try FileManager.default.moveItem(at: temporary, to: destination)
            transfers.append(Transfer(source: source, destination: destination))
        }
        return transfers
    }
}
