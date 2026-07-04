import SwiftUI
import HeadwindCore

/// Settings-style tinted icon square for list rows.
struct IconBadge: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint.gradient, in: .rect(cornerRadius: 7))
    }
}

/// Big-number stat for hero cards.
struct HeroStat: View {
    let value: String
    let unit: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Compass-style wind indicator: the arrow flies with the wind (from → to),
/// north-up.
struct WindArrow: View {
    /// Direction the wind blows from, degrees true.
    let directionFromDeg: Double
    var speedKts: Double? = nil
    var size: CGFloat = 34

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
                Image(systemName: "location.north.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(directionFromDeg + 180))
            }
            .frame(width: size, height: size)
            if let speedKts {
                Text("\(Int(speedKts.rounded()))kt")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Stylized north-up runway layout drawn from FAA true headings — the kind
/// of glanceable diagram that makes an airport page feel like an EFB.
struct RunwayDiagram: View {
    let runways: [Runway]
    var windFromDeg: Double? = nil
    var windSpeedKts: Double? = nil
    var diameter: CGFloat = 170

    private var drawable: [(ident: String, headingDeg: Double, relativeLength: Double)] {
        let usable = runways.compactMap { runway -> (String, Double, Int)? in
            guard let heading = runway.leHeadingDegT else { return nil }
            return (runway.leIdent ?? runway.ident, heading, runway.lengthFt)
        }
        guard let maxLen = usable.map(\.2).max(), maxLen > 0 else { return [] }
        return usable.map { ($0.0, $0.1, max(0.45, Double($0.2) / Double(maxLen))) }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.secondary.opacity(0.08))
            Circle()
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)

            Text("N")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .offset(y: -diameter / 2 + 11)

            ForEach(Array(drawable.enumerated()), id: \.offset) { _, runway in
                Capsule()
                    .fill(.primary.opacity(0.75))
                    .frame(width: 9, height: diameter * 0.72 * runway.relativeLength)
                    .rotationEffect(.degrees(runway.headingDeg))
            }

            // Ident labels sit outside the pavement at each runway's
            // approach-end azimuth (the "10" end lies on the reciprocal
            // side), unrotated so they stay legible at any orientation.
            ForEach(Array(drawable.enumerated()), id: \.offset) { _, runway in
                let azimuth = (runway.headingDeg + 180) * .pi / 180
                let radius = diameter * 0.36 * runway.relativeLength + 11
                Text(runway.ident)
                    .font(.system(size: 9, weight: .bold))
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .offset(
                        x: sin(azimuth) * radius,
                        y: -cos(azimuth) * radius
                    )
            }

            if let windFromDeg {
                WindArrow(directionFromDeg: windFromDeg, speedKts: windSpeedKts, size: 30)
                    .offset(x: diameter / 2 - 24, y: -diameter / 2 + 28)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Small labeled value chip used inside rich rows.
struct MetricChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 7))
    }
}
