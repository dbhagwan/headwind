import SwiftUI

enum AppTab: String, Hashable {
    case map, plan, weather, logbook, more, search
}

struct ContentView: View {
    @Environment(PlanStore.self) private var plan
    @Environment(AirportStore.self) private var airports
    @Environment(LocationService.self) private var location
    @Environment(WeatherService.self) private var weather
    @Environment(TrackRecorder.self) private var tracks
    @Environment(\.modelContext) private var modelContext

    @State private var selection: AppTab = ContentView.initialTab()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Map", systemImage: "map.fill", value: AppTab.map) {
                MapScreen()
            }
            Tab("Plan", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill", value: AppTab.plan) {
                PlannerScreen()
            }
            Tab("Weather", systemImage: "cloud.sun.fill", value: AppTab.weather) {
                WeatherScreen()
            }
            Tab("Logbook", systemImage: "book.closed.fill", value: AppTab.logbook) {
                LogbookScreen()
            }
            Tab("More", systemImage: "ellipsis.circle.fill", value: AppTab.more) {
                MoreScreen()
            }
            Tab(value: AppTab.search, role: .search) {
                AirportSearchScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .task {
            location.start()
            weather.loadCache()
            await airports.load()
            DemoData.seedIfNeeded(plan: plan, airports: airports, tracks: tracks, context: modelContext)
            consumeTabRequest()
            await LogbookIndexer.reindexAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .headwindTabRequested)) { _ in
            consumeTabRequest()
        }
    }

    /// Siri/Shortcuts intents route to a tab via AppTabRouter; the
    /// request may predate this view on cold launch, so it's consumed
    /// both on appear and on notification.
    private func consumeTabRequest() {
        if let tab = AppTabRouter.requested {
            AppTabRouter.requested = nil
            selection = tab
        }
    }

    /// Allows CI screenshot automation to open the app on a specific tab:
    /// `simctl launch <udid> com.headwind.app -screenshotTab weather`
    private static func initialTab() -> AppTab {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-screenshotTab"),
           index + 1 < args.count,
           let tab = AppTab(rawValue: args[index + 1]) {
            return tab
        }
        return .map
    }
}

#Preview {
    ContentView()
        .environment(AirportStore())
        .environment(WeatherService())
        .environment(PlanStore())
        .environment(LocationService())
        .environment(BriefingService())
        .environment(TFRService())
        .environment(AirspaceService())
        .environment(PlateStore())
        .environment(TrackRecorder())
}
