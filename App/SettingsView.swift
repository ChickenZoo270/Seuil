import SwiftUI
import UIKit
import IntentionCore

struct SettingsView: View {
    @ObservedObject var access: AccessController

    var body: some View {
        Form {
            Section {
                Picker("Défi", selection: preference(\.challenge)) {
                    ForEach(ChallengeKind.allCases, id: \.self) { kind in
                        VStack(alignment: .leading) {
                            Text(kind.title)
                            Text(kind.summary).font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                        }.tag(kind)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Picker("Difficulté", selection: preference(\.difficulty)) {
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Mériter un déblocage")
            } footer: {
                Text("Demandé à chaque déblocage d’une app verrouillée. Plus c’est difficile, plus tu as le temps de changer d’avis.")
            }
            Section {
                Toggle("Rappels de temps passé", isOn: preference(\.usageAlerts))
                if access.state.preferences.usageAlerts && !access.notificationsAllowed {
                    Button("Autoriser les notifications") { openSystemSettings() }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Une notification à \(UsageAlert.thresholds.map { "\($0) min" }.joined(separator: ", ")) d’utilisation par jour de chaque app verrouillée.")
            }
            Section("Confidentialité") {
                Text("Seuil ne voit jamais le nom ni le contenu de tes apps : iOS ne lui donne que des jetons anonymes. Tout reste sur ton iPhone.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Réglages")
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(
            get: { access.state.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = access.state.preferences
                preferences[keyPath: keyPath] = value
                access.setPreferences(preferences)
            })
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
