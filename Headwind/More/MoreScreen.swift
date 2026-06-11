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
                        BriefingScreen()
                    } label: {
                        Label("AI Briefing", systemImage: "sparkles")
                    }
                }
                Section("App") {
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
                LabeledContent("Airports", value: "Bundled sample (v0.1)")
            }

            Section("Important") {
                Text("Headwind is not certified for navigation and is not a substitute for official charts, weather briefings, or NOTAMs. All bundled data is for planning and educational use only. The pilot in command is solely responsible for the safety of each flight.")
                    .font(.footnote)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
