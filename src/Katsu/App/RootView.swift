import SwiftUI

/// Top-level app gate. If no server is configured, present onboarding;
/// otherwise show the home shell.
struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        Group {
            if env.activeProfile == nil {
                OnboardingFlowView()
            } else {
                HomeView()
            }
        }
        .animation(.easeInOut, value: env.activeProfile?.id)
    }
}
