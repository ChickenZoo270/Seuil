import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import IntentionCore

extension DeviceActivityReport.Context {
    static let home = Self("home")
    static let detail = Self("detail")
}

/// Today's usage, hour by hour, on this iPhone.
func todayFilter() -> DeviceActivityFilter {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
    return DeviceActivityFilter(segment: .hourly(during: DateInterval(start: start, end: end)),
                                users: .all, devices: .init([.iPhone]))
}

struct HomeView: View {
    @ObservedObject var access: AccessController
    let onUnlock: (ApplicationToken) -> Void
    let onShowApps: () -> Void
    let onFocus: () -> Void
    let onRoute: (SettingsRoute) -> Void
    let onDoors: () -> Void
    @State private var showDetail = false
    @State private var showMenu = false
    @AppStorage("profile.name") private var name = ""
    @AppStorage("profile.hours") private var hours = 4.0
    @AppStorage("profile.rate") private var rate = 25
    @State private var filter = todayFilter()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                Button(action: onDoors) { hero }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.hero")
                    .accessibilityLabel("Tes portes")
                if access.authorized {
                    // The report is drawn out of process: it eats every touch, which
                    // froze the scroll as soon as a finger landed on it. Turning its
                    // interaction off hands drags back to the ScrollView, and a clear
                    // layer on top keeps the tap that opens the detail.
                    DeviceActivityReport(.home, filter: filter)
                        .frame(minHeight: 760)
                        .allowsHitTesting(false)
                        .overlay(alignment: .top) {
                            Color.white.opacity(0.001).frame(height: 330)
                                .onTapGesture { showDetail = true }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel("Voir le détail du score")
                        }
                } else {
                    permissionCard
                }
                nextRuleCard
                if let task = setupTask { setupCard(task) }
                analysesCard
                streakCard
                // Clears the floating unlock pill (92 + 56) and the tab bar.
                Color.clear.frame(height: 220)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { unlockPill.padding(.horizontal, 20).padding(.bottom, 92) }
        .overlay(alignment: .topTrailing) {
            if showMenu {
                ZStack(alignment: .topTrailing) {
                    Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { withAnimation { showMenu = false } }
                    profileMenu.padding(.top, 64).padding(.trailing, 20)
                        .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
                }
            }
        }
        .onAppear { filter = todayFilter() }
        .sheet(isPresented: $showDetail) { ScoreDetailSheet(filter: filter) }
    }

    /// The most advanced door earned so far, or the orb until the first one opens.
    @ViewBuilder
    private var hero: some View {
        if let door = Door.latest(access.state.progressStats(now: Date())) {
            VStack(spacing: 10) {
                DoorScene(door: door, locked: false)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                Text(door.title).font(.headline).foregroundStyle(SeuilTheme.secondaryInk)
            }
        } else {
            GlowOrb(size: 170).padding(.vertical, 8)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                SeuilMark()
                Text("seuil").font(.system(size: 34, weight: .semibold, design: .rounded))
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(.orange.gradient)
                Text("\(access.state.streak(now: Date()))").font(.title3.monospacedDigit())
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: Capsule())
            .accessibilityLabel("Série de \(access.state.streak(now: Date())) jours")
            CircleIconButton(symbol: "person.fill", size: 46) { withAnimation(.spring(response: 0.3)) { showMenu.toggle() } }
                .accessibilityIdentifier("home.settings")
                .accessibilityLabel("Profil")
        }
        .padding(.top, 8)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Temps d’écran").font(.title3.weight(.semibold))
            Text("Seuil a besoin de ton autorisation pour calculer ton score et verrouiller tes apps.")
                .foregroundStyle(SeuilTheme.secondaryInk)
            Button("Autoriser") { Task { await access.authorize() } }
                .buttonStyle(PillButtonStyle())
        }
        .glassCard()
    }

    private var nextRuleCard: some View {
        Button(action: onShowApps) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Mes apps").font(.headline).foregroundStyle(SeuilTheme.secondaryInk)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(SeuilTheme.secondaryInk)
                    Spacer()
                }
                HStack(spacing: 14) {
                    Image(systemName: "shield.fill").font(.title).foregroundStyle(SeuilTheme.accentGradient)
                    Text(nextRuleText).font(.title3.weight(.semibold)).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                if !access.state.applications.isEmpty {
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack {
                        AppIconRow(tokens: Array(access.state.applications), size: 34, maximum: 5)
                        Spacer()
                        Text(access.blockedApplications.isEmpty ? "Aucune app bloquée" : "\(access.blockedApplications.count) bloquées")
                            .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                    }
                }
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var nextRuleText: String {
        let now = Date()
        if let focus = access.state.focus, focus.endsAt > now {
            return "\(focus.name) en cours jusqu’à \(focus.endsAt.formatted(date: .omitted, time: .shortened))"
        }
        if let active = access.state.activeRoutines.first { return "\(active.name) est en cours" }
        if let next = RoutineSchedule.next(access.state.routines, after: now) {
            return "\(next.routine.name) commence \(RoutineSchedule.relative(next.start, from: now))"
        }
        return access.state.rules.isEmpty ? "Choisis les apps qui te distraient" : "\(access.state.rules.count) apps sous contrôle"
    }

    /// One step of the setup that is still missing, or nothing once all is done.
    private var setupTask: SetupTask? {
        if !access.authorized { return .permission }
        if access.state.applications.isEmpty { return .distracting }
        if access.state.allowedApplications.isEmpty { return .allowed }
        if access.state.rules.isEmpty && access.state.routines.isEmpty { return .rule }
        return nil
    }

    private func setupCard(_ task: SetupTask) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus").foregroundStyle(SeuilTheme.accent)
                Text("Termine ta configuration").font(.headline).foregroundStyle(SeuilTheme.accent)
                Spacer()
            }
            Text(task.title).font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 14) {
                Text(task.subtitle).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Configurer") { task.open(access: access, onShowApps: onShowApps, onRoute: onRoute) }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
            }
        }
        .glassCard()
    }

    /// What the hours spent scrolling are worth, at a rate the user sets.
    private var analysesCard: some View {
        let weekly = hours * 7 / 2 * Double(rate)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Analyses").font(.headline).foregroundStyle(SeuilTheme.secondaryInk)
                Spacer()
            }
            Text("Moitié moins d’écran, c’est \(Int(weekly.rounded())) € de ton temps repris chaque semaine.")
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Color.white.opacity(0.08))
            HStack {
                Text("Ton heure vaut").font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                Spacer()
                CountStepper(value: $rate, range: 5...200, step: 5)
                Text("€/h").font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .glassCard()
    }

    private var streakCard: some View {
        let streak = access.state.streak(now: Date())
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(streak == 0 ? "Lance ta série" : "Série de \(streak) jour\(streak > 1 ? "s" : "")")
                    .font(.title3.weight(.semibold))
                Text(streak == 0
                     ? "Une journée sans déblocage ni limite dépassée, et la flamme s’allume."
                     : "Aucun déblocage ni limite dépassée. Continue comme ça.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
            }
            Spacer()
            ZStack {
                Image(systemName: "flame.fill").font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .orange.opacity(0.6), radius: 16)
                Text("\(streak)").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.black).offset(y: 10)
            }
        }
        .glassCard()
    }

    private var profileMenu: some View {
        VStack(spacing: 0) {
            menuButton(.account) {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill").font(.largeTitle).foregroundStyle(SeuilTheme.accentGradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? "Toi" : name).font(.title3.weight(.semibold))
                        Text("Voir ton profil").foregroundStyle(SeuilTheme.secondaryInk)
                    }
                    Spacer()
                }
                .padding(18)
            }
            Divider().overlay(Color.white.opacity(0.1))
            HStack(spacing: 0) {
                menuButton(.shields) { tile("bolt.shield.fill", "Écrans de blocage") }
                menuButton(.autofocus) { tile("sparkles", "Autofocus") }
            }
            Divider().overlay(Color.white.opacity(0.1))
            ShareLink(item: "Je reprends la main sur mon téléphone avec Seuil. Chaque app se mérite 🔥") {
                menuRow("square.and.arrow.up", "Partager Seuil", "Aide un ami à décrocher")
            }
            .buttonStyle(.plain)
            Button {
                showMenu = false
                onDoors()
            } label: { menuRow("door.left.hand.open", "Mes portes", "Tes seuils franchis") }
            .buttonStyle(.plain)
            menuButton(.settings) { menuRow("gearshape.fill", "Paramètres", nil) }
                .accessibilityIdentifier("menu.settings")
        }
        .frame(width: 300)
        .accessibilityIdentifier("home.profileMenu")
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
    }

    private func menuButton<Label: View>(_ route: SettingsRoute, @ViewBuilder label: () -> Label) -> some View {
        Button {
            showMenu = false
            onRoute(route)
        } label: { label() }
        .buttonStyle(.plain)
        // A plain style with a custom label is not always exposed as a button.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func tile(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title2).foregroundStyle(SeuilTheme.accentGradient)
            Text(title).font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
    }

    private func menuRow(_ symbol: String, _ title: String, _ subtitle: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(SeuilTheme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk) }
            }
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    @ViewBuilder
    private var unlockPill: some View {
        let blocked = access.blockedApplications
        if blocked.isEmpty, access.authorized, !access.state.isFocusActive(now: Date()) {
            Button(action: onFocus) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text("Lance un Focus").font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(colors: [SeuilTheme.glow.opacity(0.9), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)))
                .overlay(Capsule().strokeBorder(SeuilTheme.accentGradient.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
        if let first = blocked.first {
            Button { onUnlock(first) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").padding(8)
                        .background(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 9))
                    Text("Débloque les apps").font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
    }
}

/// The next thing to set up, shown on the home screen until nothing is left.
enum SetupTask {
    case permission, distracting, allowed, rule

    var title: String {
        switch self {
        case .permission: return "Autorise Temps d’écran"
        case .distracting: return "Choisis tes apps distrayantes"
        case .allowed: return "Définis tes apps toujours autorisées"
        case .rule: return "Crée ta première règle"
        }
    }

    var subtitle: String {
        switch self {
        case .permission: return "Sans cette autorisation, Seuil ne peut rien bloquer."
        case .distracting: return "Ce sont elles que Seuil mettra sous contrôle."
        case .allowed: return "Ces apps ne seront jamais bloquées."
        case .rule: return "Une limite ou une routine, et tout se met en place."
        }
    }

    @MainActor
    func open(access: AccessController, onShowApps: () -> Void, onRoute: (SettingsRoute) -> Void) {
        switch self {
        case .permission: Task { await access.authorize() }
        case .distracting, .allowed, .rule: onShowApps()
        }
    }
}

struct ScoreDetailSheet: View {
    let filter: DeviceActivityFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                DeviceActivityReport(.detail, filter: filter).frame(minHeight: 1300)
            }
            .background(GlowBackground())
            .navigationTitle("Aujourd’hui")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
        .presentationBackground(.black)
    }
}

/// When enabled routines next start.
enum RoutineSchedule {
    static func next(_ routines: [Routine], after now: Date, calendar: Calendar = .current) -> (routine: Routine, start: Date)? {
        var best: (Routine, Date)?
        for routine in routines where routine.isEnabled && routine.window.isValid {
            for offset in 0...7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                      routine.window.weekdays.contains(calendar.component(.weekday, from: day)),
                      let start = calendar.date(byAdding: .minute, value: routine.window.startMinute, to: day),
                      start > now else { continue }
                if best.map({ start < $0.1 }) ?? true { best = (routine, start) }
                break
            }
        }
        return best.map { (routine: $0.0, start: $0.1) }
    }

    static func relative(_ date: Date, from now: Date) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 60 { return "dans \(max(1, minutes)) min" }
        if minutes < 24 * 60 { return "dans \(minutes / 60) h" }
        return "dans \(minutes / (24 * 60)) j"
    }
}
