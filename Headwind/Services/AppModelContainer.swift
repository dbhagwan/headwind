import Foundation
import SwiftData

/// The app's single ModelContainer, shared between the SwiftUI scene and
/// App Intents (which can run while the app is backgrounded — they must
/// hit the same store, not build their own).
///
/// CloudKit-backed when possible, local otherwise. The fallback matters
/// in three real situations: demo/capture runs (deterministic data, no
/// account), unsigned CI builds (no iCloud entitlement — CloudKit
/// container creation throws), and devices signed out of iCloud. The app
/// must behave identically in all of them, just without sync.
enum AppModelContainer {
    static var shared: ModelContainer { made.container }
    static var cloudSyncActive: Bool { made.cloudSyncActive }

    private static let made: (container: ModelContainer, cloudSyncActive: Bool) = {
        let schema = Schema([LogEntry.self, UserAircraft.self])

        if !DemoData.isEnabled {
            let cloud = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.headwind.app")
            )
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                return (container, true)
            }
        }

        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return (try ModelContainer(for: schema, configurations: local), false)
        } catch {
            fatalError("Cannot create model container: \(error)")
        }
    }()
}
