import SwiftUI

@MainActor
enum AppState {
    static let engine = SlapEngine()
    static let settings = SettingsStore()
}

@main
struct SlapBackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var engine = AppState.engine
    @ObservedObject private var settings = AppState.settings
    @State private var showOnboarding = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(engine: engine, settings: settings)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: engine.menuBarBounce ? "hand.raised" : "hand.raised.fill")
                if settings.showCountInMenuBar && engine.isRunning && engine.slapCount > 0 {
                    Text("\(engine.slapCount)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let engine = AppState.engine
            let settings = AppState.settings

            settings.applyAll(to: engine)

            if !settings.hasCompletedOnboarding {
                showOnboarding(engine: engine, settings: settings)
            } else {
                engine.start()
            }
        }
    }

    @MainActor
    private func showOnboarding(engine: SlapEngine, settings: SettingsStore) {
        WindowManager.shared.openSwiftUI(
            id: "onboarding", title: "Welcome to SlapBack",
            width: 420, height: 340,
            view: OnboardingView(hasCompletedOnboarding: Binding(
                get: { settings.hasCompletedOnboarding },
                set: { done in
                    settings.hasCompletedOnboarding = done
                    if done {
                        settings.applyAll(to: engine)
                        engine.start()
                        WindowManager.shared.close(id: "onboarding")
                    }
                }
            ))
        )
    }
}
