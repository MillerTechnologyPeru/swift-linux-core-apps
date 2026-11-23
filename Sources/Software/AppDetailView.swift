//
//  AppDetailView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import SoftwareCore

/// An app's page: install, open, update or remove it, what it is, what's
/// new, and where it comes from.
struct AppDetailView: View {

    let model: SoftwareModel

    let id: String

    /// What the catalog says, when the app is in it, once it's read.
    private var app: CatalogApp? {
        model.catalogApp(id) ?? listed
    }

    /// The catalog's entry this page was opened from.
    private let listed: CatalogApp?

    /// An install to fall back on for an app the catalog doesn't have.
    let fallback: InstalledApp?

    @State private var removing: InstalledApp?

    init(model: SoftwareModel, app: CatalogApp) {
        self.model = model
        self.id = app.id
        self.listed = app
        self.fallback = nil
    }

    init(model: SoftwareModel, installed: InstalledApp) {
        self.model = model
        self.id = installed.appID
        self.listed = nil
        self.fallback = installed
    }

    var body: some View {
        List {
            Section {
                header
                actions
            }
            if let app, !app.description.isEmpty {
                Section("About") {
                    DescriptionText(blocks: app.description)
                }
            }
            if let release = app?.latestRelease {
                Section("What's New") {
                    Text("Version \(release.version)")
                        .fontWeight(.semibold)
                    if !release.notes.isEmpty {
                        DescriptionText(blocks: release.notes)
                    }
                }
            }
            Section("Information") {
                information
            }
        }
        .navigationTitle(name)
        .confirmationDialog(
            "Remove \(removing?.name ?? name)?",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
        ) {
            Button("Remove", role: .destructive) {
                guard let app = removing else { return }
                removing = nil
                Task { await model.remove(app) }
            }
        } message: {
            Text("Its settings and data stay, in case you install it again.")
        }
    }

    private var name: String {
        app?.name ?? fallback?.name ?? id
    }

    private var installs: [InstalledApp] {
        let installs = model.installs(of: id)
        if installs.isEmpty, let fallback, model.installed.contains(fallback) {
            return [fallback]
        }
        return installs
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            AppIcon(model: model, id: id, name: name, size: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                if let developer = app?.developer, !developer.isEmpty {
                    Text(developer)
                        .foregroundStyle(Color.secondary)
                }
                if let summary = app?.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.footnote)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actions: some View {
        if let operation = model.operations[id] {
            HStack(spacing: 12) {
                ProgressView()
                Text(operation.description)
                    .foregroundStyle(Color.secondary)
            }
            .frame(minHeight: Metrics.minimumTarget)
        } else if let installed = installs.first {
            HStack(spacing: 12) {
                Button("Open") {
                    model.open(installed)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("open")
                if model.update(for: installed) != nil {
                    Button("Update") {
                        Task { await model.update(installed) }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("update")
                }
                Spacer()
                Button("Remove", role: .destructive) {
                    removing = installed
                }
                .accessibilityIdentifier("remove")
            }
            .frame(minHeight: Metrics.minimumTarget)
        } else if let app {
            Button {
                Task { await model.install(app) }
            } label: {
                Text("Install")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.flatpak == nil)
            .accessibilityIdentifier("install")
        }
    }

    // MARK: Information

    @ViewBuilder
    private var information: some View {
        if let version = installs.first?.version ?? app?.latestRelease?.version, !version.isEmpty {
            row("Version", version)
        }
        if let size = installs.first?.size, !size.isEmpty {
            row("Size", size)
        }
        if let app, !app.license.isEmpty {
            row("License", app.isFreeSoftware ? "Free software (\(app.license))" : "Proprietary")
        }
        if let installed = installs.first {
            row("Installed", installed.installation.name)
            row("Source", installed.origin.isEmpty ? installed.source.name : "\(installed.source.name), \(installed.origin)")
        } else if app != nil {
            row("Source", "Flatpak, Flathub")
        }
        row("Identifier", id)
        if let homepage = app?.homepage, let url = URL(string: homepage) {
            Link(destination: url) {
                HStack {
                    Text("Website")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A description's paragraphs and lists.
struct DescriptionText: View {

    let blocks: [DescriptionBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<blocks.count, id: \.self) { index in
                switch blocks[index] {
                case .paragraph(let text):
                    Text(text)
                case .list(let items):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<items.count, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                Text(items[item])
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#endif
