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

    private struct DrawableRunway {
        let ident: String
        let headingDeg: Double
        let relativeLength: Double
        /// Perpendicular offset in points so parallels sit side by side
        /// like the real layout (and their labels never collide).
        let lateral: CGFloat
    }

    private var drawable: [DrawableRunway] {
        let usable = runways.compactMap { runway -> (ident: String, heading: Double, length: Int)? in
            guard let heading = runway.leHeadingDegT else { return nil }
            return (runway.leIdent ?? runway.ident, heading, runway.lengthFt)
        }
        guard let maxLen = usable.map(\.length).max(), maxLen > 0 else { return [] }

        // Group parallels (headings within ~8°) and spread each group
        // laterally, ordered L → C → R like the pavement.
        func suffixRank(_ ident: String) -> Int {
            switch ident.last {
            case "L": 0
            case "C": 1
            case "R": 2
            default: 1
            }
        }
        var groups: [Int: [Int]] = [:]
        for (index, runway) in usable.enumerated() {
            let bucket = Int((runway.heading / 8.0).rounded())
            groups[bucket, default: []].append(index)
        }

        var lateral = [CGFloat](repeating: 0, count: usable.count)
        for members in groups.values {
            let ordered = members.sorted {
                suffixRank(usable[$0].ident) < suffixRank(usable[$1].ident)
            }
            for (position, index) in ordered.enumerated() {
                lateral[index] = (CGFloat(position) - CGFloat(ordered.count - 1) / 2) * 14
            }
        }

        return usable.enumerated().map { index, runway in
            DrawableRunway(
                ident: runway.ident,
                headingDeg: runway.heading,
                relativeLength: max(0.45, Double(runway.length) / Double(maxLen)),
                lateral: lateral[index]
            )
        }
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
                let headingRad = runway.headingDeg * .pi / 180
                Capsule()
                    .fill(.primary.opacity(0.75))
                    .frame(width: 8, height: diameter * 0.68 * runway.relativeLength)
                    .rotationEffect(.degrees(runway.headingDeg))
                    .offset(
                        x: cos(headingRad) * runway.lateral,
                        y: sin(headingRad) * runway.lateral
                    )
            }

            // Ident labels sit outside the pavement at each runway's
            // approach-end azimuth (the "10" end lies on the reciprocal
            // side), unrotated, and carry their runway's lateral offset.
            ForEach(Array(drawable.enumerated()), id: \.offset) { _, runway in
                let headingRad = runway.headingDeg * .pi / 180
                let azimuth = (runway.headingDeg + 180) * .pi / 180
                let radius = diameter * 0.34 * runway.relativeLength + 12
                Text(runway.ident)
                    .font(.system(size: 9, weight: .bold))
                    .monospaced()
                    .foregroundStyle(.secondary)
                    .offset(
                        x: sin(azimuth) * radius + cos(headingRad) * runway.lateral,
                        y: -cos(azimuth) * radius + sin(headingRad) * runway.lateral
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
