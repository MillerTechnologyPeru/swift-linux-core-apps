//
//  BrowserApp.swift
//  CoreApps
//

import AppUI
import CoreAppsUI

/// The web browser.
public struct BrowserApp: App {

    public init() { }

    public var body: some Scene {
        #if Native || (Apple && os(macOS))
        // On a desktop the window opens at a phone's size.
        WindowGroup("Browser") {
            BrowserView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            BrowserView()
        }
        #endif
    }
}

#if !Native && !Apple

/// A guest's entry point: the host calls it once after loading the app.
@_expose(wasm, "rt_main")
@c(rt_main)
public func browserMain() -> rt_status {
    Runtime.main { BrowserApp.run() }
}

#endif
