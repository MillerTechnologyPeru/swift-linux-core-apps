//
//  ImageStore.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import FilesCore
import Foundation
import ImagesCore
#if Apple && canImport(UIKit)
import UIKit
#elseif Apple && canImport(AppKit)
import AppKit
#endif

/// An image read from a file, ready to draw.
struct LoadedImage {

    let image: Image

    let size: PixelSize

    let format: ImageFormat?
}

/// Why a file isn't shown.
enum ImageFailure: Error, Equatable {
    /// The file couldn't be read.
    case unreadable(String)
    /// The file isn't an image of a kind known.
    case notAnImage
    /// The file is an image of a kind that can't be drawn here yet.
    case unsupported(ImageFormat)

    var message: String {
        switch self {
        case let .unreadable(reason): reason
        case .notAnImage: "This file isn't an image."
        case let .unsupported(format): "\(format.name) images can't be shown yet."
        }
    }
}

/// Reads images from files, keeping the last few so that drawing one again
/// (every frame of a pinch, every pass over a grid) doesn't decode it again.
@MainActor
final class ImageStore: ObservableObject {

    private var cache: [URL: Result<LoadedImage, ImageFailure>] = [:]

    /// The files cached, oldest first.
    private var order: [URL] = []

    /// How many images are kept.
    private let limit = 80

    /// The largest file read.
    private let byteLimit = 200_000_000

    func image(at url: URL) -> Result<LoadedImage, ImageFailure> {
        if let cached = cache[url] { return cached }
        let result = load(url)
        cache[url] = result
        order.append(url)
        if order.count > limit {
            cache[order.removeFirst()] = nil
        }
        return result
    }

    /// Forgets a file that changed or went away.
    func forget(_ url: URL) {
        cache[url] = nil
        order.removeAll { $0 == url }
    }

    private func load(_ url: URL) -> Result<LoadedImage, ImageFailure> {
        let data: Data
        do {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= byteLimit else { return .failure(.unreadable("This file is too large to show.")) }
            data = try Data(contentsOf: url)
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
        let header = [UInt8](data.prefix(1 << 18))
        guard let format = ImageFormat(header: header) else { return .failure(.notAnImage) }
        let headerSize = PixelSize(header: header)

        #if Native
        // Cacao decodes PNG; the other formats wait for decoders.
        guard format == .png, let size = headerSize else { return .failure(.unsupported(format)) }
        return .success(LoadedImage(image: Image(pngData: data), size: size, format: format))
        #elseif canImport(UIKit)
        guard let decoded = UIImage(data: data) else { return .failure(.unsupported(format)) }
        let size = headerSize ?? PixelSize(
            width: Int(decoded.size.width * decoded.scale),
            height: Int(decoded.size.height * decoded.scale)
        )
        return .success(LoadedImage(image: Image(uiImage: decoded), size: size, format: format))
        #elseif canImport(AppKit)
        guard let decoded = NSImage(data: data) else { return .failure(.unsupported(format)) }
        let size = headerSize ?? PixelSize(width: Int(decoded.size.width), height: Int(decoded.size.height))
        return .success(LoadedImage(image: Image(nsImage: decoded), size: size, format: format))
        #else
        return .failure(.unsupported(format))
        #endif
    }

    /// The images directly in a folder, by name, and the folders in it.
    static func contents(of folder: URL) -> (folders: [FileItem], images: [FileItem]) {
        let items = (try? DirectoryListing.load(folder)) ?? []
        return (items.filter(\.isFolder), items.filter { $0.kind == .image })
    }
}

#endif
