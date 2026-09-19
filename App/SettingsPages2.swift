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
                HStack(alignment: .top, spacing: 12) {
                    SeuilMark().scaleEffect(0.8).frame(width: 44, height: 44)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Attention 🙌").font(.headline)
                            Spacer()
                            Text("maintenant").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                        }
                        Text(UsageAlert.message(minutes: first, appName: "Instagram").body).font(.subheadline)
                    }
                }
                .padding(16)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, -30)
                .padding(.top, 110)
            }
            SettingsCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fréquence des interventions").font(.title3)
                        Text("À quelle fréquence Autofocus intervient").foregroundStyle(SeuilTheme.secondaryInk)
                    }
                    Spacer()
                    Picker("Fréquence", selection: access.preference(\.autofocusFrequency)) {
                        ForEach(AutofocusFrequency.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .tint(SeuilTheme.secondaryInk)
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

struct EmergencyPassView: View {
    @ObservedObject var access: AccessController

    var body: some View {
        PageScaffold(title: "Pass d’urgence") {
            VStack(spacing: 16) {
                Image(systemName: "ticket.fill").font(.system(size: 70)).foregroundStyle(SeuilTheme.accentGradient)
                Text(access.isEmergencyPassAvailable ? "Disponible" : "Déjà utilisé cette semaine")
                    .font(.title2.weight(.semibold))
                Text("Une fois par semaine, débloque une app \(EmergencyPass.minutes) minutes sans défi, même en mode strict ou en Hard Mode. À garder pour les vraies urgences.")
                    .multilineTextAlignment(.center).foregroundStyle(SeuilTheme.secondaryInk)
                if let next = EmergencyPass.nextAvailable(lastUsed: access.state.preferences.emergencyPassUsedAt), !access.isEmergencyPassAvailable {
                    Text("De nouveau disponible le \(next.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.footnote).foregroundStyle(SeuilTheme.accent)
                }
                Text("Pour l’utiliser, ouvre une app bloquée puis choisis « Pass d’urgence » dans la salle d’attente.")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .glassCard(cornerRadius: 34, padding: 26)
        }
    }
}

/// Gems unlocked by the streak: Seuil's milestones, earned on this iPhone.
struct RewardsView: View {
    @ObservedObject var access: AccessController

    private let milestones: [(days: Int, name: String, hue: Double)] = [
        (1, "Gemme d’éveil", 0.45), (3, "Gemme loyale", 0.6), (7, "Gemme inspirée", 0.8),
        (14, "Gemme sereine", 0.15), (30, "Gemme lumineuse", 0.95), (100, "Gemme légendaire", 0.33),
    ]

    var body: some View {
        let streak = access.state.streak(now: Date())
        PageScaffold(title: "Récompenses") {
            VStack(spacing: 8) {
                Text("Série actuelle").foregroundStyle(SeuilTheme.secondaryInk)
                Text("\(streak) jour\(streak > 1 ? "s" : "")").font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(SeuilTheme.accentGradient)
            }
            .frame(maxWidth: .infinity)
            ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                let unlocked = streak >= milestone.days
                HStack(spacing: 18) {
                    Gem(hue: milestone.hue, unlocked: unlocked).frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(milestone.days) JOUR\(milestone.days > 1 ? "S" : "")").font(.caption.weight(.bold)).foregroundStyle(SeuilTheme.accent)
                        Text(milestone.name).font(.title3.weight(.semibold))
                        Text(unlocked ? "Débloquée" : "Encore \(milestone.days - streak) jour\(milestone.days - streak > 1 ? "s" : "")")
                            .foregroundStyle(SeuilTheme.secondaryInk)
                        ProgressView(value: min(Double(streak), Double(milestone.days)), total: Double(milestone.days))
                            .tint(SeuilTheme.accent)
                    }
                }
                .glassCard(cornerRadius: 30, padding: 14)
                if index < milestones.count - 1 {
                    Image(systemName: "arrow.down").foregroundStyle(SeuilTheme.secondaryInk).frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// Faceted gem drawn in code; greyed out until earned.
struct Gem: View {
    let hue: Double
    let unlocked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.05))
            Ellipse()
                .fill(AngularGradient(colors: [Color(hue: hue, saturation: 0.8, brightness: 0.9),
                                               Color(hue: (hue + 0.2).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 1),
                                               Color(hue: (hue + 0.45).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.8),
                                               Color(hue: hue, saturation: 0.8, brightness: 0.9)],
                                      center: .center))
                .frame(width: 58, height: 76)
                .overlay(Ellipse().fill(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .center)).frame(width: 58, height: 76))
                .shadow(color: Color(hue: hue, saturation: 0.8, brightness: 1).opacity(0.6), radius: 14)
                .saturation(unlocked ? 1 : 0)
                .opacity(unlocked ? 1 : 0.35)
            if !unlocked { Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.8)) }
        }
    }
}
