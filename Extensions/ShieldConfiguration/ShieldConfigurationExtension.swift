import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let subtitle: String
        let button: String
        if #available(iOS 26.5, *) {
            subtitle = "Une intention avant d’ouvrir \(application.localizedDisplayName ?? "cette app")."
            button = "Expliquer mon intention"
        } else {
            subtitle = "Ferme cet écran puis ouvre Seuil pour expliquer ce que tu viens faire."
            button = "Fermer et ouvrir Seuil moi-même"
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: .init(text: "Pourquoi maintenant ?", color: .label),
            subtitle: .init(text: subtitle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: button, color: .white),
            primaryButtonBackgroundColor: .systemGreen,
            secondaryButtonLabel: .init(text: "Je retourne à l’essentiel", color: .secondaryLabel))
    }
}
