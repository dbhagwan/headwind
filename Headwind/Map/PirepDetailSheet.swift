import SwiftUI
import HeadwindCore

/// Detail card for a tapped pilot report.
struct PirepDetailSheet: View {
    let pirep: Pirep

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let aircraft = pirep.aircraft {
                        LabeledContent("Aircraft", value: aircraft)
                    }
                    if let altitude = pirep.altitudeFt {
                        LabeledContent("Altitude", value: "\(altitude.formatted()) ft")
                    }
                    if let turbulence = pirep.turbulence {
                        LabeledContent("Turbulence", value: turbulence)
                    }
                    if let icing = pirep.icing {
                        LabeledContent("Icing", value: icing)
                    }
                    if let weather = pirep.weather {
                        LabeledContent("Weather", value: weather)
                    }
                    if let temp = pirep.temperatureC {
                        LabeledContent("OAT", value: "\(temp)°C")
                    }
                    if let time = pirep.observationTime {
                        LabeledContent("Reported") {
                            Text(time, style: .relative) + Text(" ago")
                        }
                    }
                }
                if let raw = pirep.rawText {
                    Section("Raw Report") {
                        Text(raw)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle(pirep.reportType ?? "PIREP")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
