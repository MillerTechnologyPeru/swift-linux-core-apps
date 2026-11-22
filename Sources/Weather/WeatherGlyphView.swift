//
//  WeatherGlyphView.swift
//  CoreApps
//

#if Native || Apple

import AppUI
import WeatherCore

/// A picture of the weather: the system's symbol on Apple's SwiftUI, and
/// drawn from shapes on Cacao, whose symbols have no clouds.
struct WeatherGlyphView: View {

    let glyph: Glyph

    var size: CGFloat = 28

    var body: some View {
        #if Apple
        Image(systemName: glyph.symbolName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size * 0.8))
            .frame(width: size, height: size)
        #else
        DrawnGlyph(glyph: glyph, size: size)
            .frame(width: size, height: size)
        #endif
    }
}

extension Glyph {

    /// The SF Symbol for the glyph.
    var symbolName: String {
        switch self {
        case .sun: "sun.max.fill"
        case .moon: "moon.stars.fill"
        case .partlySun: "cloud.sun.fill"
        case .partlyMoon: "cloud.moon.fill"
        case .cloud: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .drizzle: "cloud.drizzle.fill"
        case .rain: "cloud.rain.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .sleet: "cloud.sleet.fill"
        case .snow: "cloud.snow.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        }
    }
}

/// The glyph in circles and capsules.
private struct DrawnGlyph: View {

    let glyph: Glyph

    let size: CGFloat

    static let sunColor = Color(red: 1.0, green: 0.78, blue: 0.16)
    static let cloudColor = Color(red: 0.78, green: 0.81, blue: 0.86)
    static let rainColor = Color(red: 0.25, green: 0.6, blue: 1.0)
    static let snowColor = Color(red: 0.72, green: 0.86, blue: 1.0)

    var body: some View {
        switch glyph {
        case .sun:
            sun(size)
        case .moon:
            moon(size * 0.9)
        case .partlySun:
            ZStack {
                sun(size * 0.7).offset(x: -size * 0.16, y: -size * 0.16)
                cloud(size * 0.78).offset(x: size * 0.1, y: size * 0.12)
            }
        case .partlyMoon:
            ZStack {
                moon(size * 0.6).offset(x: -size * 0.18, y: -size * 0.18)
                cloud(size * 0.78).offset(x: size * 0.1, y: size * 0.12)
            }
        case .cloud:
            cloud(size)
        case .fog:
            ZStack {
                cloud(size * 0.8).offset(y: -size * 0.14)
                VStack(spacing: size * 0.06) {
                    bar(width: size * 0.7)
                    bar(width: size * 0.55)
                }
                .offset(y: size * 0.3)
            }
        case .drizzle:
            overCloud { drops(2, length: 0.12) }
        case .rain:
            overCloud { drops(3, length: 0.18) }
        case .heavyRain:
            overCloud { drops(4, length: 0.24) }
        case .sleet:
            overCloud {
                HStack(spacing: size * 0.1) {
                    drop(length: 0.16)
                    flake()
                    drop(length: 0.16)
                }
            }
        case .snow:
            overCloud {
                HStack(spacing: size * 0.1) {
                    flake()
                    flake().offset(y: size * 0.08)
                    flake()
                }
            }
        case .thunderstorm:
            overCloud {
                Image(systemName: "bolt")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Self.sunColor)
            }
        }
    }

    private func sun(_ side: CGFloat) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Self.sunColor)
                    .frame(width: side * 0.08, height: side * 0.16)
                    .offset(y: -side * 0.4)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            Circle()
                .fill(Self.sunColor)
                .frame(width: side * 0.48, height: side * 0.48)
        }
        .frame(width: side, height: side)
    }

    private func moon(_ side: CGFloat) -> some View {
        Image(systemName: "moon")
            .font(.system(size: side * 0.75, weight: .semibold))
            .foregroundStyle(Color(red: 0.95, green: 0.9, blue: 0.6))
            .frame(width: side, height: side)
    }

    private func cloud(_ side: CGFloat) -> some View {
        ZStack {
            Circle()
                .frame(width: side * 0.4, height: side * 0.4)
                .offset(x: -side * 0.16, y: side * 0.02)
            Circle()
                .frame(width: side * 0.52, height: side * 0.52)
                .offset(x: side * 0.08, y: -side * 0.06)
            Capsule()
                .frame(width: side * 0.84, height: side * 0.3)
                .offset(y: side * 0.14)
        }
        .foregroundStyle(Self.cloudColor)
        .frame(width: side, height: side)
    }

    /// A cloud above, and rain, snow or lightning under it.
    private func overCloud<Below: View>(@ViewBuilder _ below: () -> Below) -> some View {
        ZStack {
            cloud(size * 0.82).offset(y: -size * 0.14)
            below().offset(y: size * 0.3)
        }
    }

    private func drops(_ count: Int, length: CGFloat) -> some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<count, id: \.self) { _ in
                drop(length: length)
            }
        }
    }

    private func drop(length: CGFloat) -> some View {
        Capsule()
            .fill(Self.rainColor)
            .frame(width: size * 0.07, height: size * length)
            .rotationEffect(.degrees(15))
    }

    private func flake() -> some View {
        Circle()
            .fill(Self.snowColor)
            .frame(width: size * 0.11, height: size * 0.11)
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(Self.cloudColor)
            .frame(width: width, height: size * 0.07)
    }
}

#endif
