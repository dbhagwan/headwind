import SwiftUI

/// First-launch flow that introduces Headwind and, critically, requires the
/// pilot to acknowledge the not-for-navigation disclaimer before the app can
/// be used. Bump `currentVersion` to re-present after a material change.
struct OnboardingView: View {
    static let currentVersion = 1

    var onComplete: () -> Void

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                features.tag(1)
                disclaimer.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.15, blue: 0.36), Color(red: 0.11, green: 0.20, blue: 0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "airplane.departure")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(radius: 12)
            Text("Welcome to Headwind")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A free, modern flight companion for general-aviation pilots.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding()
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Text("Everything for preflight")
                .font(.title.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .center)
            VStack(alignment: .leading, spacing: 22) {
                featureRow("map", "Charts & moving map", "VFR sectionals and IFR charts with offline download.")
                featureRow("cloud.sun", "Live weather", "METARs, TAFs, winds aloft, and AI briefings.")
                featureRow("doc.on.doc", "Procedures", "Approach plates and airport diagrams for every field.")
                featureRow("point.topleft.down.to.point.bottomright.curvepath", "Planning", "Wind-corrected routes, fuel, weight & balance, logbook.")
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
        .padding()
    }

    private var disclaimer: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
            Text("Before You Fly")
                .font(.title.weight(.bold))
            VStack(spacing: 14) {
                Text("Headwind is **not certified for navigation**. It is not a substitute for official charts, a regulatory weather briefing, or NOTAMs.")
                Text("All data is for planning and situational awareness only and may be incomplete or out of date. The **pilot in command is solely responsible** for the safe conduct of every flight.")
                Text("Headwind uses your location only on this device, to show your position and nearby airports. It is never transmitted.")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.subheadline)
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
        .padding()
    }

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0...lastPage, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index == page ? 0.95 : 0.3))
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.snappy, value: page)
                }
            }

            Button {
                if page < lastPage {
                    page += 1
                } else {
                    onComplete()
                }
            } label: {
                Text(page < lastPage ? "Continue" : "I Understand & Agree")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color(red: 0.11, green: 0.20, blue: 0.45))
            .controlSize(.large)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
