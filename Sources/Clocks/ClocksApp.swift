//
//  ClocksApp.swift
//  CoreApps
//

// The clocks ring only while they're open, there being no service yet to
// wake an app for an alarm: they're a program for now, on Cacao or on
// Apple's SwiftUI.
#if Native || Apple

import AppUI
import ClocksCore
import CoreAppsUI
import Foundation

/// The clocks.
public struct ClocksApp: App {

    public init() { }

    public var body: some Scene {
        #if Native || os(macOS)
        // On a desktop the window opens at a phone's size.
        WindowGroup("Clocks") {
            ClocksView()
        }
        .defaultSize(width: Metrics.phoneSize.width, height: Metrics.phoneSize.height)
        #else
        WindowGroup {
            ClocksView()
        }
        #endif
    }
}

/// The clocks' tabs.
enum ClocksTab: Hashable {
    case worldClock
    case alarms
    case stopwatch
    case timer
}

/// A tab per clock, and whatever's ringing over them.
public struct ClocksView: View {

    @StateObject private var model = ClocksModel()

    @State private var tab = ClocksTab.worldClock

    public init() { }

    public var body: some View {
        TabView(selection: $tab) {
            NavigationStack { WorldClockView() }
                .tabItem { Label("World Clock", systemImage: "globe") }
                .tag(ClocksTab.worldClock)
            NavigationStack { AlarmsView() }
                .tabItem { Label("Alarms", systemImage: "bell") }
                .tag(ClocksTab.alarms)
            NavigationStack { StopwatchView() }
                .tabItem { Label("Stopwatch", systemImage: Self.stopwatchSymbol) }
                .tag(ClocksTab.stopwatch)
            NavigationStack { TimerView() }
                .tabItem { Label("Timer", systemImage: Self.timerSymbol) }
                .tag(ClocksTab.timer)
        }
        .environmentObject(model)
        .alert(model.ringing?.title ?? "", isPresented: ringingIsShown) {
            if case .alarm = model.ringing {
                Button("Snooze") { model.snooze() }
            }
            Button("Stop", role: .cancel) { model.stopRinging() }
        } message: {
            Text(ringingMessage)
        }
        .task {
            await model.poll()
        }
    }

    /// Cacao's symbols have no stopwatch or timer.
    #if Apple
    private static let stopwatchSymbol = "stopwatch"
    private static let timerSymbol = "timer"
    #else
    private static let stopwatchSymbol = "flag"
    private static let timerSymbol = "clock"
    #endif

    private var ringingIsShown: Binding<Bool> {
        Binding(get: { model.ringing != nil }, set: { if !$0 { model.stopRinging() } })
    }

    private var ringingMessage: String {
        switch model.ringing {
        case let .alarm(alarm):
            TimeText.timeOfDay(hour: alarm.hour, minute: alarm.minute, uses24Hour: model.uses24Hour)
        case .timer:
            "Time's up."
        case nil:
            ""
        }
    }
}

#endif
