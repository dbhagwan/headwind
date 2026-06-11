import SwiftUI
import HeadwindCore

/// AI weather briefing for the active route (or favorite stations),
/// grounded in live METAR data.
struct BriefingScreen: View {
    @Environment(BriefingService.self) private var briefing
    @Environment(WeatherService.self) private var weather
    @Environment(PlanStore.self) private var plan

    @AppStorage("weather.favorites") private var favoritesCSV = "KSFO,KOAK,KSJC,KPAO"
    @State private var briefingText: String?

    private var stations: [String] {
        if plan.waypoints.count >= 2 {
            return plan.waypoints.map(\.ident)
        }
        return favoritesCSV.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        plan.waypoints.count >= 2 ? "Route: \(plan.routeString)" : "Favorite stations",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    .font(.subheadline.weight(.semibold))

                    Text("Engine: \(briefing.engine.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .hwGlassCard(cornerRadius: 16)

                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        if briefing.isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(briefing.isGenerating ? "Generating…" : "Generate Briefing")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(briefing.isGenerating || stations.isEmpty)

                if let briefingText {
                    Text(briefingText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hwGlassCard()
                }

                Text("Generated summaries are an aid, not an official weather briefing. Always obtain a regulatory briefing before flight.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("AI Briefing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generate() async {
        await weather.refreshMetars(for: stations)
        let metars = stations.compactMap { weather.metar(for: $0) }
        guard !metars.isEmpty else {
            briefingText = "No weather observations available for \(stations.joined(separator: ", ")). Check the identifiers and your connection."
            return
        }
        briefingText = await briefing.briefing(
            for: metars,
            routeDescription: plan.waypoints.count >= 2 ? plan.routeString : nil
        )
    }
}
