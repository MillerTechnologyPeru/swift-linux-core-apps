//
//  EmptyState.swift
//  CoreApps
//

import AppUI

/// What a screen shows when it has nothing to list: a title, and a line
/// saying why or what to do, centered in the space.
public struct EmptyState: View {

    private let title: String

    private let message: String?

    public init(_ title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(Metrics.screenPadding)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}
