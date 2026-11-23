//
//  PageErrorView.swift
//  CoreApps
//

import AppUI
import AppWeb
import BrowserCore
import CoreAppsUI

/// Why a page didn't open, over where it would be, with a way to try again.
struct PageErrorView: View {

    let error: WebError

    let url: String?

    let retry: () -> Void

    var body: some View {
        ZStack {
            // White, as the pages around it mostly are, with the text in
            // fixed grays to read on it.
            Color(white: 1)
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(Color(white: 0.45))
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(white: 0.1))
                    .multilineTextAlignment(.center)
                Text(message)
                    .foregroundStyle(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                Button("Try Again", action: retry)
                    .accessibilityIdentifier("try-again")
            }
            .padding(32)
        }
    }

    private var host: String? {
        url.map { WebAddress.summary(of: $0) }
    }

    private var symbol: String {
        switch error.code {
        case .network, .timedOut: "wifi.slash"
        case .security: "exclamationmark.shield"
        case .notPermitted: "nosign"
        default: "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch error.code {
        case .security: "This Connection Isn't Private"
        default: "Can't Open the Page"
        }
    }

    private var message: String {
        let place = host.map { "“\($0)”" } ?? "the page"
        switch error.code {
        case .network:
            return "The browser can't reach \(place). You may be offline, or the server can't be found."
        case .timedOut:
            return host.map { "“\($0)” took too long to answer." } ?? "The page took too long to answer."
        case .security:
            return "The certificate of \(place) isn't trusted, so what you send it could be read by others."
        case .badURL:
            return "The browser can't open this kind of address."
        case .notPermitted:
            return "The browser isn't allowed to use the network."
        default:
            return error.message.isEmpty ? "Something went wrong opening \(place)." : error.message
        }
    }
}
