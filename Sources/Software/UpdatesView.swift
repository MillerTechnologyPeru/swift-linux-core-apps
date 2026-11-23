//
//  UpdatesView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import SoftwareCore

/// Newer versions of the apps installed from Flatpak.
struct UpdatesView: View {

    let model: SoftwareModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Updates")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Check Again") {
                            Task { await model.refresh() }
                        }
                        .disabled(model.isRefreshing)
                        .accessibilityIdentifier("check-again")
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.updates.isEmpty {
            if model.isRefreshing {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState("Up to Date", message: model.flatpak == nil
                    ? "Flatpak isn't installed here, so there's nothing to update."
                    : "Every app installed from Flatpak is the newest version.")
            }
        } else {
            List {
                Section {
                    Button("Update All") {
                        Task { await model.updateAll() }
                    }
                    .disabled(!model.operations.isEmpty)
                    .accessibilityIdentifier("update-all")
                }
                Section("\(model.updates.count) Available") {
                    ForEach(model.updates) { update in
                        row(update)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ update: AvailableUpdate) -> some View {
        let installed = model.installed.first { $0.appID == update.appID && $0.installation == update.installation }
        let name = installed?.name ?? model.catalogApp(update.appID)?.name ?? update.appID
        HStack(spacing: 12) {
            AppRow(model: model, id: update.appID, name: name, detail: detail(update, from: installed))
            if model.operations[update.appID] == nil, let installed {
                Button("Update") {
                    Task { await model.update(installed) }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func detail(_ update: AvailableUpdate, from installed: InstalledApp?) -> String {
        let from = installed?.version ?? ""
        switch (from.isEmpty, update.version.isEmpty) {
        case (false, false) where from != update.version: return "\(from) → \(update.version)"
        case (_, false): return "Version \(update.version)"
        default: return update.installation.name
        }
    }
}

#endif
