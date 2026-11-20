//
//  ViewerView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import CoreAppsUI
import FilesCore
import Foundation
import ImagesCore

/// One image, and its folder's other images either side of it. It's
/// pinched or double-tapped to zoom, dragged to pan when zoomed, and
/// swiped to the next when it isn't.
struct ViewerView: View {

    @EnvironmentObject private var store: ImageStore

    @State private var sequence: ImageSequence<URL>

    /// The zoom, offset and turn of the image showing.
    @State private var viewport = Viewport(imageWidth: 1, imageHeight: 1)

    /// The zoom when a pinch began.
    @State private var pinchStart: Double?

    /// How far a drag had gone when last heard from.
    @State private var dragged = CGSize.zero

    /// The size the image has to show in, known once it's laid out: what
    /// the bar's percentage and the menu's zooming go by.
    @State private var viewSize = CGSize.zero

    @State private var showsInfo = false

    @State private var failure: String?

    /// - Parameter image: The image to show, among the images of its folder.
    init(opening image: URL) {
        let images = ImageStore.contents(of: image.deletingLastPathComponent()).images.map(\.url)
        // An image the listing doesn't count as one (by its name) still shows.
        let all = images.contains(image) ? images : [image] + images
        _sequence = State(initialValue: ImageSequence(all, current: image))
    }

    var body: some View {
        Group {
            if let url = sequence.current {
                content(url)
            } else {
                EmptyState("No Images", message: "There is nothing left to show here.")
            }
        }
        .navigationTitle(sequence.current?.lastPathComponent ?? "Images")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    menu
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(sequence.isEmpty)
            }
        }
        .sheet(isPresented: $showsInfo) {
            if let url = sequence.current {
                ImageInfoView(url: url, loaded: try? store.image(at: url).get()) { showsInfo = false }
            }
        }
        .alert("Couldn't Do That", isPresented: failureIsShown) {
            Button("OK") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var failureIsShown: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    // MARK: The image

    @ViewBuilder
    private func content(_ url: URL) -> some View {
        switch store.image(at: url) {
        case let .success(loaded):
            GeometryReader { proxy in
                canvas(loaded, in: proxy.size)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bar(percentage: resolved(loaded, in: nil).percentage)
            }
        case let .failure(reason):
            EmptyState("Can't Show Image", message: reason.message)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bar(percentage: nil)
                }
        }
    }

    /// The viewport for an image and a view: the state's zoom and offset,
    /// with the sizes they apply to.
    private func resolved(_ loaded: LoadedImage, in size: CGSize?) -> Viewport {
        var current = viewport
        current.imageWidth = Double(loaded.size.width)
        current.imageHeight = Double(loaded.size.height)
        let size = size ?? viewSize
        current.resize(viewWidth: Double(size.width), viewHeight: Double(size.height))
        return current
    }

    private func canvas(_ loaded: LoadedImage, in size: CGSize) -> some View {
        let current = resolved(loaded, in: size)
        // The image's frame before it's turned.
        let scale = current.fitScale * current.zoom
        return ZStack {
            Color.black
            loaded.image
                .resizable()
                .frame(width: CGFloat(current.imageWidth * scale), height: CGFloat(current.imageHeight * scale))
                .rotationEffect(.degrees(Double(current.quarterTurns) * 90))
                .offset(x: CGFloat(current.offsetX), y: CGFloat(current.offsetY))
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onAppear { viewSize = size }
        .onChange(of: size) { _, new in viewSize = new }
        .onTapGesture(count: 2) {
            var next = current
            next.toggleZoom()
            viewport = next
        }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard !current.isFitted else { return }
                    var next = current
                    next.pan(
                        byX: Double(value.translation.width - dragged.width),
                        y: Double(value.translation.height - dragged.height)
                    )
                    dragged = value.translation
                    viewport = next
                }
                .onEnded { value in
                    dragged = .zero
                    // A fitted image is swiped to the next or the one before.
                    guard current.isFitted, abs(value.translation.width) > 60,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 { show(next: true) } else { show(next: false) }
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let start = pinchStart ?? current.zoom
                    pinchStart = start
                    var next = current
                    next.setZoom(
                        start * Double(value.magnification),
                        aroundX: Double(value.startLocation.x - size.width / 2),
                        y: Double(value.startLocation.y - size.height / 2)
                    )
                    viewport = next
                }
                .onEnded { _ in pinchStart = nil }
        )
    }

    /// Where the image is among its folder's, and the ways to the others.
    private func bar(percentage: Int?) -> some View {
        HStack {
            Button {
                show(next: false)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            }
            .disabled(!sequence.hasPrevious)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(sequence.position)
                    .font(.footnote)
                if let percentage {
                    Text("\(percentage)%")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                show(next: true)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: Metrics.minimumTarget, height: Metrics.minimumTarget)
            }
            .disabled(!sequence.hasNext)
        }
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.12))
    }

    // MARK: Actions

    /// Goes to the next image or the one before, showing it whole.
    private func show(next: Bool) {
        var moved = sequence
        if next { moved.next() } else { moved.previous() }
        guard moved != sequence else { return }
        sequence = moved
        viewport = Viewport(imageWidth: 1, imageHeight: 1)
    }

    private func change(_ body: (inout Viewport) -> Void) {
        guard let url = sequence.current, let loaded = try? store.image(at: url).get() else { return }
        var next = resolved(loaded, in: nil)
        body(&next)
        viewport = next
    }

    @ViewBuilder
    private var menu: some View {
        Button("Zoom In") { change { $0.zoom(by: 1.5) } }
        Button("Zoom Out") { change { $0.zoom(by: 1 / 1.5) } }
        Button("Fit") { change { $0.fit() } }
        Button("Actual Size") { change { $0.setZoom($0.actualSizeZoom) } }
        Divider()
        Button("Rotate Left") { change { $0.rotate(clockwise: false) } }
        Button("Rotate Right") { change { $0.rotate() } }
        Divider()
        Button("Properties") { showsInfo = true }
        Button("Move to Trash", role: .destructive) { trash() }
    }

    private func trash() {
        guard let url = sequence.current else { return }
        do {
            try FileOperations.moveToTrash(url)
            store.forget(url)
            sequence.removeCurrent()
            viewport = Viewport(imageWidth: 1, imageHeight: 1)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// What's known of an image.
struct ImageInfoView: View {

    let url: URL

    let loaded: LoadedImage?

    let done: () -> Void

    var body: some View {
        let properties = try? FileProperties.load(url)
        return NavigationStack {
            Form {
                Section {
                    row("Name", url.lastPathComponent)
                    if let format = loaded?.format {
                        row("Format", format.name)
                    }
                    if let size = loaded?.size {
                        row("Dimensions", "\(size.width) × \(size.height)")
                        row("Megapixels", megapixels(size))
                    }
                    if let bytes = properties?.size {
                        row("File Size", ByteCount.format(bytes))
                    }
                }
                Section {
                    if let date = properties?.modified {
                        row("Modified", date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let date = properties?.created {
                        row("Created", date.formatted(date: .abbreviated, time: .shortened))
                    }
                    row("Folder", url.deletingLastPathComponent().path)
                }
            }
            .navigationTitle("Properties")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }

    /// A size in millions of pixels, to one decimal place.
    private func megapixels(_ size: PixelSize) -> String {
        let tenths = (size.width * size.height + 50_000) / 100_000
        return "\(tenths / 10).\(tenths % 10)"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
    }
}

#endif
