import SwiftUI

@main
struct KatsuApp: App {
    @StateObject private var environment: AppEnvironment

    init() {
        let configuration = AppConfiguration.fromProcess()
        _environment = StateObject(wrappedValue: AppEnvironment.live(configuration: configuration))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .tint(DesignSystem.accent)
                .tracksDeviceHinge()
        }
    }
}
