import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// Shown when a blocked app is opened: the unlock has to be earned.
struct UnlockFlow: View {
    let application: ApplicationToken
    let state: SharedState
    let onGranted: (Int) -> Void
    let onDismiss: () -> Void
    @State private var minutes = Policy.defaultUnlockMinutes

    var body: some View {
        let now = Date()
        let rule = state.rule(for: application)
        let remaining = rule?.remainingUnlocks(now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(application).font(.headline)
                Spacer()
                Button("Plus tard", action: onDismiss).font(.subheadline)
            }
            Text(blockReason(rule: rule, now: now)).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            if state.isStrictlyBlocked(application, now: now) {
                Label("Mode strict : aucun déblocage avant la fin.", systemImage: "lock.fill").font(.headline)
            } else if remaining == 0 {
                Label("Plus aucun déblocage aujourd’hui. Rendez-vous demain.", systemImage: "moon.zzz.fill").font(.headline)
            } else {
                if let remaining {
                    Text("Déblocages restants aujourd’hui : \(remaining)").font(.caption.weight(.semibold))
                }
                Picker("Durée", selection: $minutes) {
                    ForEach(Policy.unlockOptions, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                Divider()
                challenge
                    .id("\(state.preferences.challenge.rawValue)-\(state.preferences.difficulty.rawValue)")
            }
        }
        .padding(16)
        .background(SeuilTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private var challenge: some View {
        ChallengeView(preferences: state.preferences, minutes: minutes) { onGranted(minutes) }
    }

    private func blockReason(rule: AppRule?, now: Date) -> String {
        if state.isFocusActive(now: now) { return "Session Focus en cours." }
        if let routine = state.activeRoutines.first(where: { $0.applications.contains(application) }) {
            return "Routine « \(routine.name) » en cours."
        }
        guard let rule else { return "Cette app est en pause." }
        if rule.dailyMinutes == 0 { return "Cette app se mérite à chaque ouverture." }
        return rule.isBlocked(now: now) ? "Tes \(DailyLimit.label(rule.dailyMinutes)) sont écoulées." : "Il te reste du temps libre sur cette app."
    }
}
