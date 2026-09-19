import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// First launch: wake-up call, goals, essentials, how unlocking works, Hard Mode,
/// proposed rules, permissions, then the distracting apps.
struct OnboardingView: View {
    @ObservedObject var access: AccessController
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome, hours, projection, goals, essentials, unlock, hardMode, challenge, rules, permissions, apps, done
    }
    private static let goals = ["Me concentrer au travail", "Mieux dormir", "Être présent avec mes proches",
                                "Lire et apprendre", "Faire du sport", "Arrêter de scroller par réflexe"]

    struct ProposedRule: Identifiable {
        let id: String, caption: String, title: String, artwork: String, icon: String
        let window: RoutineWindow?
        let dailyMinutes: Int?
    }
    static let proposals = [
        ProposedRule(id: "work", caption: "09:00 – 17:00", title: "Travail", artwork: "work", icon: "calendar",
                     window: RoutineWindow(startMinute: 540, endMinute: 1020, weekdays: [2, 3, 4, 5, 6]), dailyMinutes: nil),
        ProposedRule(id: "weekend", caption: "09:00 – 12:00", title: "Week-end zen", artwork: "weekend", icon: "calendar",
                     window: RoutineWindow(startMinute: 540, endMinute: 720, weekdays: [1, 7]), dailyMinutes: nil),
        ProposedRule(id: "sleep", caption: "22:00 – 06:00", title: "Sommeil profond", artwork: "sleep", icon: "calendar",
                     window: RoutineWindow(startMinute: 1320, endMinute: 360, weekdays: RoutineWindow.allWeekdays), dailyMinutes: nil),
        ProposedRule(id: "limit", caption: "1 heure par jour", title: "Limite quotidienne", artwork: "limit", icon: "hourglass",
                     window: nil, dailyMinutes: 60),
    ]

    @State private var step = Step.welcome
    @State private var hours = 4.0
    @State private var age = 25
    @State private var chosenGoals: Set<String> = []
    @State private var challenge = ChallengeKind.math
    @State private var hardMode = false
    @State private var chosenRules: Set<String> = ["work", "limit"]
    @State private var picker: PickerTarget?
    @State private var selection = FamilyActivitySelection()
    @State private var unlockedPreview = false

    private enum PickerTarget { case essentials, distracting }

    var body: some View {
        ZStack {
            GlowBackground()
            VStack(spacing: 0) {
                if step != .done {
                    ProgressView(value: Double(step.rawValue + 1), total: Double(Step.allCases.count - 1))
                        .tint(SeuilTheme.accent)
                        .padding(.bottom, 20)
                }
                ScrollView {
                    VStack(spacing: 22) { content }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                buttons
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .tint(SeuilTheme.accent)
        .familyActivityPicker(isPresented: Binding(get: { picker != nil }, set: { if !$0 { pickerClosed() } }),
                              selection: $selection)
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            GlowOrb(size: 190).padding(.vertical, 30)
            heading("Reprends la main sur ton téléphone.")
            paragraph("Seuil verrouille les apps que tu ouvres sans cesse. Chaque déblocage se mérite, pour que tu choisisses vraiment ce que tu fais de ton temps.")
        case .hours:
            heading("Combien de temps passes-tu sur ton téléphone chaque jour ?")
            paragraph("Regarde dans Réglages › Temps d’écran si tu veux le chiffre exact.")
            Text(hoursLabel).font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(SeuilTheme.accentGradient)
            Slider(value: $hours, in: 1...12, step: 0.5)
            Stepper("J’ai \(age) ans", value: $age, in: 13...79).glassCard(cornerRadius: 22, padding: 14)
        case .projection:
            let years = LifeProjection.yearsOnPhone(hoursPerDay: hours, age: age)
            heading("À ce rythme, tu passeras \(LifeProjection.format(years: years)) de ta vie sur ton téléphone.")
            HStack(spacing: 12) {
                stat("\(LifeProjection.daysPerYear(hoursPerDay: hours)) j", "par an, écran allumé")
                stat("\(Int((LifeProjection.awakeShare(hoursPerDay: hours) * 100).rounded())) %", "de tes heures éveillées")
            }
            paragraph("L’objectif n’est pas zéro écran : c’est d’arrêter les ouvertures par réflexe.")
        case .goals:
            let saved = LifeProjection.yearsSaved(hoursPerDay: hours, age: age)
            heading("Avec Seuil, tu peux récupérer environ \(LifeProjection.format(years: saved)).")
            paragraph("Qu’est-ce que tu veux en faire ?")
            ForEach(Self.goals, id: \.self) { goal in
                choiceRow(goal, selected: chosenGoals.contains(goal)) {
                    if chosenGoals.contains(goal) { chosenGoals.remove(goal) } else { chosenGoals.insert(goal) }
                }
            }
        case .essentials:
            heading("Tes apps essentielles restent accessibles.")
            paragraph("Elles ne seront jamais bloquées, même pendant une session. Tu pourras en ajouter d’autres plus tard.")
            essentialsCard
        case .unlock:
            heading("Débloque des apps quand tu en as vraiment besoin.")
            paragraph("Une courte pause suffit souvent à changer d’avis.")
            unlockPreview
        case .hardMode:
            Label("ENGAGEMENT", systemImage: "bolt.fill").font(.caption.weight(.bold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(SeuilTheme.accentGradient, lineWidth: 1.5))
                .foregroundStyle(SeuilTheme.accent)
            heading("Prêt à t’engager à fond ?")
            paragraph("Avec le Hard Mode, impossible de débloquer temporairement une app, d’annuler ou de contourner tes règles. Le désactiver prend 24 heures.")
            PhoneMock {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar").font(.title)
                        Image(systemName: "arrow.right").opacity(0.5)
                        Image(systemName: "shield.fill").font(.title).foregroundStyle(SeuilTheme.accentGradient)
                    }
                    Toggle("Hard Mode", isOn: $hardMode).tint(SeuilTheme.accent).padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.08))
            }
        case .challenge:
            heading("Comment veux-tu mériter tes déblocages ?")
            paragraph("Tu pourras changer ça dans les réglages.")
            ForEach(ChallengeKind.allCases, id: \.self) { kind in
                choiceRow(kind.title, detail: kind.summary, selected: challenge == kind) { challenge = kind }
            }
        case .rules:
            heading("Voici les règles que je te propose")
            paragraph("Touche une carte pour l’ajouter ou la retirer. Tu pourras tout modifier plus tard.")
            proposalCarousel
        case .permissions:
            heading("Deux autorisations, et c’est parti.")
            permissionRow(icon: "hourglass", title: "Temps d’écran",
                          detail: "Pour verrouiller tes apps et calculer ton score. Seuil ne voit jamais leur contenu.",
                          done: access.authorized)
            permissionRow(icon: "bell.badge", title: "Notifications",
                          detail: "Pour te prévenir quand tu scrolles depuis 15, 30 ou 60 min.",
                          done: access.notificationsAllowed)
        case .apps:
            heading("Quelles apps ouvres-tu sans réfléchir ?")
            paragraph("Instagram, TikTok, X, YouTube, jeux… Elles auront 30 min libres par jour, puis chaque déblocage se mérite.")
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 90)).foregroundStyle(SeuilTheme.accentGradient).padding(30)
        case .done:
            GlowOrb(size: 200).padding(.top, 60)
            Image(systemName: "checkmark").font(.title.weight(.bold)).foregroundStyle(.black)
                .frame(width: 64, height: 64).background(SeuilTheme.accentGradient, in: Circle())
                .padding(.top, 40)
            heading("Tout est prêt.\nBienvenue dans Seuil !")
        }
    }

    private var essentialsCard: some View {
        VStack(spacing: 18) {
            Text("Toujours autorisé").font(.title3.weight(.semibold))
            if access.state.allowedApplications.isEmpty {
                HStack(spacing: -10) {
                    GlyphTile(symbol: "phone.fill", tint: .white, background: .green)
                    GlyphTile(symbol: "message.fill", tint: .white, background: .green)
                    GlyphTile(symbol: "map.fill", tint: .white, background: .blue)
                    GlyphTile(symbol: "clock.fill", tint: .black, background: .white)
                    GlyphTile(symbol: "gearshape.fill", tint: .white, background: .gray)
                }
                Text("Téléphone, Messages, Plans, Horloge, Réglages… choisis les tiennes.")
                    .foregroundStyle(SeuilTheme.secondaryInk).multilineTextAlignment(.center)
            } else {
                HStack(spacing: 6) {
                    ForEach(Array(access.state.allowedApplications.prefix(6)), id: \.self) { token in
                        Label(token).labelStyle(.iconOnly).scaleEffect(1.8).frame(width: 48, height: 48)
                    }
                }
                Text("\(access.state.allowedApplications.count) apps toujours autorisées").foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .glassCard(cornerRadius: 40, padding: 30)
        .padding(.top, 30)
    }

    private var unlockPreview: some View {
        PhoneMock {
            ZStack {
                DriftingSky()
                if unlockedPreview {
                    Image(systemName: "lock.open.fill").font(.system(size: 54)).transition(.scale.combined(with: .opacity))
                } else {
                    BreathingRing(size: 120, expanded: true)
                }
            }
        }
        .padding(.top, 20)
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                withAnimation(.spring) { unlockedPreview.toggle() }
            }
        }
    }

    private var proposalCarousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(Self.proposals) { rule in
                    let selected = chosenRules.contains(rule.id)
                    Button {
                        if selected { chosenRules.remove(rule.id) } else { chosenRules.insert(rule.id) }
                    } label: {
                        RuleCard(artwork: rule.artwork, icon: rule.icon, caption: rule.caption, title: rule.title,
                                 subtitle: "Sur tes apps distrayantes", width: 250, height: 320) {
                            Image(systemName: selected ? "checkmark" : "plus")
                                .font(.title2.weight(.semibold))
                                .frame(width: 52, height: 52)
                                .background(selected ? Color.white : Color.white.opacity(0.18), in: Circle())
                                .foregroundStyle(selected ? Color.black : Color.white)
                        }
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 40).strokeBorder(Color.white, lineWidth: selected ? 3 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rule.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: advance) { Text(buttonTitle) }
                .buttonStyle(PillButtonStyle(variant: step == .unlock ? .bright : .glass))
                .disabled(step == .goals && chosenGoals.isEmpty)
                .accessibilityIdentifier("onboarding.primary")
            switch step {
            case .essentials:
                Button("Ajouter des apps autorisées") { open(.essentials) }.font(.title3)
            case .permissions, .apps:
                Button("Plus tard", action: onFinish).font(.title3).accessibilityIdentifier("onboarding.later")
            default:
                EmptyView()
            }
        }
        .padding(.top, 12)
    }

    private var buttonTitle: String {
        switch step {
        case .welcome: return "Commencer"
        case .permissions: return access.authorized ? "Continuer" : "Autoriser"
        case .apps: return "Choisir mes apps"
        case .done: return "C’est parti"
        default: return "Continuer"
        }
    }

    private var hoursLabel: String { hours == hours.rounded() ? "\(Int(hours)) h" : "\(Int(hours)) h 30" }

    private func advance() {
        switch step {
        case .challenge:
            var preferences = access.state.preferences
            preferences.challenge = challenge
            access.setPreferences(preferences)
            go(to: .rules)
        case .permissions:
            if access.authorized { go(to: .apps) } else { Task { await access.authorize() } }
        case .apps:
            open(.distracting)
        case .done:
            onFinish()
        default:
            if let next = Step(rawValue: step.rawValue + 1) { go(to: next) }
        }
    }

    private func open(_ target: PickerTarget) {
        selection = FamilyActivitySelection()
        selection.applicationTokens = target == .essentials ? access.state.allowedApplications : access.state.applications
        picker = target
    }

    private func pickerClosed() {
        guard let target = picker else { return }
        picker = nil
        switch target {
        case .essentials:
            access.setAllowedApplications(selection.applicationTokens)
        case .distracting:
            guard !selection.applicationTokens.isEmpty else { return }
            access.protect(selection)
            applyProposals(apps: selection.applicationTokens)
            if hardMode { access.setHardMode(true) }
            go(to: .done)
        }
    }

    /// Creates the rules picked on the proposal carousel for the chosen apps.
    private func applyProposals(apps: Set<ApplicationToken>) {
        for rule in Self.proposals where chosenRules.contains(rule.id) {
            if let window = rule.window {
                access.saveRoutine(Routine(name: rule.title, window: window, applications: apps,
                                           isStrict: rule.id == "sleep", artwork: rule.artwork))
            } else if let minutes = rule.dailyMinutes {
                for token in apps { access.setDailyLimit(minutes, for: token) }
            }
        }
    }

    private func go(to next: Step) { withAnimation(.easeInOut(duration: 0.3)) { step = next } }

    // MARK: Pieces

    private func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 30, weight: .semibold)).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("onboarding.heading")
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.title3).foregroundStyle(SeuilTheme.secondaryInk).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(SeuilTheme.accentGradient)
            Text(caption).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk).multilineTextAlignment(.center)
        }
        .glassCard(cornerRadius: 26, padding: 16)
    }

    private func choiceRow(_ title: String, detail: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let detail { Text(detail).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk) }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? SeuilTheme.accent : SeuilTheme.secondaryInk)
            }
            .padding(16)
            .background(selected ? SeuilTheme.accent.opacity(0.14) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? SeuilTheme.accent.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func permissionRow(icon: String, title: String, detail: String, done: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: done ? "checkmark.circle.fill" : icon).font(.title2).frame(width: 32)
                .foregroundStyle(done ? SeuilTheme.accent : .white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .glassCard(cornerRadius: 22, padding: 16)
    }
}
