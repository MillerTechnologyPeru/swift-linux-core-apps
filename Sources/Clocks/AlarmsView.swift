//
//  AlarmsView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import ClocksCore
import CoreAppsUI
import Foundation

/// The alarms, each turned on or off; tapped, one is edited.
struct AlarmsView: View {

    @EnvironmentObject private var model: ClocksModel

    /// The alarm being edited, new or not.
    @State private var editing: Alarm?

    var body: some View {
        Group {
            if model.alarms.isEmpty {
                EmptyState("No Alarms", message: "Add an alarm with the + button.")
            } else {
                TimelineView(.everyMinute) { _ in
                    List {
                        Section {
                            ForEach(model.alarms) { alarm in
                                row(alarm)
                            }
                        } footer: {
                            Text(footer)
                        }
                    }
                }
            }
        }
        .navigationTitle("Alarms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
                    editing = Alarm(id: UUID().uuidString, hour: parts.hour ?? 7, minute: parts.minute ?? 0)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { alarm in
            AlarmEditor(alarm: alarm, isNew: !model.alarms.contains { $0.id == alarm.id }) { result in
                editing = nil
                switch result {
                case let .save(changed): model.update(changed)
                case .delete: model.delete(alarm)
                case .cancel: break
                }
            }
        }
    }

    private var footer: String {
        let next = model.nextAlarm.map { "Next alarm \(TimeText.until($0.seconds)). " } ?? ""
        return next + "Alarms ring only while Clocks is open."
    }

    private func row(_ alarm: Alarm) -> some View {
        HStack {
            Button {
                editing = alarm
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeText.timeOfDay(hour: alarm.hour, minute: alarm.minute, uses24Hour: model.uses24Hour))
                        .font(.system(size: 36, weight: .light).monospacedDigit())
                    Text(alarm.days.isEmpty ? alarm.title : "\(alarm.title), \(alarm.days.summary.lowercased())")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(alarm.isEnabled ? Color.primary : Color.secondary)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .plainButton()
            Toggle("On", isOn: Binding(get: { alarm.isEnabled }, set: { model.setEnabled($0, for: alarm) }))
                .labelsHidden()
        }
        .contextMenu {
            Button("Delete", role: .destructive) { model.delete(alarm) }
        }
    }
}

/// What came of editing an alarm.
enum AlarmEdit {
    case save(Alarm)
    case delete
    case cancel
}

/// Sets an alarm's time, label and the days it repeats on.
struct AlarmEditor: View {

    let isNew: Bool

    let done: (AlarmEdit) -> Void

    @State private var alarm: Alarm

    init(alarm: Alarm, isNew: Bool, done: @escaping (AlarmEdit) -> Void) {
        self.isNew = isNew
        self.done = done
        _alarm = State(initialValue: alarm)
    }

    /// The alarm's time as a date today, for the picker.
    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                alarm.hour = parts.hour ?? alarm.hour
                alarm.minute = parts.minute ?? alarm.minute
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                    TextField("Label", text: $alarm.label)
                }
                Section("Repeat") {
                    ForEach(Weekdays.all, id: \.name) { day in
                        Toggle(day.name, isOn: Binding(
                            get: { alarm.days.contains(day.day) },
                            set: { isOn in
                                if isOn { alarm.days.insert(day.day) } else { alarm.days.remove(day.day) }
                            }
                        ))
                    }
                }
                if !isNew {
                    Section {
                        Button("Delete Alarm", role: .destructive) { done(.delete) }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Alarm" : "Edit Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { done(.cancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = alarm
                        saved.isEnabled = true
                        done(.save(saved))
                    }
                }
            }
        }
    }
}

#endif
