//
//  AddressBar.swift
//  CoreApps
//

import AppUI
import CoreAppsUI

/// The address bar: where the page is, and, once tapped, a field to type
/// an address or a search into.
struct AddressBar: View {

    /// The page's host, search or address; `nil` for a new tab.
    let summary: String?

    let isSecure: Bool

    let isEditing: Bool

    let isLoading: Bool

    let hasPage: Bool

    @Binding var typed: String

    var isFieldFocused: FocusState<Bool>.Binding

    let beginEditing: () -> Void

    let endEditing: () -> Void

    let submit: () -> Void

    let reloadOrStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                TextField("Search or enter address", text: $typed)
                    .focused(isFieldFocused)
                    .onSubmit(submit)
                    .addressFieldInput()
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(BrowserColors.field)
                    .cornerRadius(10)
                    .accessibilityIdentifier("address-field")
                Button("Cancel", action: endEditing)
                    .accessibilityIdentifier("cancel-address")
            } else {
                Button(action: beginEditing) {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        if isSecure {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                        }
                        Text(summary ?? "Search or enter address")
                            .lineLimit(1)
                            .foregroundStyle(summary == nil ? Color.secondary : Color.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(BrowserColors.field)
                    .cornerRadius(10)
                }
                .plainButton()
                .accessibilityIdentifier("address")
                if hasPage {
                    Button(action: reloadOrStop) {
                        Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                            .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
                    }
                    .plainButton()
                    .accessibilityIdentifier(isLoading ? "stop" : "reload")
                }
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 8)
    }
}

/// The buttons under the address bar.
struct ToolbarRow: View {

    let canGoBack: Bool

    let canGoForward: Bool

    let isBookmarked: Bool

    let canBookmark: Bool

    let tabCount: Int

    let goBack: () -> Void

    let goForward: () -> Void

    let toggleBookmark: () -> Void

    let showLibrary: () -> Void

    let showTabs: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            button("chevron.left", "back", action: goBack)
                .disabled(!canGoBack)
            button("chevron.right", "forward", action: goForward)
                .disabled(!canGoForward)
            button(isBookmarked ? "star.fill" : "star", isBookmarked ? "remove-bookmark" : "add-bookmark", action: toggleBookmark)
                .disabled(!canBookmark)
            button("book", "library", action: showLibrary)
            Button(action: showTabs) {
                ZStack {
                    Image(systemName: "square")
                        .font(.title2)
                    Text(String(tabCount))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
            }
            .plainButton()
            .accessibilityIdentifier("tabs")
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private func button(_ symbol: String, _ identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTarget)
        }
        .plainButton()
        .accessibilityIdentifier(identifier)
    }
}

/// Colors the browser draws with, given as values: a guest's host doesn't
/// know every system color by name.
enum BrowserColors {

    /// Behind the address bar and the rows of the start page.
    static let field = Color(white: 0.5, opacity: 0.15)
}

extension View {

    /// An address isn't a sentence: no capitals or corrections, where the
    /// flavor has them.
    @ViewBuilder
    func addressFieldInput() -> some View {
        #if Apple && os(iOS)
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
        #elseif Apple || Native
        self.autocorrectionDisabled()
        #else
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #endif
    }
}
