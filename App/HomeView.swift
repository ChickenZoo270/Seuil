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
    let onSettings: () -> Void
    @State private var showDetail = false
    @State private var filter = todayFilter()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                GlowOrb(size: 170).padding(.vertical, 8)
                if access.authorized {
                    // The report is drawn out of process and swallows taps: a clear layer opens the detail.
                    DeviceActivityReport(.home, filter: filter)
                        .frame(minHeight: 760)
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
                streakCard
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) { unlockPill.padding(.bottom, 92) }
        .onAppear { filter = todayFilter() }
        .sheet(isPresented: $showDetail) { ScoreDetailSheet(filter: filter) }
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
            CircleIconButton(symbol: "person.fill", size: 46, action: onSettings)
                .accessibilityIdentifier("home.settings")
                .accessibilityLabel("Réglages")
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
                    Spacer(minLength: 0)
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

    @ViewBuilder
    private var unlockPill: some View {
        let blocked = access.blockedApplications
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
