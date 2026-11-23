//
//  Video.swift
//  CoreApps
//

import AppMedia
import AppUI
import VideosCore
#if Apple
import UniformTypeIdentifiers
#elseif !Native
import DynamicDocuments
#endif

/// A video to play: what it's called, and where it comes from.
struct Video: Identifiable, Equatable {

    let id: Int

    let title: String

    let source: MediaSource

    /// The next video's identifier.
    nonisolated(unsafe) private static var count = 0

    init(title: String, source: MediaSource) {
        Video.count += 1
        self.id = Video.count
        self.title = title
        self.source = source
    }

    /// A video at a path or an address someone typed or passed. A guest
    /// opens files only through the system's picker, so for it a path is
    /// `nil`.
    init?(_ location: VideoLocation) {
        switch location {
        case .web(let address):
            self.init(title: location.title, source: .url(address))
        case .file(let path):
            #if Native || Apple
            self.init(title: location.title, source: .file(path))
            #else
            _ = path
            return nil
            #endif
        }
    }
}

extension View {

    /// Shows the system's picker for a video file while `isPresented`, and
    /// calls `open` with the one picked.
    @ViewBuilder
    func videoImporter(isPresented: Binding<Bool>, open: @escaping (Video) -> Void) -> some View {
        #if Native
        // Cacao's dialog filters by extension; a movie has many, so every
        // file is offered and the player says if one doesn't play.
        fileImporter(isPresented: isPresented, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            open(Video(title: VideoLocation.file(url.path).title, source: .file(url.path)))
        }
        #elseif Apple
        fileImporter(isPresented: isPresented, allowedContentTypes: [.movie]) { result in
            guard case .success(let url) = result else { return }
            // A picked file outside the app's own is lent for as long as
            // the app runs.
            _ = url.startAccessingSecurityScopedResource()
            open(Video(title: VideoLocation.file(url.path).title, source: .file(url.path)))
        }
        #else
        fileImporter(isPresented: isPresented, allowedContentTypes: [.movie]) { result in
            guard case .success(let documents) = result, let document = documents.first else { return }
            open(Video(title: VideoLocation.file(document.name).title, source: .file(document.path)))
        }
        #endif
    }
}
