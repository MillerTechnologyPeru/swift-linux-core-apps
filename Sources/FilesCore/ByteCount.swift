//
//  ByteCount.swift
//  CoreApps
//

/// A size in bytes, as people read it: in decimal units, as storage is
/// sold and as file managers show it.
public enum ByteCount {

    public static func format(_ bytes: Int64) -> String {
        guard bytes >= 1000 else {
            return bytes == 1 ? "1 byte" : "\(max(bytes, 0)) bytes"
        }
        let units = ["kB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes) / 1000
        var unit = 0
        while value >= 999.95, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        // One decimal place below ten, none above: 1.5 kB, 15 kB.
        if value < 9.95 {
            let tenths = Int((value * 10).rounded())
            return tenths % 10 == 0 ? "\(tenths / 10) \(units[unit])" : "\(tenths / 10).\(tenths % 10) \(units[unit])"
        }
        return "\(Int(value.rounded())) \(units[unit])"
    }
}
