import SwiftUI
import UIKit
import IntentionCore

extension AccessController {
    /// Two-way binding to one preference, saved on every change.
    func preference<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(get: { self.state.preferences[keyPath: keyPath] },
                set: { value in self.updatePreferences { $0[keyPath: keyPath] = value } })
    }
}

struct SettingsView: View {
    @ObservedObject var access: AccessController
    @ObservedObject var store: ProStore
    @Environment(\.requestPro) private var requestPro
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profile.name") private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                proCard
                SettingsCard(title: "Compte") {
                    NavigationLink { AccountView() } label: {
                        SettingsRowLabel(icon: "person.fill", title: "Mon compte", subtitle: name.isEmpty ? nil : name)
                    }
                }
                SettingsCard(title: "Personnaliser") {
                    NavigationLink { NotificationSettingsView(access: access) } label: {
                        SettingsRowLabel(icon: "bell.fill", title: "Notifications", value: access.notificationsAllowed ? "Activé" : "Désactivé")
                    }
                    RowDivider()
                    NavigationLink { ShieldDesignView(access: access) } label: {
                        SettingsRowLabel(icon: "bolt.shield.fill", title: "Écrans de blocage",
                                         subtitle: "Personnalise ce qui s’affiche quand une app est bloquée")
                    }
                    RowDivider()
                    NavigationLink { WaitingRoomView(access: access) } label: {
                        SettingsRowLabel(icon: "hourglass", title: "Salle d’attente", subtitle: "Ce qu’il faut faire pour débloquer")
                    }
                    .accessibilityIdentifier("settings.waitingRoom")
                    RowDivider()
                    NavigationLink { AutofocusView(access: access) } label: {
                        SettingsRowLabel(icon: "sparkles", title: "Autofocus", subtitle: "Des rappels quand tu scrolles trop")
                    }
                }
                SettingsCard(title: "Apps") {
                    ForEach(AppListKind.allCases, id: \.self) { kind in
                        NavigationLink { AppListView(access: access, kind: kind) } label: {
                            SettingsRowLabel(icon: kind.symbol, title: kind.title, value: "\(kind.tokens(in: access.state).count)")
                        }
                        if kind != AppListKind.allCases.last { RowDivider() }
                    }
                }
                SettingsCard(title: "Assistance") {
                    Link(destination: URL(string: "mailto:adri1.pouch@gmail.com?subject=Seuil")!) {
                        SettingsRowLabel(icon: "envelope.fill", title: "Écrire par e-mail", trailing: "arrow.up.right")
                    }
                    RowDivider()
                    NavigationLink { SupportChatView() } label: {
                        SettingsRowLabel(icon: "bubble.left.and.bubble.right.fill", title: "Discuter avec l’assistance")
                    }
                    RowDivider()
                    NavigationLink { HelpView() } label: { SettingsRowLabel(icon: "book.fill", title: "Centre d’aide") }
                    RowDivider()
                    NavigationLink { EmergencyTicketView(access: access) } label: {
                        SettingsRowLabel(icon: "ticket.fill", title: "Pass d’urgence",
                                         value: access.isEmergencyPassAvailable ? "Disponible" : "Utilisé")
                    }
                    RowDivider()
                    Button { access.reload() } label: {
                        SettingsRowLabel(icon: "arrow.clockwise", title: "Recharger Seuil",
                                         subtitle: "Réapplique tes règles et blocages si quelque chose ne fonctionne pas.", trailing: nil)
                    }
                }
                SettingsCard(title: "Autorisations") {
                    Button { if !access.authorized { Task { await access.authorize() } } } label: {
                        SettingsRowLabel(icon: "hourglass.circle.fill", title: "Temps d’écran",
                                         subtitle: "Pour bloquer tes apps et calculer ton score",
                                         value: access.authorized ? "Autorisé" : "Autoriser", trailing: nil)
                    }
                    RowDivider()
                    Button { openSystemSettings() } label: {
                        SettingsRowLabel(icon: "bell.badge.fill", title: "Notifications",
                                         value: access.notificationsAllowed ? "Autorisées" : "Ouvrir", trailing: "arrow.up.right")
                    }
                }
                SettingsCard(title: "Partager") {
                    ShareLink(item: "Je reprends la main sur mon téléphone avec Seuil. Chaque app se mérite 🔥") {
                        SettingsRowLabel(icon: "square.and.arrow.up", title: "Partager Seuil")
                    }
                    RowDivider()
                    NavigationLink { DoorsList(access: access) } label: {
                        SettingsRowLabel(icon: "door.left.hand.open", title: "Mes portes", subtitle: "Les seuils que tu as franchis")
                    }
                }
                if !access.message.isEmpty {
                    Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk).padding(.horizontal, 8)
                }
                Text("Seuil v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""))")
                    .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CircleIconButton(symbol: "checkmark", size: 44, prominent: true) { dismiss() }
                    .accessibilityLabel("Terminé")
            }
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.isPro ? "Seuil Pro est actif" : "Tu es au plan gratuit").font(.title2.weight(.semibold))
                Text(store.isPro ? "Merci. Toutes les fonctions sont débloquées."
                                 : "Passe à Seuil Pro pour tenir vraiment tes engagements.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
            }
            ProFeatureList()
            if store.isPro {
                Toggle(isOn: Binding(get: { access.isHardModeActive }, set: { access.setHardMode($0) })) {
                    Text("Hard Mode").font(.title3.weight(.semibold))
                }
                .tint(Color(red: 0.86, green: 0.96, blue: 0.62))
                .padding(.horizontal, 22).padding(.vertical, 14)
                .background(Color.white.opacity(0.08), in: Capsule())
                .accessibilityIdentifier("settings.hardMode")
                if let offAt = access.state.preferences.hardModeOffAt, access.isHardModeActive {
                    Text("Désactivation le \(offAt.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
            } else {
                Button("Essayer Seuil Pro", action: requestPro)
                    .buttonStyle(PillButtonStyle())
                    .accessibilityIdentifier("settings.tryPro")
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(colors: [SeuilTheme.glow.opacity(0.45), Color.white.opacity(0.04)], startPoint: .topTrailing, endPoint: .bottomLeading))
        )
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
