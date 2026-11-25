//
//  AppearanceView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import SettingsCore

/// Light or dark, the accent, contrast, window buttons, fonts, icons and
/// the cursor: the desktop's appearance, which every app follows.
struct AppearanceView: View {

    let model: SettingsModel

    var body: some View {
        let appearance = model.appearance
        Form {
            if let note = model.note {
                Section {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .accessibilityIdentifier("appearance-note")
                }
            }
            Section("Style") {
                HStack(spacing: 12) {
                    ForEach(ColorSchemePreference.shown, id: \.self) { scheme in
                        SchemeTile(scheme: scheme, isSelected: appearance.colorScheme == scheme, accent: accent) {
                            model.setColorScheme(scheme)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                    ForEach(AccentColor.palette) { named in
                        Swatch(color: named.color, isSelected: appearance.accentColor.map(named.color.matches) ?? false) {
                            model.setAccentColor(named.color)
                        }
                        .accessibilityIdentifier("accent-\(named.name.lowercased())")
                    }
                    if let current = appearance.accentColor, current.name == nil {
                        Swatch(color: current, isSelected: true) { }
                    }
                }
                .padding(.vertical, 4)
                Toggle("Increase Contrast", isOn: highContrast)
                    .accessibilityIdentifier("contrast")
            } header: {
                Text("Accent Color")
            } footer: {
                Text(accentDescription(appearance.accentColor))
            }
            Section("Window Buttons") {
                ForEach(ButtonLayout.Preset.allCases) { preset in
                    CheckRow(title: preset.title, detail: preset.detail, isChecked: appearance.buttonLayout?.preset == preset) {
                        model.setButtonLayout(preset.layout)
                    }
                    .accessibilityIdentifier("buttons-\(preset.rawValue)")
                }
                if let layout = appearance.buttonLayout, layout.preset == nil {
                    CheckRow(title: "Custom", detail: layout.setting, isChecked: true) { }
                }
            }
            Section("Fonts") {
                FontRow(title: "Interface", font: appearance.fontName) { font in
                    model.setFont(.fontName, to: font)
                }
                FontRow(title: "Monospace", font: appearance.monospaceFontName) { font in
                    model.setFont(.monospaceFontName, to: font)
                }
            }
            Section("Icons and Cursor") {
                Picker("Icons", selection: themeBinding(appearance.iconTheme, model.setIconTheme)) {
                    ForEach(Themes.choices(model.themes.iconThemes, current: appearance.iconTheme), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Picker("Cursor", selection: themeBinding(appearance.cursorTheme, model.setCursorTheme)) {
                    ForEach(Themes.choices(model.themes.cursorThemes, current: appearance.cursorTheme), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Picker("Cursor Size", selection: cursorSize) {
                    ForEach(CursorSize.choices(current: appearance.cursorSize), id: \.self) { size in
                        Text("\(size) pixels").tag(size)
                    }
                }
            }
        }
        .disabled(!model.canChange)
        .navigationTitle("Appearance")
    }

    // MARK: Values

    private var accent: Color {
        model.appearance.accentColor.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? Color.accentColor
    }

    private func accentDescription(_ accent: AccentColor?) -> String {
        guard let accent else {
            return "No accent is set: apps use their own."
        }
        return accent.name ?? "A color of the desktop's own."
    }

    private var highContrast: Binding<Bool> {
        Binding(
            get: { model.appearance.contrast == .high },
            set: { model.setContrast($0 ? .high : .normal) }
        )
    }

    private var cursorSize: Binding<Int> {
        Binding(
            get: { model.appearance.cursorSize ?? 0 },
            set: { model.setCursorSize($0) }
        )
    }

    private func themeBinding(_ current: String?, _ set: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: { current ?? "" }, set: { if !$0.isEmpty { set($0) } })
    }
}

// MARK: - Rows

/// A choice of color scheme: a small window drawn light, dark, or half
/// of each, over its name.
private struct SchemeTile: View {

    let scheme: ColorSchemePreference

    let isSelected: Bool

    let accent: Color

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? accent : Color.secondary.opacity(0.35), lineWidth: isSelected ? 3 : 1)
                    )
                Text(scheme.title)
                    .font(.footnote)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .plainButton()
        .accessibilityIdentifier("scheme-\(scheme.title.lowercased())")
    }

    @ViewBuilder
    private var preview: some View {
        switch scheme {
        case .light:
            WindowSketch(dark: false, accent: accent)
        case .dark:
            WindowSketch(dark: true, accent: accent)
        case .automatic:
            HStack(spacing: 0) {
                WindowSketch(dark: false, accent: accent)
                WindowSketch(dark: true, accent: accent)
            }
        }
    }
}

/// A window in miniature: a title bar, two lines of text and a button.
private struct WindowSketch: View {

    let dark: Bool

    let accent: Color

    var body: some View {
        let background = dark ? Color(white: 0.16) : Color(white: 0.96)
        let bar = dark ? Color(white: 0.24) : Color(white: 0.86)
        let text = dark ? Color(white: 0.7) : Color(white: 0.45)
        VStack(alignment: .leading, spacing: 6) {
            bar.frame(height: 12)
            VStack(alignment: .leading, spacing: 5) {
                text.frame(width: 34, height: 4).cornerRadius(2)
                text.opacity(0.6).frame(width: 24, height: 4).cornerRadius(2)
                accent.frame(width: 22, height: 9).cornerRadius(3)
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(background)
    }
}

/// An accent to choose: a circle of it, ringed when it's the one set.
private struct Swatch: View {

    let color: AccentColor

    let isSelected: Bool

    let action: () -> Void

    var body: some View {
        let fill = Color(red: color.red, green: color.green, blue: color.blue)
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 28, height: 28)
                if isSelected {
                    Circle()
                        .stroke(fill, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }
            .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            .contentShape(Rectangle())
        }
        .plainButton()
    }
}

/// A choice in a list: its title and a line under it, checked when it's
/// the one chosen.
private struct CheckRow: View {

    let title: String

    let detail: String

    let isChecked: Bool

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                if isChecked {
                    Image(systemName: "checkmark")
                }
            }
            .frame(minHeight: Metrics.minimumTarget)
            .contentShape(Rectangle())
        }
        .plainButton()
    }
}

/// A font setting: its family, typed in, and its size, picked.
private struct FontRow: View {

    let title: String

    let font: FontDescription?

    let change: (FontDescription) -> Void

    @State private var family = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            HStack {
                TextField("Family", text: $family)
                    .onSubmit(submit)
                    .accessibilityIdentifier("font-\(title.lowercased())")
                Picker("Size", selection: size) {
                    ForEach(sizes, id: \.self) { size in
                        Text(FontDescription.format(size)).tag(size)
                    }
                }
                .labelsHidden()
                .frame(width: 80)
            }
        }
        .padding(.vertical, 4)
        .onAppear { family = font?.family ?? "" }
        .onChange(of: font?.family) { _, new in family = new ?? "" }
    }

    private var sizes: [Double] {
        var sizes = FontDescription.sizes
        if let size = font?.size, !sizes.contains(size) {
            sizes.append(size)
            sizes.sort()
        }
        return sizes
    }

    private var size: Binding<Double> {
        Binding(
            get: { font?.size ?? 0 },
            set: { change(FontDescription(family: font?.family ?? family, size: $0)) }
        )
    }

    private func submit() {
        let trimmed = family.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != font?.family else { return }
        change(FontDescription(family: trimmed, size: font?.size))
    }
}

#endif
