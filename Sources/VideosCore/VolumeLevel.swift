//
//  VolumeLevel.swift
//  CoreApps
//

/// The player's volume, and the speaker that shows it.
public struct VolumeLevel: Equatable, Sendable {

    /// 0 to 1.
    public var volume: Float

    public var isMuted: Bool

    public init(volume: Float, isMuted: Bool = false) {
        self.volume = Self.clamp(volume)
        self.isMuted = isMuted
    }

    /// Whether any sound comes out.
    public var isSilent: Bool {
        isMuted || volume <= 0
    }

    /// The speaker's symbol: crossed out when silent, then with one to
    /// three waves.
    public var symbolName: String {
        if isSilent { return "speaker.slash.fill" }
        if volume < 1.0 / 3 { return "speaker.wave.1.fill" }
        if volume < 2.0 / 3 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    /// The speaker's button: mutes, or unmutes, and a volume dragged to
    /// nothing comes back at a quarter.
    public func toggled() -> VolumeLevel {
        if isMuted { return VolumeLevel(volume: volume > 0 ? volume : 0.25) }
        if volume <= 0 { return VolumeLevel(volume: 0.25) }
        return VolumeLevel(volume: volume, isMuted: true)
    }

    /// Up or down by `step`, unmuting.
    public func stepped(by step: Float) -> VolumeLevel {
        VolumeLevel(volume: volume + step)
    }

    public static func clamp(_ volume: Float) -> Float {
        guard volume.isFinite, volume > 0 else { return 0 }
        return volume < 1 ? volume : 1
    }
}
