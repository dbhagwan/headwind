import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                MapScreen()
            }
            Tab("Plan", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") {
                PlannerScreen()
            }
            Tab("Weather", systemImage: "cloud.sun.fill") {
                WeatherScreen()
            }
            Tab("Logbook", systemImage: "book.closed.fill") {
                LogbookScreen()
            }
            Tab("More", systemImage: "ellipsis.circle.fill") {
                MoreScreen()
            }
            Tab(role: .search) {
                AirportSearchScreen()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
        .environment(AirportStore())
        .environment(WeatherService())
        .environment(PlanStore())
        .environment(LocationService())
        .environment(BriefingService())
}
