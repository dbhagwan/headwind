import Foundation
import Observation
import HeadwindCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Generates plain-English weather briefings.
///
/// Uses the on-device Apple Intelligence foundation model when available,
/// always grounded in the actual METAR data. Falls back to a deterministic
/// summarizer on devices without Apple Intelligence — the feature never
/// disappears, it just gets less conversational.
@MainActor
@Observable
final class BriefingService {
    enum Engine: String {
        case appleIntelligence = "Apple Intelligence (on-device)"
        case deterministic = "Standard summarizer"
    }

    var engine: Engine {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return .appleIntelligence
        }
        #endif
        return .deterministic
    }

    private(set) var isGenerating = false

    /// Produces a route-ordered weather briefing for the given observations.
    func briefing(for metars: [Metar], routeDescription: String?) async -> String {
        isGenerating = true
        defer { isGenerating = false }

        let fallback = metars
            .map { MetarSummarizer.plainEnglish(for: $0) }
            .joined(separator: "\n\n")

        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            let observations = metars.map { metar in
                "\(metar.stationID) (\(metar.flightCategory.rawValue)): \(metar.rawText ?? MetarSummarizer.plainEnglish(for: metar))"
            }
            .joined(separator: "\n")

            let route = routeDescription.map { "The pilot's route is: \($0).\n" } ?? ""
            let prompt = """
            \(route)Here are the current METAR observations:

            \(observations)

            Brief the pilot on these conditions.
            """

            do {
                let session = LanguageModelSession(instructions: """
                You are a concise, professional aviation weather briefer for \
                general-aviation pilots. Summarize the provided METAR \
                observations in plain English, ordered along the route. Lead \
                with the overall picture (VFR/MVFR/IFR/LIFR), then call out \
                anything a pilot should care about: gusts, crosswinds, low \
                ceilings, low visibility, or big temperature/dewpoint spreads. \
                Use only the data provided — never invent conditions. Keep it \
                under 200 words. End with a one-line reminder that this is not \
                an official weather briefing.
                """)
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                // Guardrail or generation failure: fall back to deterministic output.
            }
        }
        #endif

        return fallback
    }
}
