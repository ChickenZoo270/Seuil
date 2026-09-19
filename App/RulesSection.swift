import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// Protected apps with their daily allowance, like Screen Time's app limits.
struct RulesSection: View {
    let rules: [AppRule]
    let locked: Bool
    let onPick: () -> Void
    let onLimit: (Int, ApplicationToken) -> Void
    let onUnlock: (ApplicationToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tes apps protégées").font(.headline)
                Spacer()
                Button("Choisir mes apps", action: onPick).disabled(locked)
            }
            if rules.isEmpty {
                Text("Facebook, Instagram, TikTok, jeux… Choisis les apps présentes sur ton iPhone, puis le temps que tu t’accordes chaque jour.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
            } else {
                Text("Temps libre par jour. Une fois écoulé, l’app demande un motif valable.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            }
            ForEach(rules) { rule in row(rule) }
        }
    }

    private func row(_ rule: AppRule) -> some View {
        let blocked = rule.isBlocked(now: Date())
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(rule.token)
                Spacer()
                Menu {
                    Picker("Temps par jour", selection: Binding(
                        get: { rule.dailyMinutes },
                        set: { onLimit($0, rule.token) })) {
                        ForEach(Policy.dailyLimitOptions, id: \.self) { Text(DailyLimit.label($0)).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(DailyLimit.label(rule.dailyMinutes))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }.font(.subheadline.weight(.medium))
                }
                .accessibilityLabel("Temps par jour : \(DailyLimit.label(rule.dailyMinutes))")
            }
            HStack {
                Text(status(rule, blocked: blocked)).font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                Spacer()
                if blocked {
                    Button("Débloquer") { onUnlock(rule.token) }
                        .font(.caption.weight(.semibold)).disabled(locked)
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func status(_ rule: AppRule, blocked: Bool) -> String {
        if rule.dailyMinutes == 0 { return "Bloquée · motif demandé à chaque ouverture" }
        return blocked ? "Temps du jour écoulé · bloquée jusqu’à minuit" : "Libre jusqu’à la limite"
    }
}
