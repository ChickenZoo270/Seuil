import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

enum AppListKind: CaseIterable {
    case distracting, allowed, never

    var title: String {
        switch self {
        case .distracting: return "Distrayantes"
        case .allowed: return "Toujours autorisées"
        case .never: return "Jamais autorisées"
        }
    }

    var symbol: String {
        switch self {
        case .distracting: return "sparkles"
        case .allowed: return "checkmark.shield.fill"
        case .never: return "eye.slash.fill"
        }
    }

    var explanation: String {
        switch self {
        case .distracting: return "Ces apps ont un temps libre chaque jour, puis chaque ouverture se mérite. Autofocus te prévient quand tu y passes trop de temps."
        case .allowed: return "Ces apps ne sont jamais bloquées, même pendant une session ou une routine qui bloque tout."
        case .never: return "Ces apps restent bloquées en permanence, et aucun défi ne peut les ouvrir."
        }
    }

    func tokens(in state: SharedState) -> Set<ApplicationToken> {
        switch self {
        case .distracting: return state.applications
        case .allowed: return state.allowedApplications
        case .never: return state.neverAllowed
        }
    }
}

struct AppListView: View {
    @ObservedObject var access: AccessController
    @Environment(\.requestPro) private var requestPro
    // See ShieldDesignView in SettingsPages.swift for why this is a private
    // @StateObject rather than @EnvironmentObject: it removes any chance of a
    // hard crash if this page is ever reached without an ancestor
    // .environmentObject(ProStore), since Pro status is re-derived from
    // UserDefaults/StoreKit regardless of which ProStore instance reads it.
    @ObservedObject private var store = ProStore.shared
    let kind: AppListKind
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        let tokens = Array(kind.tokens(in: access.state))
        PageScaffold(title: kind.title) {
            HStack(spacing: 18) {
                PreviewPhone {
                    Image(systemName: kind.symbol).font(.system(size: 50)).foregroundStyle(SeuilTheme.accentGradient).padding(.top, 90)
                }
                .frame(width: 120)
                .scaleEffect(0.5)
                Text(kind.explanation).font(.body)
            }
            .padding(20)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(SeuilTheme.accentGradient, lineWidth: 2).shadow(color: SeuilTheme.accent, radius: 8))
            if tokens.isEmpty {
                Text("Aucune app pour l’instant. Touche + pour en ajouter.").foregroundStyle(SeuilTheme.secondaryInk)
            }
            VStack(spacing: 0) {
                ForEach(tokens, id: \.self) { token in
                    HStack(spacing: 16) {
                        Label(token).labelStyle(.titleAndIcon).font(.title3)
                        Spacer()
                        CircleIconButton(symbol: "xmark", size: 44) { remove(token) }
                            .accessibilityLabel("Retirer")
                    }
                    .padding(.vertical, 10)
                    if token != tokens.last { RowDivider() }
                }
            }
            if !access.message.isEmpty { Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CircleIconButton(symbol: "plus", size: 44) {
                    guard store.isPro || kind != .never else { requestPro(); return }
                    selection = FamilyActivitySelection()
                    selection.applicationTokens = kind.tokens(in: access.state)
                    showPicker = true
                }
                .accessibilityLabel("Ajouter")
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { old, new in if old && !new { apply(selection.applicationTokens) } }
    }

    private func remove(_ token: ApplicationToken) {
        var tokens = kind.tokens(in: access.state)
        tokens.remove(token)
        apply(tokens)
    }

    private func apply(_ tokens: Set<ApplicationToken>) {
        switch kind {
        case .distracting:
            var picked = FamilyActivitySelection()
            picked.applicationTokens = tokens
            access.protect(picked)
        case .allowed: access.setAllowedApplications(tokens)
        case .never: access.setNeverAllowed(tokens)
        }
    }
}

struct AutofocusView: View {
    @ObservedObject var access: AccessController

    var body: some View {
        let first = access.state.preferences.autofocusFrequency.thresholds.first ?? 15
        PageScaffold(title: "Autofocus") {
            PreviewPhone {
                // `.frame(width: 280)` matches PreviewPhone's own screen width so the
                // toast can never grow wider than the phone outline that contains it.
                HStack(alignment: .top, spacing: 12) {
                    SeuilMark().scaleEffect(0.8).frame(width: 44, height: 44)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Attention 🙌").font(.headline).lineLimit(1)
                            Spacer(minLength: 8)
                            Text("maintenant").font(.caption).foregroundStyle(SeuilTheme.secondaryInk).lineLimit(1)
                        }
                        Text(UsageAlert.message(minutes: first, appName: "Instagram").body)
                            .font(.subheadline)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(width: 280 - 28)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, 14)
                .padding(.top, 110)
            }
            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fréquence des interventions").font(.title3)
                            .lineLimit(2).minimumScaleFactor(0.85)
                        Text("À quelle fréquence Autofocus intervient").foregroundStyle(SeuilTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    ChevronStepper(values: AutofocusFrequency.allCases, title: { $0.title },
                                   selection: access.preference(\.autofocusFrequency))
                }
                .padding(20)
            }
            SettingsCard(title: "Types d’interventions") {
                SettingsToggleRow(icon: "bell.fill", title: "Notifications", subtitle: "Pings quand tu scrolles trop",
                                  isOn: access.preference(\.usageAlerts))
            }
            Text("Rappels à \(access.state.preferences.autofocusFrequency.thresholds.map { "\($0) min" }.joined(separator: ", ")) d’utilisation de chaque app distrayante, une fois par jour.")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            SettingsCard(title: "Apps") {
                NavigationLink { AppListView(access: access, kind: .distracting) } label: {
                    SettingsRowLabel(icon: "sparkles", title: "Distrayantes", subtitle: "\(access.state.applications.count) apps")
                }
                .buttonStyle(.plain)
                RowDivider()
                NavigationLink { AppListView(access: access, kind: .allowed) } label: {
                    SettingsRowLabel(icon: "checkmark.shield.fill", title: "Toujours autorisées", subtitle: "\(access.state.allowedApplications.count) apps")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HelpView: View {
    private let entries = [
        ("Pourquoi une app n’est pas bloquée ?", "Vérifie qu’elle est dans tes apps distrayantes et que son temps libre du jour est écoulé. Sinon, ouvre Paramètres › Recharger Seuil."),
        ("Comment débloquer une app ?", "Touche « Mériter un déblocage » sur l’écran de blocage : Seuil s’ouvre sur la salle d’attente. Réussis le défi, choisis la durée, puis retourne dans l’app."),
        ("Qu’est-ce que le Hard Mode ?", "Aucun déblocage, aucune annulation, et tu ne peux que durcir tes règles. Le désactiver prend 24 heures pour éviter les coups de tête."),
        ("Et en cas d’urgence ?", "Le pass d’urgence débloque une app 15 minutes, même en mode strict ou en Hard Mode. Il se recharge une fois par semaine."),
        ("Comment est calculé mon score ?", "Focus (distractions, prises en main, déblocages), Repos (pauses loin de l’écran, temps total) et Sommeil (écran entre minuit et 6 h). Tout est calculé sur ton iPhone."),
        ("Mes données quittent-elles l’iPhone ?", "Non. Apple ne donne à Seuil que des jetons anonymes, et rien n’est envoyé sur un serveur."),
    ]

    var body: some View {
        PageScaffold(title: "Centre d’aide") {
            ForEach(entries, id: \.0) { entry in
                DisclosureGroup {
                    Text(entry.1).foregroundStyle(SeuilTheme.secondaryInk).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                } label: {
                    Text(entry.0).font(.title3).multilineTextAlignment(.leading)
                }
                .tint(.white)
                .glassCard(cornerRadius: 24, padding: 18)
            }
        }
    }
}
