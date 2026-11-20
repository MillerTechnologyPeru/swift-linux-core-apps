//
//  PlainButton.swift
//  CoreApps
//

import AppUI

extension View {

    /// Draws a button as its label alone, where the flavor has button
    /// styles. A guest's host draws buttons its own way.
    @ViewBuilder
    public func plainButton() -> some View {
        #if Native
        self.buttonStyle(.plain)
        #else
        self
        #endif
    }
}
