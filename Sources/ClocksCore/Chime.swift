//
//  Chime.swift
//  CoreApps
//

/// The sound an alarm or a finished timer makes: four short beeps and a
/// pause, made rather than read from a file, and played over and over.
public enum Chime {

    /// Samples a second.
    public static let sampleRate = 44_100

    /// The beeps' pitch, in hertz.
    static let frequency = 880.0

    /// One round of the chime, as signed 16-bit samples of one channel.
    public static func samples(sampleRate: Int = sampleRate) -> [Int16] {
        let beep = Int(Double(sampleRate) * 0.1)
        let gap = Int(Double(sampleRate) * 0.08)
        let pause = Int(Double(sampleRate) * 0.6)
        var samples: [Int16] = []
        samples.reserveCapacity(4 * (beep + gap) + pause)
        for _ in 0..<4 {
            for index in 0..<beep {
                // A square-ish wave from the sign of a triangle, eased in
                // and out over a few milliseconds so it doesn't click.
                let phase = Double(index) * frequency / Double(sampleRate)
                let triangle = 4 * abs(phase - (phase + 0.5).rounded(.down)) - 1
                let edge = Double(sampleRate) * 0.005
                let envelope = min(1, Double(index) / edge, Double(beep - index) / edge)
                samples.append(Int16(triangle * envelope * 9000))
            }
            samples.append(contentsOf: repeatElement(0, count: gap))
        }
        samples.append(contentsOf: repeatElement(0, count: pause))
        return samples
    }

    /// How long one round lasts, in seconds.
    public static var duration: Double {
        Double(samples().count) / Double(sampleRate)
    }

    /// One round of the chime as a WAV file: for players that take files.
    public static func wav(sampleRate: Int = sampleRate) -> [UInt8] {
        let samples = samples(sampleRate: sampleRate)
        func little(_ value: Int, _ count: Int) -> [UInt8] {
            (0..<count).map { UInt8(value >> ($0 * 8) & 0xFF) }
        }
        let dataSize = samples.count * 2
        var bytes = Array("RIFF".utf8) + little(36 + dataSize, 4) + Array("WAVE".utf8)
        // PCM, one channel, the rate, bytes a second, bytes a sample, bits.
        bytes += Array("fmt ".utf8) + little(16, 4) + little(1, 2) + little(1, 2)
        bytes += little(sampleRate, 4) + little(sampleRate * 2, 4) + little(2, 2) + little(16, 2)
        bytes += Array("data".utf8) + little(dataSize, 4)
        bytes.reserveCapacity(bytes.count + dataSize)
        for sample in samples {
            let value = UInt16(bitPattern: sample)
            bytes.append(UInt8(value & 0xFF))
            bytes.append(UInt8(value >> 8))
        }
        return bytes
    }
}
