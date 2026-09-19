import SwiftUI
import FamilyControls
import IntentionCore

/// First launch: a wake-up call on screen time, goals, the unlock challenge,
/// permissions, then the apps to lock.
struct OnboardingView: View {
    @ObservedObject var access: AccessController
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable { case welcome, hours, projection, goals, challenge, permissions, apps }
    private static let goals = ["Me concentrer au travail", "Mieux dormir", "Être présent avec mes proches",
                                "Lire et apprendre", "Faire du sport", "Arrêter de scroller par réflexe"]

    @State private var step = Step.welcome
    @State private var hours = 4.0
    @State private var age = 25
    @State private var chosenGoals: Set<String> = []
    @State private var challenge = ChallengeKind.math
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count))
                .tint(SeuilTheme.accent)
                .padding(.bottom, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollBounceBehavior(.basedOnSize)
            primaryButton
        }
        .padding(24)
        .background(SeuilTheme.paper.ignoresSafeArea())
        .foregroundStyle(SeuilTheme.ink)
        .tint(SeuilTheme.accent)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { old, new in
            if old && !new, !selection.applicationTokens.isEmpty {
                access.protect(selection)
                finish()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            SeuilMark().scaleEffect(1.6, anchor: .topLeading).frame(width: 56, height: 56, alignment: .topLeading).padding(.top, 4)
            heading("Reprends la main sur ton téléphone.")
            paragraph("Seuil verrouille les apps que tu ouvres sans cesse. Chaque déblocage se mérite, pour que tu choisisses vraiment ce que tu fais de ton temps.")
        case .hours:
            heading("Combien de temps passes-tu sur ton téléphone chaque jour ?")
            paragraph("Regarde dans Réglages › Temps d’écran si tu veux le chiffre exact.")
            Text(hoursLabel).font(.system(size: 56, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)
            Slider(value: $hours, in: 1...12, step: 0.5)
            Stepper("J’ai \(age) ans", value: $age, in: 13...79)
        case .projection:
            let years = LifeProjection.yearsOnPhone(hoursPerDay: hours, age: age)
            heading("À ce rythme, tu passeras \(LifeProjection.format(years: years)) de ta vie sur ton téléphone.")
            stat("\(LifeProjection.daysPerYear(hoursPerDay: hours)) jours", "par an, écran allumé")
            stat("\(Int((LifeProjection.awakeShare(hoursPerDay: hours) * 100).rounded())) %", "de tes heures éveillées")
            paragraph("Pas de panique : l’objectif n’est pas zéro écran, c’est d’arrêter les ouvertures par réflexe.")
        case .goals:
            let saved = LifeProjection.yearsSaved(hoursPerDay: hours, age: age)
            heading("Avec Seuil, tu peux récupérer environ \(LifeProjection.format(years: saved)).")
            paragraph("Qu’est-ce que tu veux en faire ?")
            ForEach(Self.goals, id: \.self) { goal in goalRow(goal) }
        case .challenge:
            heading("Comment veux-tu mériter tes déblocages ?")
            paragraph("Tu pourras changer ça à tout moment dans les réglages.")
            ForEach(ChallengeKind.allCases, id: \.self) { kind in challengeRow(kind) }
        case .permissions:
            heading("Deux autorisations, et c’est parti.")
            permissionRow(icon: "hourglass", title: "Temps d’écran",
                          detail: "Pour verrouiller tes apps. Seuil ne voit ni leur nom ni leur contenu.",
                          done: access.authorized)
            permissionRow(icon: "bell.badge", title: "Notifications",
                          detail: "Pour te prévenir quand tu scrolles depuis 15, 30 ou 60 min.",
                          done: access.notificationsAllowed)
        case .apps:
            heading("Quelles apps ouvres-tu sans réfléchir ?")
            paragraph("Instagram, TikTok, X, YouTube, jeux… Elles auront 30 min libres par jour, puis chaque déblocage se mérite. Tu pourras ajuster chaque app ensuite.")
        }
    }

    private var primaryButton: some View {
        VStack(spacing: 10) {
            Button(action: advance) {
                Text(buttonTitle).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .foregroundStyle(SeuilTheme.onAccent)
            .disabled(step == .goals && chosenGoals.isEmpty)
            .accessibilityIdentifier("onboarding.primary")
            if step == .apps || step == .permissions {
                Button("Plus tard", action: finish).font(.subheadline)
                    .accessibilityIdentifier("onboarding.later")
            }
        }
        .padding(.top, 12)
    }

    private var buttonTitle: String {
        switch step {
        case .welcome: return "Commencer"
        case .permissions: return access.authorized ? "Continuer" : "Autoriser"
        case .apps: return "Choisir mes apps"
        default: return "Continuer"
        }
    }

    private var hoursLabel: String {
        hours == hours.rounded() ? "\(Int(hours)) h" : "\(Int(hours)) h 30"
    }

    private func advance() {
        switch step {
        case .challenge:
            var preferences = access.state.preferences
            preferences.challenge = challenge
            access.setPreferences(preferences)
            go(to: .permissions)
        case .permissions:
            if access.authorized { go(to: .apps) } else { Task { await access.authorize() } }
        case .apps:
            selection = FamilyActivitySelection()
            selection.applicationTokens = access.state.applications
            showPicker = true
        default:
            if let next = Step(rawValue: step.rawValue + 1) { go(to: next) }
        }
    }

    private func go(to next: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func finish() { onFinish() }

    private func heading(_ text: String) -> some View {
        Text(text).font(.largeTitle.weight(.semibold)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("onboarding.heading")
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(SeuilTheme.secondaryInk).fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded))
            Text(caption).foregroundStyle(SeuilTheme.secondaryInk)
        }
    }

    private func goalRow(_ goal: String) -> some View {
        let selected = chosenGoals.contains(goal)
        return Button {
            if selected { chosenGoals.remove(goal) } else { chosenGoals.insert(goal) }
        } label: {
            HStack {
                Text(goal)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .padding(14)
            .background(selected ? SeuilTheme.accent.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func challengeRow(_ kind: ChallengeKind) -> some View {
        let selected = challenge == kind
        return Button { challenge = kind } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title).font(.headline)
                    Text(kind.summary).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
            .padding(14)
            .background(selected ? SeuilTheme.accent.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func permissionRow(icon: String, title: String, detail: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : icon).font(.title2).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
