import ManagedSettings
import ManagedSettingsUI
import UIKit
import IntentionCore

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let name = application.localizedDisplayName ?? "cette app"
        let rule = application.token.flatMap { token in (try? SharedStorage.snapshot())?.rule(for: token) }
        let title: String
        let reason: String
        if let rule, rule.dailyMinutes > 0 {
            title = "Temps écoulé"
            reason = "Tes \(DailyLimit.label(rule.dailyMinutes)) sur \(name) sont utilisées."
        } else {
            title = "Pourquoi maintenant ?"
            reason = "\(name) demande une intention avant chaque ouverture."
        }
        let subtitle: String
        let button: String
        if #available(iOS 26.5, *) {
            subtitle = "\(reason) Donne un motif valable pour la débloquer."
            button = "Débloquer avec un motif"
        } else {
            subtitle = "\(reason) Ferme cet écran puis ouvre Seuil pour donner ton motif."
            button = "Fermer et ouvrir Seuil"
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: .init(text: title, color: .label),
            subtitle: .init(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: button, color: .white),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: .init(text: "Je retourne à l’essentiel", color: .secondaryLabel))
    }
}
