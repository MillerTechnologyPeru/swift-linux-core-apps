//
//  SettingsApp.swift
//  CoreApps
//

// Settings talks to the desktop's services over D-Bus, which a guest
// can't: it is a program only, on Cacao or on Apple's SwiftUI.
#if Native || Apple

import AppUI
import CoreAppsUI
import SettingsCore

/// The system's settings.
public struct SettingsApp: App {

    public init() { }

    public var body: some Scene {
        #if Native || (Apple && os(macOS))
        // On a desktop the window opens at a phone's size.
        WindowGroup("Settings") {
            SettingsView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            SettingsView()
        }
        #endif
    }
}

/// The panes in a sidebar, and the one picked beside it; one over the
/// other at a phone's width.
struct SettingsView: View {

    @State private var model = SettingsModel()

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(SettingsPane.groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.panes) { pane in
                            NavigationLink {
                                PaneView(pane: pane, model: model)
                            } label: {
                                Label(pane.title, systemImage: pane.symbolName)
                                    .frame(minHeight: Metrics.minimumTarget)
                            }
                            .accessibilityIdentifier("pane-\(pane.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        } detail: {
            PaneView(pane: .appearance, model: model)
        }
        .task {
            await model.start()
        }
        .alert("Couldn't Change That", isPresented: problemIsShown) {
            Button("OK") { model.problem = nil }
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var problemIsShown: Binding<Bool> {
        Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
    }
}

/// A pane, or what it will be.
struct PaneView: View {

    let pane: SettingsPane

    let model: SettingsModel

    var body: some View {
        if pane.isAvailable {
            AppearanceView(model: model)
        } else {
            EmptyState(
                "Not Here Yet",
                message: pane.plannedService.map { "\(pane.title) will come with \($0)." }
            )
            .navigationTitle(pane.title)
        }
    }
}

#endif
