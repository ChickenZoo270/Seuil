import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// "Mes Apps" tab: blocked apps, the rule rail and the three app categories,
/// in the order the reference app uses (spec v5 §2.1 / v3 §2.2). Rule detail,
/// rule editing and "Nouvelle règle" live in RuleSheets.swift.
struct AppsView: View {
    @ObservedObject var access: AccessController
    @ObservedObject private var store = ProStore.shared
    @Environment(\.requestPro) private var requestPro
    let onUnlock: (ApplicationToken) -> Void
    @State private var showNewRule = false
    @State private var viewingRoutine: Routine?
    @State private var picking: AppList?
    @State private var unlockingAll = false
    @State private var selection = FamilyActivitySelection()

    enum AppList: String, Identifiable {
        case allowed, never, distracting
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                blockedSection
                rulesSection
                groupsSection
                if !access.message.isEmpty {
                    Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Color.clear.frame(height: 180)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showNewRule) { NewRuleSheet(access: access) }
        .sheet(item: $viewingRoutine) { routine in RuleSheetHost(access: access, routine: routine) }
        .sheet(isPresented: $unlockingAll) { unlockAllSheet }
        .familyActivityPicker(isPresented: Binding(get: { picking != nil }, set: { if !$0 { commitPicking() } }),
                              selection: $selection)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Apps").font(.system(size: 40, weight: .bold))
            Spacer()
            CircleIconButton(symbol: "plus", size: 58, prominent: true, action: addRule)
                .accessibilityIdentifier("apps.newRule")
                .accessibilityLabel("Nouvelle règle")
        }
    }

    // MARK: Apps bloquées

    private var blockedSection: some View {
        let blocked = access.blockedApplications
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Apps bloquées").font(.title3.weight(.semibold))
                Spacer()
                if !blocked.isEmpty {
                    Button("Tout débloquer") { unlockingAll = true }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(SeuilTheme.accent)
                        .accessibilityIdentifier("apps.unlockAll")
                }
            }
            blockedCard(blocked)
        }
    }

    @ViewBuilder
    private func blockedCard(_ blocked: [ApplicationToken]) -> some View {
        Group {
            if blocked.isEmpty {
                Text("Toutes les apps sont disponibles.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 18) {
                        ForEach(blocked, id: \.self) { token in blockedAppButton(token) }
                    }
                    .scrollTargetLayout()
                    .padding(16)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
    }

    private func blockedAppButton(_ token: ApplicationToken) -> some View {
        Button { onUnlock(token) } label: {
            VStack(spacing: 8) {
                Label(token).labelStyle(.iconOnly).scaleEffect(2.2)
                    .frame(width: 76, height: 76)
                    .overlay(Image(systemName: "lock.fill").font(.title2).foregroundStyle(.white).shadow(radius: 4))
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(SeuilTheme.accentGradient, lineWidth: 2))
                Text("Débloquer").font(.subheadline.weight(.medium)).foregroundStyle(SeuilTheme.accent)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Règles

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Règles").font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(SeuilTheme.secondaryInk)
            }
            if access.state.routines.isEmpty {
                Text("Aucune règle pour l'instant.").foregroundStyle(SeuilTheme.secondaryInk)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(access.state.routines) { routine in ruleCard(routine) }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func ruleCard(_ routine: Routine) -> some View {
        Button {
            if !access.isLocked(routine) { viewingRoutine = routine }
        } label: {
            RuleCard(artwork: routine.artwork, icon: "calendar",
                     caption: RuleStatus.caption(for: routine, state: access.state),
                     title: routine.name, subtitle: routine.blocksAll ? "Tout bloquer" : "Bloquer",
                     tokens: Array(routine.applications)) {
                Toggle("", isOn: Binding(get: { routine.isEnabled },
                                         set: { access.setRoutineEnabled($0, id: routine.id) }))
                    .labelsHidden().tint(SeuilTheme.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rule.card.\(routine.id)")
    }

    // MARK: Apps (categories)

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apps").font(.title3.weight(.semibold))
            // Exactly three tiles: they share the width instead of scrolling,
            // so none of them is ever cut in the middle of a word.
            HStack(alignment: .top, spacing: 12) {
                categoryButton(.allowed, title: "Toujours autorisées", tokens: access.state.allowedApplications, symbol: "checkmark.shield")
                categoryButton(.never, title: "Jamais autorisées", tokens: access.state.neverAllowed, symbol: "eye.slash", pro: true)
                categoryButton(.distracting, title: "Distrayantes", tokens: access.state.applications, symbol: "sparkles")
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryButton(_ list: AppList, title: String, tokens: Set<ApplicationToken>, symbol: String, pro: Bool = false) -> some View {
        Button {
            guard store.isPro || !pro else { requestPro(); return }
            selection = FamilyActivitySelection()
            selection.applicationTokens = tokens
            picking = list
        } label: {
            AppCategoryTile(title: title, count: tokens.count, symbol: symbol,
                             tokens: Array(tokens), showsProBadge: pro && !store.isPro)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("apps.category.\(list.rawValue)")
    }

    // MARK: Unlock everything

    private var unlockAllSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Débloquer toutes tes apps pendant 15 minutes").font(.title3.weight(.semibold))
                    Text("Un seul défi, puis tout s'ouvre. La journée compte comme non tenue.")
                        .foregroundStyle(SeuilTheme.secondaryInk)
                    ChallengeView(preferences: access.state.preferences, minutes: 15) {
                        access.openEverything(minutes: 15)
                        unlockingAll = false
                    }
                }
                .padding(20)
            }
            .background(GlowBackground())
            .navigationTitle("Tout débloquer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { unlockingAll = false } } }
        }
        .presentationBackground(.black)
    }

    // MARK: Actions

    /// The free plan allows two rules; more of them is a Pro feature.
    private func addRule() {
        if store.isPro || FreePlan.allowsRule(count: access.state.routines.count) {
            showNewRule = true
        } else {
            requestPro()
        }
    }

    private func commitPicking() {
        guard let list = picking else { return }
        picking = nil
        let tokens = selection.applicationTokens
        switch list {
        case .allowed: access.setAllowedApplications(tokens)
        case .never: access.setNeverAllowed(tokens)
        case .distracting: access.protect(selection)
        }
    }
}
