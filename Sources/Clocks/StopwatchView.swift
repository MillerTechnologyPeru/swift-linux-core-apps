//
//  StopwatchView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ClocksCore
import CoreAppsUI
import Foundation

/// The stopwatch, and its laps.
struct StopwatchView: View {

    @EnvironmentObject private var model: ClocksModel

    var body: some View {
        VStack(spacing: 0) {
            // A twentieth of a second is as often as the time is drawn.
            TimelineView(.periodic(from: Date(), by: 0.05)) { _ in
                Text(TimeText.stopwatch(model.stopwatch.elapsed(at: ClocksModel.now)))
                    .font(.system(size: 56, weight: .thin).monospacedDigit())
                    .lineLimit(1)
                    .padding(.vertical, 32)
            }
            HStack {
                CircleButton(
                    title: model.stopwatch.isRunning || model.stopwatch.isReset ? "Lap" : "Reset",
                    tint: Color.secondary
                ) {
                    if model.stopwatch.isRunning {
                        model.stopwatch.lap(at: ClocksModel.now)
                    } else {
                        model.stopwatch.reset()
                    }
                }
                .disabled(model.stopwatch.isReset)
                Spacer()
                CircleButton(
                    title: model.stopwatch.isRunning ? "Stop" : "Start",
                    tint: model.stopwatch.isRunning ? Color.red : Color.green
                ) {
                    if model.stopwatch.isRunning {
                        model.stopwatch.stop(at: ClocksModel.now)
                    } else {
                        model.stopwatch.start(at: ClocksModel.now)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            laps
        }
        .navigationTitle("Stopwatch")
    }

    @ViewBuilder
    private var laps: some View {
        let stopwatch = model.stopwatch
        if stopwatch.laps.isEmpty && stopwatch.isReset {
            Spacer()
        } else {
            List {
                if !stopwatch.isReset {
                    TimelineView(.periodic(from: Date(), by: 0.1)) { _ in
                        lapRow("Lap \(stopwatch.laps.count + 1)", stopwatch.currentLap(at: ClocksModel.now), color: Color.primary)
                    }
                }
                ForEach(Array(stopwatch.laps.enumerated()).reversed(), id: \.offset) { index, length in
                    lapRow("Lap \(index + 1)", length, color: color(of: index))
                }
            }
        }
    }

    private func color(of lap: Int) -> Color {
        if lap == model.stopwatch.fastestLap { return Color.green }
        if lap == model.stopwatch.slowestLap { return Color.red }
        return Color.primary
    }

    private func lapRow(_ title: String, _ length: Double, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(TimeText.stopwatch(length))
                .font(.body.monospacedDigit())
        }
        .foregroundStyle(color)
    }
}

/// A round button, as clocks have for starting and stopping.
struct CircleButton: View {

    let title: String

    let tint: Color

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 84, height: 84)
                .background(Circle().fill(tint.opacity(0.18)))
        }
        .plainButton()
    }
}

#endif
