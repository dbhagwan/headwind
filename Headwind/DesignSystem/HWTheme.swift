import SwiftUI
import HeadwindCore

/// Headwind design system: Liquid Glass surfaces, flight-category color
/// language, and shared typography helpers.
extension FlightCategory {
    var color: Color {
        switch self {
        case .vfr: .green
        case .mvfr: .blue
        case .ifr: .red
        case .lifr: .purple
        }
    }
}

struct FlightCategoryBadge: View {
    let category: FlightCategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption.weight(.bold))
            .monospaced()
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.color.gradient, in: .capsule)
    }
}

extension View {
    /// Standard Headwind floating glass card.
    func hwGlassCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// Compact value readout used in instrument strips ("GS 104 KT").
struct InstrumentReadout: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 64)
    }
}
