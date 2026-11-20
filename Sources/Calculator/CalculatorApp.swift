//
//  CalculatorApp.swift
//  CoreApps
//

import AppUI
import CoreAppsUI

/// The calculator app.
public struct CalculatorApp: App {

    public init() { }

    public var body: some Scene {
        #if Native
        WindowGroup("Calculator") {
            CalculatorView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            CalculatorView()
        }
        #endif
    }
}

#if !Native

/// A guest's entry point: the host calls it once after loading the app.
@_expose(wasm, "rt_main")
@c(rt_main)
public func calculatorMain() -> rt_status {
    Runtime.main { CalculatorApp.run() }
}

#endif
