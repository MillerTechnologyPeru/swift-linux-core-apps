//
//  SettingsModel.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import Foundation
import Observation
import SettingsCore

/// What Settings knows of the desktop: its appearance as the settings
/// portal serves it, kept in step as it changes, and whether the settings
/// service is there to take changes.
@Observable
final class SettingsModel {

    /// The appearance now.
    private(set) var appearance = DesktopAppearance()

    /// The icon and cursor themes installed.
    private(set) var themes = Themes()

    private(set) var connection: Connection = .connecting

    /// Whether the settings service is on the bus, so settings can be
    /// changed.
    private(set) var serviceIsRunning = false

    /// Why the last change didn't happen.
    var problem: String?

    enum Connection: Equatable {

        case connecting

        /// There's no session bus to ask.
        case noBus

        /// Connected; the settings came from this, or from nothing when
        /// neither the portal nor the service answered.
        case connected(DesktopSettingsClient.Source?)
    }

    /// Whether settings can be changed here.
    var canChange: Bool {
        if case .connected = connection {
            return serviceIsRunning
        }
        return false
    }

    /// What the pane says when settings can't be changed, or can't be
    /// read.
    var note: String? {
        switch connection {
        case .connecting:
            return nil
        case .noBus:
            return "There's no session bus, so the desktop's settings can't be read or changed here."
        case let .connected(source):
            if source == nil && !serviceIsRunning {
                return "Neither the settings portal nor the desktop's settings service answered, so these aren't the desktop's settings and can't be changed."
            }
            if !serviceIsRunning {
                return "The desktop's settings service isn't running, so these are shown as the portal has them and can't be changed."
            }
            return nil
        }
    }

    @ObservationIgnored private var client: DesktopSettingsClient?

    @ObservationIgnored private var hasStarted = false

    @ObservationIgnored private var following: [Task<Void, Never>] = []

    // MARK: Reading

    /// Connects to the session bus, reads the settings, and follows them
    /// and the service from then on. Once.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        async let themes = Task.detached(priority: .utility) { Themes.installed() }.value
        do {
            let client = try await DesktopSettingsClient.connect()
            self.client = client
            // Heard from before reading, so a change between the two
            // isn't missed.
            let changes = try? await client.changes()
            let services = try? await client.serviceChanges()
            let (appearance, source) = await client.read()
            self.appearance = appearance
            serviceIsRunning = await client.serviceIsRunning()
            connection = .connected(source)
            if let changes {
                following.append(Task { [weak self] in
                    for await change in changes {
                        self?.appearance.apply(namespace: change.namespace, key: change.key, value: change.value)
                    }
                })
            }
            if let services {
                following.append(Task { [weak self] in
                    for await isRunning in services {
                        await self?.serviceChanged(isRunning)
                    }
                })
            }
        } catch {
            connection = .noBus
        }
        self.themes = await themes
    }

    /// The service started or stopped. Once it's back, what it serves is
    /// read again, as it may have changed meanwhile.
    private func serviceChanged(_ isRunning: Bool) async {
        serviceIsRunning = isRunning
        guard isRunning, let client else { return }
        let (appearance, source) = await client.read()
        if source != nil {
            self.appearance = appearance
            connection = .connected(source)
        }
    }

    // MARK: Changing

    /// Changes a setting through the settings service. It's shown at once,
    /// and put back if the service refuses it.
    func set(_ key: SettingKey, to value: SettingValue) {
        guard let client, canChange, appearance.value(for: key) != value else { return }
        let old = appearance
        appearance.apply(value, for: key)
        Task {
            do {
                try await client.set(key, to: value)
            } catch {
                appearance = old
                problem = "The setting couldn't be changed: \(error)"
            }
        }
    }

    func setColorScheme(_ scheme: ColorSchemePreference) {
        set(.colorScheme, to: .uint32(scheme.rawValue))
    }

    func setAccentColor(_ color: AccentColor) {
        set(.accentColor, to: .color(red: color.red, green: color.green, blue: color.blue))
    }

    func setContrast(_ contrast: ContrastPreference) {
        set(.contrast, to: .uint32(contrast.rawValue))
    }

    func setButtonLayout(_ layout: ButtonLayout) {
        set(.buttonLayout, to: .string(layout.setting))
    }

    func setFont(_ key: SettingKey, to font: FontDescription) {
        set(key, to: .string(font.description))
    }

    func setIconTheme(_ name: String) {
        set(.iconTheme, to: .string(name))
    }

    func setCursorTheme(_ name: String) {
        set(.cursorTheme, to: .string(name))
    }

    func setCursorSize(_ size: Int) {
        set(.cursorSize, to: .int32(Int32(clamping: size)))
    }
}

#endif
