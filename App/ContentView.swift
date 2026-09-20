import SwiftUI
import ManagedSettings
import IntentionCore

struct ContentView: View {
    @StateObject private var access = AccessController()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("seuil.onboarded") private var onboarded = false

    var body: some View {
        Group {
            if onboarded {
                RootView(access: access)
            } else {
                OnboardingView(access: access) { withAnimation { onboarded = true } }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                access.refresh()
                NotificationScheduler.reschedule(state: access.state)
            }
        }
        .task {
            access.refresh()
            NotificationScheduler.reschedule(state: access.state)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
                if scenePhase == .active { access.refresh() }
            }
        }
    }
}

enum MainTab: CaseIterable {
    case home, apps, timer

    var title: String {
        switch self {
        case .home: return "Accueil"
        case .apps: return "Mes Apps"
        case .timer: return "Minuteur"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "circle.circle"
        case .apps: return "square.grid.2x2.fill"
        case .timer: return "play.fill"
        }
    }
}

/// Any screen can ask for the paywall through the environment.
struct RequestProKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var requestPro: () -> Void {
        get { self[RequestProKey.self] }
        set { self[RequestProKey.self] = newValue }
    }
}

struct RootView: View {
    @ObservedObject var access: AccessController
    @StateObject private var store = ProStore()
    @State private var tab = MainTab.home
    @State private var showPaywall = false
    @State private var showDoors = false
    @State private var unlocking: ApplicationToken?
    @State private var settingsRoute: SettingsRoute?

    var body: some View {
        ZStack(alignment: .bottom) {
            GlowBackground()
            ZStack {
                HomeView(access: access, onUnlock: { unlocking = $0 }, onShowApps: { tab = .apps },
                         onFocus: { tab = .timer }, onRoute: { settingsRoute = $0 }, onDoors: { showDoors = true })
                    .tabPage(isCurrent: tab == .home)
                AppsView(access: access, onUnlock: { unlocking = $0 })
                    .tabPage(isCurrent: tab == .apps)
                TimerView(access: access)
                    .tabPage(isCurrent: tab == .timer)
            }
            .animation(.easeInOut(duration: 0.2), value: tab)
            FloatingTabBar(selection: $tab)
                .padding(.bottom, 6)
        }
        .foregroundStyle(.white)
        .tint(SeuilTheme.accent)
        .environmentObject(store)
        .environment(\.requestPro, { showPaywall = true })
        .sheet(isPresented: $showPaywall) { PaywallView(store: store) }
        .fullScreenCover(isPresented: $showDoors) { DoorsView(access: access) }
        // A shield's "earn an unlock" button brings the user straight to the challenge.
        .onChange(of: access.state.pendingApplication) { _, pending in
            if let pending { unlocking = pending }
        }
        .onAppear {
            if let pending = access.state.pendingApplication { unlocking = pending }
            // UI tests jump straight to the settings instead of driving the profile menu.
            if ProcessInfo.processInfo.arguments.contains("--open-settings") { settingsRoute = .settings }
        }
        .sheet(item: Binding(get: { unlocking.map(UnlockTarget.init) },
                             set: { if $0 == nil { unlocking = nil; access.dismissPending() } })) { target in
            UnlockSheet(access: access, application: target.token) {
                unlocking = nil
                access.dismissPending()
            }
        }
        .sheet(item: $settingsRoute) { route in
            NavigationStack {
                switch route {
                case .settings: SettingsView(access: access, store: store)
                case .account: AccountView()
                case .shields: ShieldDesignView(access: access)
                case .autofocus: AutofocusView(access: access)
                }
            }
            .presentationBackground(.black)
        }
    }
}

extension View {
    /// Tabs stay mounted to keep their scroll position, so hidden ones must not
    /// swallow taps or show up in the accessibility tree.
    func tabPage(isCurrent: Bool) -> some View {
        opacity(isCurrent ? 1 : 0)
            .allowsHitTesting(isCurrent)
            .accessibilityHidden(!isCurrent)
    }
}

enum SettingsRoute: String, Identifiable {
    case settings, account, shields, autofocus
    var id: String { rawValue }
}

struct UnlockTarget: Identifiable {
    let token: ApplicationToken
    var id: Int { token.hashValue }
}

struct FloatingTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol).font(.system(size: 22, weight: .semibold))
                        Text(tab.title).font(.caption.weight(.medium))
                    }
                    .frame(width: 96, height: 58)
                    .background {
                        if selection == tab {
                            Capsule().fill(Color.white.opacity(0.14)).matchedGeometryEffect(id: "tab", in: highlight)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }
}

/// Full-screen unlock: why it is blocked, how long, then the chosen challenge.
struct UnlockSheet: View {
    @ObservedObject var access: AccessController
    let application: ApplicationToken
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    UnlockFlow(application: application, state: access.state,
                               onGranted: { minutes in
                                   do {
                                       try access.grant(application: application, minutes: minutes)
                                       onClose()
                                   } catch { access.message = error.localizedDescription }
                               },
                               onEmergency: {
                                   access.useEmergencyPass()
                                   if access.state.isEmergencyActive(now: Date()) { onClose() }
                               },
                               onDismiss: onClose)
                    if !access.message.isEmpty {
                        Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                    }
                }
                .padding(20)
            }
            .background(GlowBackground())
            .navigationTitle("Débloquer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(.black)
    }
}
