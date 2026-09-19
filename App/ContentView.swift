import SwiftUI

struct ContentView: View {
    @StateObject private var access = AccessController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = Tab.today
    @AppStorage("seuil.onboarded") private var onboarded = false

    enum Tab { case today, routines, settings }

    var body: some View {
        Group {
            if onboarded {
                tabs
            } else {
                OnboardingView(access: access) { withAnimation { onboarded = true } }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { access.refresh() }
        }
        .task {
            access.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
                if scenePhase == .active { access.refresh() }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            NavigationStack { TodayView(access: access).toolbar(.hidden, for: .navigationBar) }
                .tabItem { Label("Aujourd’hui", systemImage: "hand.raised") }
                .tag(Tab.today)
            NavigationStack { RoutinesView(access: access) }
                .tabItem { Label("Routines", systemImage: "calendar.badge.clock") }
                .tag(Tab.routines)
            NavigationStack { SettingsView(access: access) }
                .tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
                .tag(Tab.settings)
        }
        .foregroundStyle(SeuilTheme.ink)
        .tint(SeuilTheme.accent)
        // A shield's "earn an unlock" button brings the user straight to the unlock flow.
        .onChange(of: access.state.pendingApplication) { _, pending in
            if pending != nil { tab = .today }
        }
    }
}
