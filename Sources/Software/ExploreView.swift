//
//  ExploreView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import SoftwareCore

/// Finding apps: a search of the catalog, its categories, and the apps
/// updated lately.
struct ExploreView: View {

    let model: SoftwareModel

    @State private var query = ""

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Explore")
                .searchable(text: $query, prompt: "Search apps")
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.flatpak == nil {
            EmptyState("No Software Sources", message: "Flatpak isn't installed here, so there's no catalog of apps to explore. AppRuntime bundles are installed from the Installed tab.")
        } else if model.isLoadingCatalog && model.catalog.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading Flathub's catalog…")
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.catalog.isEmpty {
            EmptyState("No Catalog", message: "Flathub's catalog hasn't been downloaded. Run flatpak update --appstream, then open the store again.")
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            results
        } else {
            browse
        }
    }

    private var results: some View {
        let found = CatalogSearch.search(query, in: model.catalog)
        return List {
            if found.isEmpty {
                Text("No apps match “\(query)”.")
                    .foregroundStyle(Color.secondary)
            }
            ForEach(found) { app in
                NavigationLink(destination: AppDetailView(model: model, app: app)) {
                    AppRow(model: model, app: app)
                }
            }
        }
    }

    private var browse: some View {
        List {
            Section("Categories") {
                ForEach(AppCategory.allCases) { category in
                    NavigationLink(destination: CategoryView(model: model, category: category)) {
                        HStack(spacing: 12) {
                            Image(systemName: category.symbol)
                                .frame(width: 28)
                            Text(category.name)
                        }
                        .frame(minHeight: Metrics.minimumTarget)
                    }
                }
            }
            Section("Updated Lately") {
                ForEach(CatalogSearch.recentlyUpdated(model.catalog)) { app in
                    NavigationLink(destination: AppDetailView(model: model, app: app)) {
                        AppRow(model: model, app: app)
                    }
                }
            }
        }
    }
}

/// A category's apps, by name.
struct CategoryView: View {

    let model: SoftwareModel

    let category: AppCategory

    var body: some View {
        List {
            ForEach(CatalogSearch.apps(in: category, from: model.catalog)) { app in
                NavigationLink(destination: AppDetailView(model: model, app: app)) {
                    AppRow(model: model, app: app)
                }
            }
        }
        .navigationTitle(category.name)
    }
}

#endif
