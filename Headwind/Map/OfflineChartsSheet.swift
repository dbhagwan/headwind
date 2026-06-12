import SwiftUI
import MapKit
import HeadwindCore

/// Downloads the current map area's chart tiles for offline flight.
struct OfflineChartsSheet: View {
    let layer: ChartLayer
    let region: MKCoordinateRegion?

    @Environment(\.dismiss) private var dismiss

    @State private var done = 0
    @State private var total = 0
    @State private var downloadTask: Task<Void, Never>?
    @State private var statusText: String?
    @State private var cacheBytes: Int64 = 0

    private static let zooms = 8...11
    private static let bytesPerTileEstimate = 35_000
    private static let tileLimit = 4000

    private var bounds: GeoBounds? {
        guard let region else { return nil }
        return GeoBounds(
            minLat: region.center.latitude - region.span.latitudeDelta / 2,
            maxLat: region.center.latitude + region.span.latitudeDelta / 2,
            minLon: region.center.longitude - region.span.longitudeDelta / 2,
            maxLon: region.center.longitude + region.span.longitudeDelta / 2
        )
    }

    private var tileCount: Int {
        bounds.map { TileMath.tileCount(covering: $0, zooms: Self.zooms) } ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Download Area") {
                    LabeledContent("Chart", value: layer.title)
                    LabeledContent("Tiles (zoom 8–11)", value: tileCount.formatted())
                    LabeledContent(
                        "Estimated size",
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(tileCount * Self.bytesPerTileEstimate),
                            countStyle: .file
                        )
                    )

                    if tileCount > Self.tileLimit {
                        Label("Zoom the map in to a smaller area to download.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if downloadTask != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: total > 0 ? Double(done) / Double(total) : 0)
                            Text("\(done.formatted()) of \(total.formatted()) tiles")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Cancel", role: .destructive) {
                            downloadTask?.cancel()
                            downloadTask = nil
                        }
                    } else {
                        Button {
                            startDownload()
                        } label: {
                            Label("Download for Offline Use", systemImage: "arrow.down.circle.fill")
                        }
                        .disabled(bounds == nil || layer == .none || tileCount == 0)
                    }

                    if let statusText {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Chart Cache") {
                    LabeledContent(
                        "On disk",
                        value: ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)
                    )
                    Button("Clear Cache", role: .destructive) {
                        Task {
                            await ChartTileCache.shared.clear()
                            cacheBytes = await ChartTileCache.shared.cacheSizeBytes()
                            statusText = "Cache cleared."
                        }
                    }
                }

                Section {
                    Text("Charts are FAA raster products served from the FAA's public tile service. Downloaded tiles let the map work without connectivity, but always verify chart currency before flight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Offline Charts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                cacheBytes = await ChartTileCache.shared.cacheSizeBytes()
            }
        }
    }

    private func startDownload() {
        guard let bounds else { return }
        statusText = nil
        done = 0
        total = tileCount

        downloadTask = Task {
            do {
                let fetched = try await ChartTileCache.shared.prefetch(
                    layer: layer,
                    bounds: bounds,
                    zooms: Self.zooms
                ) { completed, totalTiles in
                    Task { @MainActor in
                        done = completed
                        total = totalTiles
                    }
                }
                statusText = fetched == 0
                    ? "Already downloaded — every tile was cached."
                    : "Downloaded \(fetched.formatted()) tiles."
            } catch is CancellationError {
                statusText = "Download cancelled."
            } catch {
                statusText = "Download failed: \(error.localizedDescription)"
            }
            cacheBytes = await ChartTileCache.shared.cacheSizeBytes()
            downloadTask = nil
        }
    }
}
