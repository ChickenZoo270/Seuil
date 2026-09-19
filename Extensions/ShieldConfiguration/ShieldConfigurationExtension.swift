import ManagedSettings
import ManagedSettingsUI
import UIKit
import IntentionCore

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, token: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName, token: application.token)
    }

    private func makeConfiguration(name: String?, token: ApplicationToken?) -> ShieldConfiguration {
        let appName = name ?? "cette app"
        let state = try? SharedStorage.snapshot()
        let now = Date()
        if let token, let name { rememberName(name, for: token, known: state) }
        let rule = token.flatMap { state?.rule(for: $0) }
        let strict = token.map { state?.isStrictlyBlocked($0, now: now) ?? false } ?? false

        let title: String
        var subtitle: String
        if strict {
            title = "Mode strict"
            subtitle = state?.isFocusActive(now: now) == true
                ? "Session Focus en cours. \(appName) revient à la fin."
                : "Une routine stricte bloque \(appName) en ce moment."
        } else if let rule, rule.dailyMinutes > 0, rule.isBlocked(now: now) {
            title = "Temps écoulé"
            subtitle = "Tes \(DailyLimit.label(rule.dailyMinutes)) sur \(appName) sont utilisées."
        } else if let routine = state?.activeRoutines.first {
            title = routine.name
            subtitle = "\(appName) est en pause pendant ta routine."
        } else {
            title = "Pourquoi maintenant ?"
            subtitle = "\(appName) se mérite avant chaque ouverture."
        }
        if !strict, let remaining = rule?.remainingUnlocks(now: now) {
            subtitle += remaining == 0 ? " Plus de déblocage aujourd’hui." : " Déblocages restants : \(remaining)."
        }
        let canUnlock = !strict && rule?.remainingUnlocks(now: now) != 0
        let button: String
        if !canUnlock {
            button = "OK"
        } else if #available(iOS 26.5, *) {
            button = "Mériter un déblocage"
        } else {
            subtitle += " Ferme cet écran puis ouvre Seuil."
            button = "Fermer et ouvrir Seuil"
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: strict ? "lock.fill" : "hand.raised.fill"),
            title: .init(text: title, color: .label),
            subtitle: .init(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: button, color: .white),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: canUnlock ? .init(text: "Je retourne à l’essentiel", color: .secondaryLabel) : nil)
    }

    /// Tokens are opaque everywhere else, so keep the name for usage notifications.
    private func rememberName(_ name: String, for token: ApplicationToken, known: SharedState?) {
        guard let rule = known?.rule(for: token), rule.name != name else { return }
        try? SharedStorage.locked { state, save in
            guard let index = state.rules.firstIndex(where: { $0.token == token }) else { return }
            state.rules[index].name = name
            try save(state)
        }
    }
}
