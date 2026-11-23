//
//  TabsView.swift
//  CoreApps
//

import AppUI
import AppWeb
import BrowserCore
import CoreAppsUI

/// The open tabs: tap one to show it, close any, or open a new one.
struct TabsView: View {

    let tabs: Tabs

    let pages: Pages

    let select: (Int) -> Void

    let close: (Int) -> Void

    let closeAll: () -> Void

    let openNew: () -> Void

    let done: () -> Void

    @State private var isConfirmingCloseAll = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(tabs.items) { tab in
                    HStack(spacing: 12) {
                        Button {
                            select(tab.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tab.id == tabs.selectedID ? "checkmark.circle" : "circle")
                                    .foregroundStyle(tab.id == tabs.selectedID ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title(of: tab))
                                        .lineLimit(1)
                                    if let url = url(of: tab) {
                                        Text(WebAddress.summary(of: url))
                                            .font(.footnote)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: Metrics.minimumTarget)
                        }
                        .plainButton()
                        Button {
                            close(tab.id)
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                        }
                        .plainButton()
                        .accessibilityLabel("Close \(title(of: tab))")
                    }
                    .swipeActions {
                        Button("Close", role: .destructive) {
                            close(tab.id)
                        }
                    }
                }
            }
            .navigationTitle(tabs.count == 1 ? "1 Tab" : "\(tabs.count) Tabs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close All") {
                        isConfirmingCloseAll = true
                    }
                    .disabled(tabs.count < 2)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: openNew) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("new-tab")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
            .confirmationDialog("Close all \(tabs.count) tabs?", isPresented: $isConfirmingCloseAll) {
                Button("Close All Tabs", role: .destructive, action: closeAll)
            }
        }
    }

    /// What the tab's page is called now, or what it was last run.
    private func title(of tab: BrowserTab) -> String {
        if let page = pages[tab.id], !page.title.isEmpty {
            return page.title
        }
        if let page = pages[tab.id], let url = page.url {
            return WebAddress.summary(of: url)
        }
        return tab.displayTitle
    }

    private func url(of tab: BrowserTab) -> String? {
        pages[tab.id]?.url ?? tab.url
    }
}
