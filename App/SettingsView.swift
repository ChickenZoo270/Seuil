import SwiftUI
import UIKit
import IntentionCore

struct SettingsView: View {
    @ObservedObject var access: AccessController
    @State private var tryingChallenge = false
    @State private var challengeResult = ""

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
                Button("Essayer le défi") { challengeResult = ""; tryingChallenge = true }
                    .accessibilityIdentifier("settings.tryChallenge")
                if !challengeResult.isEmpty { Text(challengeResult).font(.footnote).accessibilityIdentifier("settings.challengeResult") }
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
            Section {
                Toggle("Hard Mode", isOn: Binding(get: { access.isHardModeActive },
                                                  set: { access.setHardMode($0) }))
                    .accessibilityIdentifier("settings.hardMode")
                if let offAt = access.state.preferences.hardModeOffAt, access.isHardModeActive {
                    Text("Désactivation le \(offAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
            } header: {
                Text("Engagement")
            } footer: {
                Text("En Hard Mode, aucun déblocage temporaire, aucune annulation et aucun contournement : tu ne peux que durcir tes règles. Le désactiver prend 24 heures.")
            }
            Section("Confidentialité") {
                Text("Seuil ne voit jamais le nom ni le contenu de tes apps : iOS ne lui donne que des jetons anonymes. Tout reste sur ton iPhone.")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(GlowBackground())
        .navigationTitle("Réglages")
        .sheet(isPresented: $tryingChallenge) {
            NavigationStack {
                ScrollView {
                    ChallengeView(preferences: access.state.preferences, minutes: Policy.defaultUnlockMinutes) {
                        tryingChallenge = false
                        challengeResult = "Défi réussi. C’est ce qui t’attendra avant chaque déblocage."
                    }
                    .padding(24)
                }
                .navigationTitle(access.state.preferences.challenge.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { tryingChallenge = false } } }
            }
        }
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
