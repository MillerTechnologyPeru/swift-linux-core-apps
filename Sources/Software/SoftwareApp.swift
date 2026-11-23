//
//  SoftwareApp.swift
//  CoreApps
//

// The software store installs and removes software for the whole system,
// which a guest can't: it is a program only, on Cacao or on Apple's
// SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import Foundation

/// The software store.
public struct SoftwareApp: App {

    public init() { }

    public var body: some Scene {
        #if Native || (Apple && os(macOS))
        // On a desktop the window opens at a phone's size.
        WindowGroup("Software") {
            SoftwareView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            SoftwareView()
        }
        #endif
    }
}

/// The store's tabs: finding apps, those installed, and their updates.
struct SoftwareView: View {

    @State private var model = SoftwareModel()

    var body: some View {
        TabView {
            ExploreView(model: model)
                .tabItem {
                    Label("Explore", systemImage: "storefront")
                }
            InstalledView(model: model)
                .tabItem {
                    Label("Installed", systemImage: "square.grid.2x2")
                }
            UpdatesView(model: model)
                .tabItem {
                    Label("Updates", systemImage: "arrow.down.circle")
                }
                .badge(model.updates.count)
        }
        .task {
            await model.load()
            if let bundle = Self.bundleArgument {
                await model.installBundle(at: bundle)
            }
        }
        .alert("Something Went Wrong", isPresented: problemIsShown) {
            Button("OK") { model.problem = nil }
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var problemIsShown: Binding<Bool> {
        Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
    }

    /// An AppRuntime bundle given on the command line, to install:
    /// `software MyApp.app`.
    private nonisolated static var bundleArgument: URL? {
        guard CommandLine.arguments.count > 1 else { return nil }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        return url.pathExtension == "app" ? url : nil
    }
}

#endif
