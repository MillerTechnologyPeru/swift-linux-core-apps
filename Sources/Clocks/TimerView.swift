//
//  TimerView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ClocksCore
import CoreAppsUI
import Foundation

/// The timer: its length set with pickers or a preset, then counted down.
struct TimerView: View {

    @EnvironmentObject private var model: ClocksModel

    @State private var hours = 0

    @State private var minutes = 5

    @State private var seconds = 0

    private static let presets = [1, 3, 5, 10, 15, 30, 60]

    var body: some View {
        Group {
            if model.timer.isStarted {
                running
            } else {
                setting
            }
        }
        .navigationTitle("Timer")
    }

    private var length: Double {
        Double(hours * 3600 + minutes * 60 + seconds)
    }

    // MARK: Setting

    private var setting: some View {
        Form {
            Section {
                Text(TimeText.countdown(length))
                    .font(.system(size: 56, weight: .thin).monospacedDigit())
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 8)
                Picker("Hours", selection: $hours) {
                    ForEach(0..<24, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Seconds", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text("\($0)").tag($0) }
                }
            }
            Section {
                Button("Start") {
                    model.timer.set(length)
                    model.timer.start(at: ClocksModel.now)
                }
                .disabled(length == 0)
            }
            Section("Presets") {
                ForEach(Self.presets, id: \.self) { preset in
                    Button(preset == 60 ? "1 hour" : (preset == 1 ? "1 minute" : "\(preset) minutes")) {
                        hours = preset / 60
                        minutes = preset % 60
                        seconds = 0
                    }
                }
            }
        }
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: Date(), by: 0.2)) { _ in
                let now = ClocksModel.now
                VStack(spacing: 12) {
                    Text(TimeText.countdown(model.timer.remaining(at: now)))
                        .font(.system(size: 64, weight: .thin).monospacedDigit())
                        .lineLimit(1)
                    ProgressView(value: model.timer.progress(at: now))
                        .padding(.horizontal, 32)
                    Text("of \(TimeText.countdown(model.timer.duration))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.top, 48)
            HStack {
                CircleButton(title: "Cancel", tint: Color.secondary) {
                    model.timer.cancel()
                }
                Spacer()
                CircleButton(title: "+1 min", tint: Color.accentColor) {
                    model.timer.add(60, at: ClocksModel.now)
                }
                Spacer()
                CircleButton(
                    title: model.timer.isRunning ? "Pause" : "Resume",
                    tint: model.timer.isRunning ? Color.orange : Color.green
                ) {
                    if model.timer.isRunning {
                        model.timer.pause(at: ClocksModel.now)
                    } else {
                        model.timer.start(at: ClocksModel.now)
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

#endif
