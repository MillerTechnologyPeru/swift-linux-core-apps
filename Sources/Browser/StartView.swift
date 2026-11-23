//
//  StartView.swift
//  CoreApps
//

import AppUI
import BrowserCore
import CoreAppsUI

/// A new tab: the bookmarks as favorites, and the pages gone to lately.
struct StartView: View {

    let bookmarks: [Bookmark]

    let recent: [Visit]

    let open: (String) -> Void

    var body: some View {
        if bookmarks.isEmpty && recent.isEmpty {
            EmptyState("Start Browsing", message: "Type an address or a search into the bar below. Pages you bookmark show here.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !bookmarks.isEmpty {
                        section("Favorites") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 12)], spacing: 16) {
                                ForEach(bookmarks) { bookmark in
                                    Button {
                                        open(bookmark.url)
                                    } label: {
                                        Favorite(title: bookmark.displayTitle, url: bookmark.url)
                                    }
                                    .plainButton()
                                }
                            }
                        }
                    }
                    if !recent.isEmpty {
                        section("Recently Visited") {
                            VStack(spacing: 0) {
                                ForEach(recent) { visit in
                                    Button {
                                        open(visit.url)
                                    } label: {
                                        PageRow(title: visit.displayTitle, url: visit.url, symbol: "clock")
                                    }
                                    .plainButton()
                                }
                            }
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            content()
        }
    }
}

/// A favorite: the host's first letter on a tile, with the title under it.
struct Favorite: View {

    let title: String

    let url: String

    var body: some View {
        VStack(spacing: 6) {
            Text(initial)
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 60, height: 60)
                .background(BrowserColors.field)
                .cornerRadius(14)
            Text(title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var initial: String {
        let host = WebAddress(url)?.displayHost ?? ""
        guard let first = (host.isEmpty ? title : host).first else { return "?" }
        return String(first).uppercased()
    }
}

/// A page in a list: its title, and its host under it.
struct PageRow: View {

    let title: String

    let url: String

    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(WebAddress.summary(of: url))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(minHeight: Metrics.minimumTarget)
    }
}
