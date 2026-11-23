//
//  SuggestionsView.swift
//  CoreApps
//

import AppUI
import BrowserCore
import CoreAppsUI

/// While the address bar is typed in: the search for what's typed, and the
/// bookmarks and history that match it.
struct SuggestionsView: View {

    let suggestions: [Suggestion]

    let typed: String

    let engine: SearchEngine

    let open: (String) -> Void

    /// Goes to what's typed, or searches for it, as Return does.
    let submit: () -> Void

    var body: some View {
        List {
            if let destination = AddressInput.destination(for: typed, engine: engine) {
                Section {
                    Button(action: submit) {
                        HStack(spacing: 12) {
                            Image(systemName: isSearch(destination) ? "magnifyingglass" : "globe")
                                .foregroundStyle(Color.secondary)
                                .frame(width: 24)
                            Text(isSearch(destination) ? "Search \(engine.name) for “\(typed)”" : "Go to \(WebAddress.summary(of: destination))")
                                .lineLimit(2)
                        }
                        .frame(minHeight: Metrics.minimumTarget)
                    }
                    .accessibilityIdentifier("submit-suggestion")
                }
            }
            if !suggestions.isEmpty {
                Section("Bookmarks and History") {
                    ForEach(suggestions) { suggestion in
                        Button {
                            open(suggestion.url)
                        } label: {
                            PageRow(title: suggestion.title, url: suggestion.url, symbol: suggestion.isBookmark ? "star" : "clock")
                        }
                    }
                }
            }
        }
    }

    private func isSearch(_ destination: String) -> Bool {
        engine.searchTerms(in: destination) != nil
    }
}
