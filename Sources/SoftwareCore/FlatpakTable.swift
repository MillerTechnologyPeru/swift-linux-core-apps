//
//  FlatpakTable.swift
//  CoreApps
//

/// What the `flatpak` command prints with `--columns`: a line for each
/// row, its columns separated by tabs, in the order asked for.
public enum FlatpakTable {

    /// The columns `installedArguments` asks for.
    public static let installedColumns = "application,name,version,branch,origin,installation,size"

    /// `flatpak list` for the apps, without runtimes.
    public static let installedArguments = ["list", "--app", "--columns=" + installedColumns]

    /// The columns `updateArguments(_:)` asks for.
    public static let updateColumns = "application,version,branch,origin"

    /// `flatpak remote-ls` for updates to one installation's apps.
    public static func updateArguments(_ installation: Installation) -> [String] {
        ["remote-ls", "--" + installation.rawValue, "--updates", "--app", "--columns=" + updateColumns]
    }

    /// The rows of a table, each split into its columns. Blank lines are
    /// skipped, and so are the header and messages `flatpak` sometimes
    /// prints, which have no tab.
    public static func rows(_ output: String) -> [[String]] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            guard line.contains("\t") else { return nil }
            return line.split(separator: "\t", omittingEmptySubsequences: false).map { String($0).trimmingWhitespace }
        }
    }

    /// The apps of `flatpak list` with `installedColumns`.
    public static func installed(_ output: String) -> [InstalledApp] {
        rows(output).compactMap { row in
            guard row.count >= 7, !row[0].isEmpty else { return nil }
            return InstalledApp(
                appID: row[0],
                name: row[1].isEmpty ? row[0] : row[1],
                version: row[2],
                source: .flatpak,
                installation: row[5] == "user" ? .user : .system,
                branch: row[3],
                origin: row[4],
                size: row[6]
            )
        }
    }

    /// The updates of `flatpak remote-ls --updates` with `updateColumns`.
    public static func updates(_ output: String, installation: Installation) -> [AvailableUpdate] {
        rows(output).compactMap { row in
            guard row.count >= 4, !row[0].isEmpty else { return nil }
            return AvailableUpdate(appID: row[0], installation: installation, version: row[1], branch: row[2], origin: row[3])
        }
    }

    /// The last thing `flatpak` said went wrong, for an error message:
    /// the last line starting with `error:`, without it, or else the last
    /// line.
    public static func failure(_ output: String) -> String {
        let lines = output.split(separator: "\n").map { String($0).trimmingWhitespace }.filter { !$0.isEmpty }
        if let error = lines.last(where: { $0.lowercased().hasPrefix("error:") }) {
            return String(error.dropFirst("error:".count)).trimmingWhitespace
        }
        return lines.last ?? ""
    }
}
