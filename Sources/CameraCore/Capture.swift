//
//  Capture.swift
//  CoreApps
//

/// What the shutter takes.
public enum CaptureMode: String, CaseIterable, Identifiable, Sendable {

    case photo
    case video

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        }
    }
}

/// A photo or video the camera took, by its file's name: `IMG_0007.jpg`,
/// `VID_0003.mp4`. Captures are numbered as a camera numbers them, in one
/// sequence for photos and videos together.
public struct Capture: Equatable, Hashable, Identifiable, Sendable {

    public var name: String

    public var mode: CaptureMode

    /// Its place in the sequence.
    public var number: Int

    public var id: String { name }

    /// A capture's file name, or `nil` for a file that isn't one.
    public init?(name: String) {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let stem = parts[0], ext = String(parts[1]).lowercased()
        let mode: CaptureMode
        if stem.hasPrefix("IMG_"), ext == "jpg" {
            mode = .photo
        } else if stem.hasPrefix("VID_"), ext == "mp4" || ext == "mov" || ext == "webm" {
            mode = .video
        } else {
            return nil
        }
        let digits = stem.dropFirst(4)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(String(digits)) else {
            return nil
        }
        self.name = name
        self.mode = mode
        self.number = number
    }

    /// The name for the next capture after `existing`: one past the
    /// highest number, written with at least four digits.
    public static func nextName(for mode: CaptureMode, after existing: [String]) -> String {
        let highest = existing.compactMap { Capture(name: $0)?.number }.max() ?? 0
        var digits = String(highest + 1)
        while digits.count < 4 {
            digits = "0" + digits
        }
        switch mode {
        case .photo: return "IMG_" + digits + ".jpg"
        case .video: return "VID_" + digits + ".mp4"
        }
    }

    /// The captures among a folder's names, newest first.
    public static func list(_ names: [String]) -> [Capture] {
        names.compactMap(Capture.init(name:)).sorted { $0.number > $1.number }
    }
}
