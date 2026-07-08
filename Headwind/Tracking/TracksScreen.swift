import SwiftUI
import MapKit
import HeadwindCore

/// Saved flight tracks: stats at a glance, replay on a map, one-tap
/// logbook entry with detected airborne time and landing count.
struct TracksScreen: View {
    @Environment(TrackRecorder.self) private var recorder
    @State private var captureShowsDetail = false

    var body: some View {
        Group {
            if recorder.savedTracks.isEmpty {
                ContentUnavailableView(
                    "No Tracks Yet",
                    systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                    description: Text("Start a recording from the map before takeoff — Headwind logs your path, detects takeoffs and landings, and pre-fills your logbook.")
                )
            } else {
                List {
                    ForEach(recorder.savedTracks) { track in
                        NavigationLink(value: track) {
                            TrackRow(track: track)
                        }
                    }
                    .onDelete { offsets in
                        // Resolve all offsets before deleting: delete()
                        // reloads savedTracks, shifting later indices.
                        let doomed = offsets.map { recorder.savedTracks[$0] }
                        doomed.forEach { recorder.delete($0) }
                    }
                }
            }
        }
        .navigationTitle("Track Logs")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TrackLog.self) { track in
            TrackDetailScreen(track: track)
        }
        .navigationDestination(isPresented: $captureShowsDetail) {
            if let first = recorder.savedTracks.first {
                TrackDetailScreen(track: first)
            }
        }
        .onAppear { recorder.loadSavedTracks() }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-screenshotTracks"),
               !recorder.savedTracks.isEmpty {
                try? await Task.sleep(for: .seconds(1))
                captureShowsDetail = true
            }
        }
    }
}

private struct TrackRow: View {
    @Environment(TrackRecorder.self) private var recorder
    let track: TrackLog

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(systemName: "point.bottomleft.forward.to.point.topright.scurvepath", tint: .teal)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    Text("\(Int(track.distanceNM.rounded())) NM")
                    Text(String(format: "%.1f h", track.durationHours))
                    let flights = recorder.flightCount(for: track)
                    if flights > 0 {
                        Text("\(flights) \(flights == 1 ? "flight" : "flights")")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }
}

struct TrackDetailScreen: View {
    let track: TrackLog

    @Environment(AirportStore.self) private var airports
    @State private var showingLogEditor = false
    @State private var gpxURL: URL?

    private var flights: [FlightDetector.Flight] {
        FlightDetector.flights(in: track)
    }

    var body: some View {
        List {
            Section {
                Map {
                    MapPolyline(coordinates: track.simplified().map(\.cl))
                        .stroke(.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    if let first = track.points.first {
                        Marker("Start", systemImage: "airplane.departure", coordinate: first.coordinate.cl)
                            .tint(.green)
                    }
                    if let last = track.points.last {
                        Marker("End", systemImage: "airplane.arrival", coordinate: last.coordinate.cl)
                            .tint(.orange)
                    }
                }
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
            }

            Section {
                HStack(spacing: 8) {
                    HeroStat(value: "\(Int(track.distanceNM.rounded()))", unit: "NM", label: "Distance")
                    HeroStat(value: String(format: "%.1f", FlightDetector.airborneHours(in: track)), unit: "HRS", label: "Airborne")
                    HeroStat(value: "\(Int(track.maxAltitudeFt.rounded()))", unit: "FT", label: "Max Alt")
                }
                .hwGlassCard()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Detected Flights") {
                if flights.isEmpty {
                    Text("No airborne segments detected — this track never sustained flying speed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(flights.enumerated()), id: \.offset) { index, flight in
                        LabeledContent("Flight \(index + 1)") {
                            Text("\(flight.takeoffTime, format: .dateTime.hour().minute()) – \(flight.landingTime, format: .dateTime.hour().minute()) · \(String(format: "%.1f h", flight.airborneHours))")
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                Button {
                    showingLogEditor = true
                } label: {
                    Label("Add to Logbook", systemImage: "book.closed.fill")
                }
                .disabled(flights.isEmpty)

                if let gpxURL {
                    ShareLink(
                        item: gpxURL,
                        preview: SharePreview(track.name)
                    ) {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLogEditor) {
            LogEntryEditor(prefilled: prefilledEntry())
        }
        .task(id: track.id) {
            gpxURL = writeGPXFile()
        }
    }

    /// Writes the GPX to a shareable temporary file URL — once per track,
    /// not on every body evaluation. Id-suffixed so two tracks sharing a
    /// display name can't clobber each other's export.
    private func writeGPXFile() -> URL? {
        let safeName = track.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(track.id.uuidString.prefix(8)).gpx")
        guard let data = track.gpx().data(using: .utf8),
              (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    /// Logbook entry seeded from the track: airborne hours, landings, and
    /// nearest airports to the endpoints.
    private func prefilledEntry() -> LogEntry {
        let entry = LogEntry()
        entry.date = track.startTime ?? .now
        entry.totalHours = (FlightDetector.airborneHours(in: track) * 10).rounded() / 10
        entry.picHours = entry.totalHours
        entry.dayLandings = flights.count
        if let start = track.points.first?.coordinate,
           let from = airports.nearest(to: start, limit: 1).first {
            entry.fromIdent = from.ident
        }
        if let end = track.points.last?.coordinate,
           let to = airports.nearest(to: end, limit: 1).first {
            entry.toIdent = to.ident
        }
        entry.remarks = "Auto-logged from track: \(Int(track.distanceNM.rounded())) NM, max \(Int(track.maxAltitudeFt.rounded())) ft."
        return entry
    }
}
