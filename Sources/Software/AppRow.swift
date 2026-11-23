//
//  AppRow.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import SoftwareCore

/// An app's icon from the catalog, or its initial on a tile.
struct AppIcon: View {

    let model: SoftwareModel

    let id: String

    let name: String

    var size: CGFloat = 48

    var body: some View {
        if let icon = model.icon(for: id) {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(String(name.first ?? "?").uppercased())
                .font(size > 60 ? .largeTitle : .title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
                .background(Color(red: 0.35, green: 0.45, blue: 0.6))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        }
    }
}

/// An app in a list: its icon, name and one line, and what's happening to
/// it.
struct AppRow: View {

    let model: SoftwareModel

    let id: String

    let name: String

    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(model: model, id: id, name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let operation = model.operations[id] {
                ProgressView()
                    .accessibilityLabel(operation.description)
            } else if !model.installs(of: id).isEmpty {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Color.secondary)
                    .accessibilityLabel("Installed")
            }
        }
        .padding(.vertical, 4)
        .frame(minHeight: Metrics.minimumTarget)
    }
}

extension AppRow {

    init(model: SoftwareModel, app: CatalogApp) {
        self.init(model: model, id: app.id, name: app.name, detail: app.summary)
    }
}

#endif
