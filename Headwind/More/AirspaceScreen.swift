import SwiftUI
import HeadwindCore

/// Active TFRs from tfr.faa.gov, grouped by type. The map draws these as
/// red polygons; this screen is the readable list.
struct AirspaceScreen: View {
    @Environment(TFRService.self) private var tfrService

    private var grouped: [(type: String, tfrs: [TFR])] {
        Dictionary(grouping: tfrService.tfrs) { $0.item.type ?? "OTHER" }
            .map { (type: $0.key, tfrs: $0.value) }
            .sorted { $0.type < $1.type }
    }

    var body: some View {
        List {
            if let updated = tfrService.lastUpdated {
                Section {
                    LabeledContent("Active TFRs", value: tfrService.tfrs.count.formatted())
                    LabeledContent("Updated") {
                        Text(updated, style: .relative) + Text(" ago")
                    }
                }
            }

            if let error = tfrService.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            ForEach(grouped, id: \.type) { group in
                Section(group.type.capitalized) {
                    ForEach(group.tfrs) { tfr in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(tfr.item.notamID)
                                    .font(.subheadline.weight(.semibold))
                                    .monospaced()
                                Spacer()
                                if let state = tfr.item.state {
                                    Text(state)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let description = tfr.item.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if tfrService.tfrs.isEmpty && !tfrService.isLoading && tfrService.lastError == nil {
                Section {
                    Text("No TFRs loaded yet — pull to refresh.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if tfrService.isLoading && tfrService.tfrs.isEmpty {
                ProgressView("Loading TFRs…")
            }
        }
        .navigationTitle("Airspace · TFRs")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await tfrService.refresh()
        }
        .task {
            if tfrService.tfrs.isEmpty {
                await tfrService.refresh()
            }
        }
    }
}
