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
            Section("Database") {
                LabeledContent("Airports", value: airports.airportCount.formatted())
                LabeledContent("Navaids", value: airports.navaidCount.formatted())
                LabeledContent("Source", value: "FAA via OurAirports")
            }
            Section {
                Text("Airport and navaid data is regenerated from the public FAA NASR cycle with scripts/build-airport-db.py.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
