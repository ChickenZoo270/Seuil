import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// Protected apps with their daily allowance and unlock cap.
struct RulesSection: View {
    let rules: [AppRule]
    let locked: Bool
    let onPick: () -> Void
    let onLimit: (Int, ApplicationToken) -> Void
    let onQuota: (Int, ApplicationToken) -> Void
    let onUnlock: (ApplicationToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Apps verrouillées").font(.headline)
                Spacer()
                Button("Choisir", action: onPick).disabled(locked)
            }
            if rules.isEmpty {
                Text("Instagram, TikTok, X, jeux… Choisis les apps que tu ouvres sans cesse, puis le temps que tu t’accordes chaque jour.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
            } else {
                Text("Temps libre par jour, puis chaque déblocage se mérite.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            }
            ForEach(rules) { rule in row(rule) }
        }
    }

    private func row(_ rule: AppRule) -> some View {
        let now = Date()
        let blocked = rule.isBlocked(now: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(rule.token)
                Spacer()
                if blocked {
                    Button("Débloquer") { onUnlock(rule.token) }
                        .font(.caption.weight(.semibold)).buttonStyle(.bordered).disabled(locked)
                }
            }
            HStack(spacing: 12) {
                Menu {
                    Picker("Temps par jour", selection: Binding(get: { rule.dailyMinutes }, set: { onLimit($0, rule.token) })) {
                        ForEach(Policy.dailyLimitOptions, id: \.self) { Text(DailyLimit.label($0)).tag($0) }
                    }
                } label: { chip(DailyLimit.label(rule.dailyMinutes), icon: "hourglass") }
                Menu {
                    Picker("Déblocages", selection: Binding(get: { rule.maxUnlocks }, set: { onQuota($0, rule.token) })) {
                        ForEach(UnlockQuota.options, id: \.self) { Text(UnlockQuota.label($0)).tag($0) }
                    }
                } label: { chip(UnlockQuota.label(rule.maxUnlocks), icon: "key") }
            }
            Text(status(rule, blocked: blocked, now: now)).font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(SeuilTheme.accent.opacity(0.12), in: Capsule())
    }

    private func status(_ rule: AppRule, blocked: Bool, now: Date) -> String {
        let unlocks = rule.unlocksToday(now: now)
        let suffix = unlocks > 0 ? " · \(unlocks) déblocage\(unlocks > 1 ? "s" : "") aujourd’hui" : ""
        if rule.dailyMinutes == 0 { return "Verrouillée à chaque ouverture" + suffix }
        return (blocked ? "Temps du jour écoulé, verrouillée jusqu’à minuit" : "Libre jusqu’à la limite") + suffix
    }
}
