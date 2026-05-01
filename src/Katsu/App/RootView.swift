import SwiftUI

/// Top-level app shell. `HomeView` owns both first-run setup and the connected
/// recipe experience so the app always lands on one home surface.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        HomeView()
        .animation(.easeInOut, value: env.activeProfile?.id)
    }
}
