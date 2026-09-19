import SwiftUI

@main
struct IntentionApp: App {
    init() {
        // UI tests pick the starting screen; a launch-argument default would mask later writes.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-onboarding") { UserDefaults.standard.set(false, forKey: "seuil.onboarded") }
        if arguments.contains("--skip-onboarding") { UserDefaults.standard.set(true, forKey: "seuil.onboarded") }
    }

    var body: some Scene { WindowGroup { ContentView() } }
}
