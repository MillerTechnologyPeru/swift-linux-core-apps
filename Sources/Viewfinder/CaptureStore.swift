//
//  CaptureStore.swift
//  CoreApps
//

import AppCamera
import AppUI
import CameraCore
#if Native || Apple
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

/// The photos and videos taken, in a `Captures` folder of the app's
/// documents: AppRuntime's files for a guest, and for a program its
/// documents (`~/Pictures/Camera` on Cacao).
///
/// Every call answers through a closure, as a guest's files do.
final class CaptureStore {

    /// The captures, newest first, as last listed.
    private(set) var captures: [Capture] = []

    #if Native || Apple

    private let folder: URL = {
        #if Native
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures/Camera", isDirectory: true)
        #else
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Captures", isDirectory: true)
        #endif
    }()

    /// Where a capture's file is.
    func file(_ name: String) -> CaptureFile {
        folder.appendingPathComponent(name).path
    }

    /// Lists the captures, and makes the folder for the next.
    func reload(_ done: @escaping ([Capture]) -> Void) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        captures = Capture.list(names)
        done(captures)
    }

    func delete(_ capture: Capture, _ done: @escaping () -> Void) {
        try? FileManager.default.removeItem(atPath: file(capture.name))
        reload { _ in done() }
    }

    /// A photo, small enough for a thumbnail or the screen; `nil` for a
    /// video, or a picture this flavor can't decode.
    func image(_ capture: Capture) -> Image? {
        guard capture.mode == .photo else { return nil }
        #if canImport(UIKit)
        return UIImage(contentsOfFile: file(capture.name)).map { Image(uiImage: $0) }
        #elseif canImport(AppKit) && Apple
        return NSImage(contentsOfFile: file(capture.name)).map { Image(nsImage: $0) }
        #else
        // Cacao decodes PNG only, and takes no photos itself.
        return nil
        #endif
    }

    #else

    private let folder = FilePath(.documents, "Captures")

    /// Where a capture's file is.
    func file(_ name: String) -> CaptureFile {
        folder / name
    }

    /// Lists the captures, and makes the folder for the next.
    func reload(_ done: @escaping ([Capture]) -> Void) {
        FileManager.default.createDirectory(at: folder) { _ in
            FileManager.default.contentsOfDirectory(at: self.folder) { result in
                switch result {
                case .success(let names):
                    self.captures = Capture.list(names)
                case .failure:
                    self.captures = []
                }
                done(self.captures)
            }
        }
    }

    func delete(_ capture: Capture, _ done: @escaping () -> Void) {
        FileManager.default.removeItem(at: file(capture.name)) { _ in
            self.reload { _ in done() }
        }
    }

    /// A photo, decoded by the host for the space it's shown in; `nil` for
    /// a video.
    func image(_ capture: Capture) -> Image? {
        guard capture.mode == .photo else { return nil }
        return Image(contentsOf: file(capture.name), maximumPixelSize: 1600)
    }

    #endif

    /// The name for the next capture.
    func nextName(for mode: CaptureMode) -> String {
        Capture.nextName(for: mode, after: captures.map { $0.name })
    }
}
