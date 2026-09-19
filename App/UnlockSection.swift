import SwiftUI
import ManagedSettings
import IntentionCore

/// Shown when a blocked app is opened: asks why, and for how long.
struct UnlockSection: View {
    let application: ApplicationToken
    let dailyMinutes: Int
    @Binding var intention: String
    @Binding var minutes: Int
    let busy: Bool
    let onValidate: () -> Void
    let onCancelAnalysis: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(application).font(.headline)
                Spacer()
                Button("Plus tard", action: onDismiss).font(.subheadline).disabled(busy)
            }
            Text(dailyMinutes > 0 ? "Ton temps du jour est écoulé." : "Cette app demande un motif à chaque ouverture.")
                .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            Text("Pourquoi veux-tu la débloquer ?").font(.title2.weight(.semibold))
            Text("Par exemple : « Répondre au message de Léa pour samedi » ou « Chercher la recette du gâteau au chocolat ».")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            TextEditor(text: $intention)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100).padding(8)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35)))
                .accessibilityLabel("Ton motif")
                .disabled(busy)
            Text("Écris ou dicte avec le micro du clavier · \(intention.count)/\(Policy.maxCharacters)")
                .font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
            Picker("Durée", selection: $minutes) {
                ForEach(Policy.unlockOptions, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented).disabled(busy)
            Button(busy ? "Analyse en cours…" : "Débloquer \(minutes) min", action: onValidate)
                .foregroundStyle(SeuilTheme.onAccent)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(busy || intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || intention.count > Policy.maxCharacters)
            if busy { Button("Annuler l’analyse", action: onCancelAnalysis) }
        }
        .padding(16)
        .background(SeuilTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}
