//
//  CapturesView.swift
//  CoreApps
//

import AppCamera
import AppUI
import CameraCore
import CoreAppsUI

/// The photos and videos taken, newest first: a grid to look through, one
/// at a time to look at, and deleting.
struct CapturesView: View {

    let store: CaptureStore

    let captures: [Capture]

    /// A capture was deleted: the list is to be read again.
    let deleted: () -> Void

    let done: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Photos and Videos")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if captures.isEmpty {
            EmptyState("No Photos or Videos", message: "What you take with the camera shows here.")
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                    ForEach(captures) { capture in
                        NavigationLink(destination: CaptureDetailView(store: store, capture: capture, deleted: deleted)) {
                            CaptureTile(store: store, capture: capture)
                        }
                        .plainButton()
                    }
                }
            }
        }
    }
}

/// A capture in the grid: the photo, or a film for a video.
struct CaptureTile: View {

    let store: CaptureStore

    let capture: Capture

    var body: some View {
        ZStack {
            CameraColors.button
            if let image = store.image(capture) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 4) {
                    Image(systemName: capture.mode == .video ? "video" : "photo")
                        .font(.title2)
                    Text(capture.name)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.secondary)
            }
        }
        .frame(height: 110)
        .clipped()
    }
}

/// One capture, as large as it fits, with its name and a way to delete it.
struct CaptureDetailView: View {

    let store: CaptureStore

    let capture: Capture

    let deleted: () -> Void

    @State private var isConfirming = false

    @State private var isDeleted = false

    var body: some View {
        VStack(spacing: 16) {
            if isDeleted {
                EmptyState("Deleted", message: "\(capture.name) is gone.")
            } else if let image = store.image(capture) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(capture.name, message: capture.mode == .video
                    ? "Videos are kept in the Captures folder of the app's documents, to play in the video player."
                    : "This photo can't be shown here.")
            }
            if !isDeleted {
                Button("Delete", role: .destructive) {
                    isConfirming = true
                }
                .accessibilityIdentifier("delete-capture")
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(capture.name)
        .confirmationDialog("Delete \(capture.name)?", isPresented: $isConfirming) {
            Button("Delete", role: .destructive) {
                store.delete(capture) {
                    isDeleted = true
                    deleted()
                }
            }
        }
    }
}
