import SwiftUI

struct MoreScreen: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tools") {
                    NavigationLink {
                        WeightBalanceScreen()
                    } label: {
                        Label("Weight & Balance", systemImage: "scalemass")
                    }
                    NavigationLink {
                        ChecklistScreen()
                    } label: {
                        Label("Checklists", systemImage: "checklist")
                    }
                    NavigationLink {
                        WindsAloftScreen()
                    } label: {
                        Label("Winds Aloft", systemImage: "wind")
                    }
                    NavigationLink {
                        AirspaceScreen()
                    } label: {
                        Label("Airspace & TFRs", systemImage: "exclamationmark.triangle")
                    }
                    NavigationLink {
                        BriefingScreen()
                    } label: {
                        Label("AI Briefing", systemImage: "sparkles")
                    }
                }
                Section("App") {
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    NavigationLink {
                        AboutScreen()
                    } label: {
                        Label("About Headwind", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

struct SettingsScreen: View {
    @Environment(AirportStore.self) private var airports
    @Environment(PlateStore.self) private var plates
    @AppStorage("settings.homeAirport") private var homeAirport = ""

    var body: some View {
        List {
            Section("Pilot") {
                LabeledContent("Home airport") {
                    TextField("KPAO", text: $homeAirport)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section("Airports & Navaids") {
                LabeledContent("Airports", value: airports.airportCount.formatted())
                LabeledContent("Navaids", value: airports.navaidCount.formatted())
                LabeledContent("Source", value: "FAA via OurAirports")
            }

            Section("Procedures & Plates") {
                LabeledContent("Cycle", value: plates.cycle.isEmpty ? "—" : plates.cycle)
                if let status = plates.currencyStatus() {
                    LabeledContent("Status") {
                        DataCurrencyBadge(status: status)
                    }
                }
                if let effective = plates.currency?.effectiveDate,
                   let expires = plates.currency?.expirationDate {
                    LabeledContent("Valid") {
                        Text("\(effective, format: .dateTime.month().day()) – \(expires, format: .dateTime.month().day())")
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    Task { await plates.refreshFromRemote() }
                } label: {
                    HStack {
                        Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if plates.isCheckingForUpdate { ProgressView() }
                    }
                }
                .disabled(plates.isCheckingForUpdate)
                if let message = plates.updateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Aeronautical data is regenerated each 28-day FAA cycle by scripts/build-airport-db.py and scripts/build-plates-index.py. When the bundled cycle expires, Headwind fetches the current procedures automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await plates.load() }
    }
}

struct AboutScreen: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("Headwind")
                        .font(.title.weight(.bold))
                    Text("Free, modern flight planning for pilots.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }

            Section("Data Sources") {
                LabeledContent("Weather", value: "aviationweather.gov")
                LabeledContent("Airports & navaids", value: "FAA / OurAirports")
            }

            Section("Important") {
                Text("Headwind is not certified for navigation and is not a substitute for official charts, weather briefings, or NOTAMs. The pilot in command is solely responsible for the safety of each flight.")
                    .font(.footnote)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
