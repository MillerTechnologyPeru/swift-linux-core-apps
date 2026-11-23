//
//  InstalledView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation
import SoftwareCore

/// The apps installed, by where they came from, and installing an
/// AppRuntime bundle.
struct InstalledView: View {

    let model: SoftwareModel

    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Installed")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isImporting = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Install an AppRuntime Bundle")
                        .disabled(model.linuxApp == nil)
                        .accessibilityIdentifier("install-bundle")
                    }
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item]) { result in
                    guard case .success(let url) = result else { return }
                    guard let bundle = Self.bundle(containing: url) else {
                        model.problem = "That isn't in an AppRuntime bundle: choose the bundle's .app, or a file inside it."
                        return
                    }
                    Task { await model.installBundle(at: bundle) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.installed.isEmpty {
            if model.isRefreshing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState("Nothing Installed", message: "Apps you install from Explore, and AppRuntime bundles, show here.")
            }
        } else {
            List {
                section(.flatpak)
                section(.appRuntime)
            }
        }
    }

    @ViewBuilder
    private func section(_ source: SoftwareSource) -> some View {
        let apps = model.installed.filter { $0.source == source }
        if !apps.isEmpty {
            Section(source.name) {
                ForEach(apps) { app in
                    NavigationLink(destination: AppDetailView(model: model, installed: app)) {
                        AppRow(model: model, id: app.appID, name: app.name, detail: detail(app))
                    }
                }
            }
        }
    }

    private func detail(_ app: InstalledApp) -> String {
        var parts: [String] = []
        if !app.version.isEmpty { parts.append(app.version) }
        if !app.size.isEmpty { parts.append(app.size) }
        parts.append(app.installation.name)
        return parts.joined(separator: " · ")
    }

    /// The `.app` directory a picked file is, or is inside.
    static func bundle(containing url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        while candidate.path != "/" {
            if candidate.pathExtension == "app" {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }
}

#endif
