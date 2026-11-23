//
//  SoftwareModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import Foundation
import Observation
import SoftwareCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What the store knows and does: Flathub's catalog, the apps installed
/// from Flatpak and as AppRuntime bundles, their updates, and installing,
/// updating and removing them through `flatpak` and `linux-app`.
@Observable
final class SoftwareModel {

    // MARK: State

    /// The apps the Flatpak remotes offer, from their AppStream catalog.
    private(set) var catalog: [CatalogApp] = []

    private(set) var isLoadingCatalog = false

    private(set) var installed: [InstalledApp] = []

    private(set) var updates: [AvailableUpdate] = []

    private(set) var isRefreshing = false

    /// What's being done to each app, by its identifier.
    private(set) var operations: [String: Operation] = [:]

    /// Why the last thing asked for didn't happen.
    var problem: String?

    /// `flatpak`, when it's installed.
    let flatpak = Command.find("flatpak")

    /// `linux-app`, which installs AppRuntime bundles, when it's installed.
    let linuxApp = Command.find("linux-app")

    enum Operation: Equatable {
        case installing
        case updating
        case removing

        var description: String {
            switch self {
            case .installing: "Installing…"
            case .updating: "Updating…"
            case .removing: "Removing…"
            }
        }
    }

    /// The catalog by identifier. Observed, so a page asking for an app
    /// before the catalog is read shows it once it is.
    private var catalogByID: [String: CatalogApp] = [:]

    @ObservationIgnored private var catalogDirectory: URL?

    @ObservationIgnored private var icons: [String: Image] = [:]

    @ObservationIgnored private var hasLoaded = false

    // MARK: Loading

    /// Reads the catalog and what's installed, once.
    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        async let catalog: Void = loadCatalog()
        async let refreshed: Void = refresh()
        _ = await (catalog, refreshed)
    }

    /// The catalog a Flatpak remote keeps on disk: the user's, or else the
    /// system's.
    private func loadCatalog() async {
        guard let directory = Self.catalogDirectory() else { return }
        catalogDirectory = directory
        isLoadingCatalog = true
        let file = directory.appendingPathComponent("appstream.xml")
        let apps = await Task.detached(priority: .userInitiated) {
            (try? Data(contentsOf: file)).map(AppStream.parse) ?? []
        }.value
        catalog = apps
        catalogByID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        isLoadingCatalog = false
    }

    /// Lists what's installed, and its updates.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        var apps: [InstalledApp] = []
        var updates: [AvailableUpdate] = []
        if let flatpak, let result = await Command.run(flatpak, FlatpakTable.installedArguments), result.succeeded {
            apps += FlatpakTable.installed(result.output)
            for installation in [Installation.user, .system] {
                if let result = await Command.run(flatpak, FlatpakTable.updateArguments(installation)), result.succeeded {
                    updates += FlatpakTable.updates(result.output, installation: installation)
                }
            }
        }
        apps += await Self.installedBundles()
        installed = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.updates = updates
    }

    // MARK: Looking up

    func catalogApp(_ id: String) -> CatalogApp? {
        catalogByID[id]
    }

    /// The installs of an app, the user's first.
    func installs(of id: String) -> [InstalledApp] {
        installed.filter { $0.appID == id }.sorted { $0.installation == .user && $1.installation == .system }
    }

    func update(for app: InstalledApp) -> AvailableUpdate? {
        guard app.source == .flatpak else { return nil }
        return updates.first { $0.appID == app.appID && $0.installation == app.installation }
    }

    /// The app's icon from the catalog, at 64 pixels.
    func icon(for id: String) -> Image? {
        if let icon = icons[id] {
            return icon
        }
        guard let name = catalogByID[id]?.icon, let directory = catalogDirectory else { return nil }
        for size in ["64x64", "128x128"] {
            let file = directory.appendingPathComponent("icons/\(size)/\(name)")
            if let data = try? Data(contentsOf: file), let image = Self.image(png: data) {
                icons[id] = image
                return image
            }
        }
        return nil
    }

    // MARK: Changing

    /// Installs an app from the catalog: for the user when the user has
    /// the remote, which needs no password, or else for everyone.
    func install(_ app: CatalogApp) async {
        guard let flatpak else {
            problem = "Flatpak isn't installed, so apps can't be installed from Flathub."
            return
        }
        let installation = await remoteInstallation(for: "flathub")
        var arguments = ["install", "--" + installation.rawValue, "--noninteractive", "-y", "flathub", app.id]
        if let branch = app.branch {
            arguments[arguments.count - 1] = "\(app.id)//\(branch)"
        }
        await perform(.installing, on: app.id, failure: "\(app.name) couldn't be installed") {
            await Command.run(flatpak, arguments)
        }
    }

    func update(_ app: InstalledApp) async {
        guard let flatpak, app.source == .flatpak else { return }
        await perform(.updating, on: app.appID, failure: "\(app.name) couldn't be updated") {
            await Command.run(flatpak, ["update", "--" + app.installation.rawValue, "--noninteractive", "-y", app.appID])
        }
    }

    /// Updates every app with an update, one after another.
    func updateAll() async {
        for update in updates {
            if let app = installed.first(where: { $0.appID == update.appID && $0.installation == update.installation }) {
                await self.update(app)
            }
        }
    }

    func remove(_ app: InstalledApp) async {
        switch app.source {
        case .flatpak:
            guard let flatpak else { return }
            await perform(.removing, on: app.appID, failure: "\(app.name) couldn't be removed") {
                await Command.run(flatpak, ["uninstall", "--" + app.installation.rawValue, "--noninteractive", "-y", app.appID])
            }
        case .appRuntime:
            guard let path = app.path else { return }
            operations[app.appID] = .removing
            let files = AppBundle.files(ofBundleAt: path, identifier: app.appID)
            let failed = await Task.detached {
                files.filter { file in
                    FileManager.default.fileExists(atPath: file) && (try? FileManager.default.removeItem(atPath: file)) == nil
                }
            }.value
            operations[app.appID] = nil
            if failed.contains(path) {
                problem = "\(app.name) couldn't be removed: you may not be allowed to change \(AppBundle.parent(of: path))."
            }
            await refresh()
        }
    }

    /// Installs an AppRuntime bundle for the user with `linux-app`.
    func installBundle(at url: URL) async {
        guard let linuxApp else {
            problem = "LinuxAppRuntime's linux-app isn't installed, so bundles can't be installed."
            return
        }
        let name = url.deletingPathExtension().lastPathComponent
        await perform(.installing, on: name, failure: "\(name) couldn't be installed") {
            await Command.run(linuxApp, ["install", url.path])
        }
    }

    /// Opens an installed app.
    func open(_ app: InstalledApp) {
        switch app.source {
        case .flatpak:
            guard let flatpak else { return }
            var arguments = ["run", "--" + app.installation.rawValue]
            if !app.branch.isEmpty {
                arguments.append("--branch=" + app.branch)
            }
            arguments.append(app.appID)
            if !Command.launch(flatpak, arguments) {
                problem = "\(app.name) couldn't be opened."
            }
        case .appRuntime:
            let runner = ProcessInfo.processInfo.environment["LINUXAPPRUNTIME_RUNNER"].flatMap { $0.isEmpty ? nil : $0 }
                ?? Command.find("linux-app-host")
            guard let runner, let path = app.path, Command.launch(runner, [path]) else {
                problem = "\(app.name) couldn't be opened: LinuxAppRuntime's linux-app-host isn't installed."
                return
            }
        }
    }

    /// Runs a change to an app, marks the app as changing meanwhile, says
    /// why it failed, and lists what's installed again.
    private func perform(_ operation: Operation, on id: String, failure: String, _ command: () async -> CommandResult?) async {
        guard operations[id] == nil else { return }
        operations[id] = operation
        let result = await command()
        operations[id] = nil
        if let result, !result.succeeded {
            let reason = FlatpakTable.failure(result.errorOutput.isEmpty ? result.output : result.errorOutput)
            problem = reason.isEmpty ? failure + "." : failure + ": " + reason
        } else if result == nil {
            problem = failure + "."
        }
        await refresh()
    }

    /// The user's installation when the user has the remote, and everyone's
    /// otherwise.
    private func remoteInstallation(for remote: String) async -> Installation {
        guard let flatpak, let result = await Command.run(flatpak, ["remotes", "--user", "--columns=name"]) else {
            return .system
        }
        let names = result.output.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        return names.contains(remote) ? .user : .system
    }

    // MARK: Where things are

    /// `appstream/flathub/<arch>/active` of the user's Flatpak, or else the
    /// system's.
    private static func catalogDirectory() -> URL? {
        #if arch(arm64)
        let arch = "aarch64"
        #else
        let arch = "x86_64"
        #endif
        let environment = ProcessInfo.processInfo.environment
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let data = environment["XDG_DATA_HOME"].flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
            ?? home.appendingPathComponent(".local/share")
        let roots = [data.appendingPathComponent("flatpak"), URL(fileURLWithPath: "/var/lib/flatpak")]
        for root in roots {
            let directory = root.appendingPathComponent("appstream/flathub/\(arch)/active")
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("appstream.xml").path) {
                return directory
            }
        }
        return nil
    }

    /// The AppRuntime bundles under LinuxAppRuntime's prefixes.
    private static func installedBundles() async -> [InstalledApp] {
        await Task.detached {
            let home = NSHomeDirectory()
            var apps: [InstalledApp] = []
            for prefix in AppBundle.prefixes(environment: ProcessInfo.processInfo.environment, home: home) {
                let directory = prefix + "/" + AppBundle.directory
                guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
                for name in names.sorted() where name.hasSuffix(".app") {
                    let path = directory + "/" + name
                    guard let data = FileManager.default.contents(atPath: path + "/Info.plist"),
                          let app = AppBundle.app(infoPlist: data, path: path,
                                                  installation: AppBundle.installation(of: prefix, home: home)) else { continue }
                    apps.append(app)
                }
            }
            return apps
        }.value
    }

    private static func image(png data: Data) -> Image? {
        #if Native
        return Image(pngData: data)
        #elseif canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #else
        return NSImage(data: data).map { Image(nsImage: $0) }
        #endif
    }
}

#endif
