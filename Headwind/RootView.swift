import SwiftUI

/// Gates the app behind the first-launch disclaimer. ContentView (and its
/// location/data startup) is only created once the pilot has acknowledged
/// the not-for-navigation terms.
struct RootView: View {
    @AppStorage("onboarding.acceptedVersion") private var acceptedVersion = 0

    private var needsOnboarding: Bool {
        acceptedVersion < OnboardingView.currentVersion && !DemoData.isEnabled
    }

    var body: some View {
        if needsOnboarding {
            OnboardingView {
                withAnimation(.smooth) {
                    acceptedVersion = OnboardingView.currentVersion
                }
            }
            .transition(.opacity)
        } else {
            ContentView()
        }
    }
}
