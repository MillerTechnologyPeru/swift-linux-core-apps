//
//  LibraryView.swift
//  CoreApps
//

import AppMedia
import AppUI
import CoreAppsUI
import VideosCore

/// Where videos are opened from: a file, an address, or one played
/// before.
struct LibraryView: View {

    /// Played since the app opened, the latest first.
    let recent: [Video]

    let open: (Video) -> Void

    @State private var address = ""

    @State private var isImporting = false

    @State private var problem: String?

    var body: some View {
        List {
            Section {
                Button {
                    isImporting = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                        Text("Open a File")
                    }
                }
                .accessibilityIdentifier("open-file")
                TextField("Address of a video", text: $address)
                    .onSubmit(openAddress)
                    .accessibilityIdentifier("address")
                Button("Play Address", action: openAddress)
                    .disabled(address.isEmpty)
                    .accessibilityIdentifier("play-address")
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(recent) { video in
                        Button {
                            open(video)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "film")
                                Text(video.title)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Videos")
        .videoImporter(isPresented: $isImporting, open: open)
    }

    private func openAddress() {
        guard let location = VideoLocation(address) else {
            problem = "That isn't an address the player can open: it starts with http:// or https://."
            return
        }
        guard let video = Video(location) else {
            problem = "Files open with Open a File."
            return
        }
        problem = nil
        address = ""
        open(video)
    }
}
