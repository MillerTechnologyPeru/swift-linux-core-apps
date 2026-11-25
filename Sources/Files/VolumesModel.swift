//
//  VolumesModel.swift
//  CoreApps
//

// UDisks is Linux's, reached over D-Bus: only on Cacao.
#if Native

import AppUI
import CoreAppsUI
import FilesCore
import FilesVolumes
import Foundation

/// The disks UDisks knows of, kept up to date as they come, go, mount and
/// unmount. Without UDisks the sidebar lists the mounted volumes from
/// `/proc/self/mounts`, as before.
@MainActor
final class VolumesModel: ObservableObject {

    /// The volumes to list, mounted or not.
    @Published private(set) var volumes: [DiskVolume] = []

    /// Whether UDisks answered: the volumes come from it, and can be
    /// mounted and ejected.
    @Published private(set) var usesUDisks = false

    /// The volumes being mounted, unmounted or ejected.
    @Published private(set) var working: Set<String> = []

    private var client: UDisksClient?

    /// Reads the volumes, then again whenever UDisks' objects change,
    /// until cancelled.
    func follow() async {
        do {
            let client = try await UDisksClient.system()
            self.client = client
            try await reload()
            usesUDisks = true
            for await _ in try await client.changes() {
                try? await reload()
            }
        } catch {
            usesUDisks = false
        }
    }

    private func reload() async throws {
        guard let client else { return }
        volumes = DiskVolume.shown(try await client.volumes())
    }

    /// Mounts a volume. Returns where, or throws why not, said for a
    /// person.
    func mount(_ volume: DiskVolume) async throws -> URL {
        try await run(volume) { client in try await client.mount(volume) }
    }

    func unmount(_ volume: DiskVolume) async throws {
        try await run(volume) { client in try await client.unmount(volume) }
    }

    func eject(_ volume: DiskVolume) async throws {
        try await run(volume) { client in try await client.eject(volume) }
    }

    private func run<T>(_ volume: DiskVolume, _ body: (UDisksClient) async throws -> T) async throws -> T {
        guard let client else { throw DiskVolumeError.unavailable }
        working.insert(volume.id)
        defer { working.remove(volume.id) }
        let result = try await body(client)
        try? await reload()
        return result
    }
}

/// A volume in the sidebar: mounted, it opens, with a button to eject it;
/// not mounted, a tap mounts it first.
struct VolumeRow: View {

    let volume: DiskVolume

    @ObservedObject var model: VolumesModel

    /// Opens a folder in the browser.
    let open: (URL) -> Void

    /// Shows why something couldn't be done.
    let fail: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let url = volume.mountURL {
                PlaceRow(name: volume.name, symbolName: symbolName, detail: detail, place: .folder(url))
            } else {
                Button {
                    act { open(try await model.mount(volume)) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: symbolName)
                            .foregroundStyle(Color.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(volume.name)
                                .lineLimit(1)
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Metrics.minimumTarget - 16)
                    .contentShape(Rectangle())
                }
                .plainButton()
            }
            if model.working.contains(volume.id) {
                ProgressView()
            } else if volume.isMounted, volume.isRemovable {
                Button {
                    act { try await model.eject(volume) }
                } label: {
                    Image(systemName: "eject")
                }
                .plainButton()
            }
        }
        .contextMenu {
            if volume.isMounted {
                Button("Unmount") { act { try await model.unmount(volume) } }
            } else {
                Button("Mount") { act { _ = try await model.mount(volume) } }
            }
            if volume.isRemovable {
                Button("Eject") { act { try await model.eject(volume) } }
            }
        }
    }

    private var symbolName: String {
        volume.isLoop ? "opticaldisc" : "externaldrive"
    }

    /// Free space while mounted; size, file system and “Not mounted”
    /// otherwise.
    private var detail: String {
        if let url = volume.mountURL, let space = Volume.space(at: url) {
            return "\(ByteCount.format(space.free)) free of \(ByteCount.format(space.total))"
        }
        var parts: [String] = []
        if volume.size > 0 { parts.append(ByteCount.format(Int64(clamping: volume.size))) }
        if !volume.fileSystem.isEmpty { parts.append(volume.fileSystem) }
        parts.append(volume.isMounted ? "Mounted" : "Not mounted")
        return parts.joined(separator: " · ")
    }

    private func act(_ body: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do {
                try await body()
            } catch {
                fail(error.localizedDescription)
            }
        }
    }
}

#endif
