import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

struct AppsView: View {
    @ObservedObject var access: AccessController
    @EnvironmentObject private var store: ProStore
    @Environment(\.requestPro) private var requestPro
    let onUnlock: (ApplicationToken) -> Void
    @State private var showNewRule = false
    @State private var editing: Routine?
    @State private var showLimits = false
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
                HStack {
                    Text("Apps").font(.system(size: 40, weight: .bold))
                    Spacer()
                    CircleIconButton(symbol: "plus", size: 58, prominent: true) { addRule() }
                        .accessibilityIdentifier("apps.newRule")
                        .accessibilityLabel("Nouvelle règle")
                }
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
        .sheet(isPresented: $showNewRule) {
            NewRuleSheet(access: access, onRoutine: { routine in
                showNewRule = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editing = routine }
            }, onLimits: {
                showNewRule = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showLimits = true }
            })
        }
        .sheet(item: $editing) { routine in
            NavigationStack {
                RoutineEditor(routine: routine,
                              isNew: !access.state.routines.contains { $0.id == routine.id },
                              onSave: { access.saveRoutine($0) },
                              onDelete: { access.deleteRoutine(id: routine.id) })
            }
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showLimits) { LimitsSheet(access: access) }
        .sheet(isPresented: $unlockingAll) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Débloquer toutes tes apps pendant 15 minutes").font(.title3.weight(.semibold))
                        Text("Un seul défi, puis tout s’ouvre. La journée compte comme non tenue.")
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
        .familyActivityPicker(isPresented: Binding(get: { picking != nil }, set: { if !$0 { commitPicking() } }),
                              selection: $selection)
    }

    // MARK: Sections

    @ViewBuilder
    private var blockedSection: some View {
        let blocked = access.blockedApplications
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Apps bloquées").font(.title3.weight(.semibold))
                Spacer()
                if !blocked.isEmpty {
                    Button("Tout débloquer") { unlockingAll = true }
                        .font(.headline).foregroundStyle(SeuilTheme.accent)
                        .accessibilityIdentifier("apps.unlockAll")
                }
            }
            if blocked.isEmpty {
                Text("Toutes les apps sont disponibles.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 18) {
                        ForEach(blocked, id: \.self) { token in
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
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Règles").font(.title3.weight(.semibold))
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(access.state.routines) { routine in
                        Button { if !access.isLocked(routine) { editing = routine } } label: {
                            RuleCard(artwork: routine.artwork, icon: "calendar", caption: caption(for: routine),
                                     title: routine.name, subtitle: routine.blocksAll ? "Tout bloquer" : "Bloquer",
                                     tokens: Array(routine.applications)) {
                                Toggle("", isOn: Binding(get: { routine.isEnabled },
                                                         set: { access.setRoutineEnabled($0, id: routine.id) }))
                                    .labelsHidden().tint(SeuilTheme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button { showLimits = true } label: {
                        RuleCard(artwork: "limit", icon: "hourglass", caption: "\(access.state.rules.count) apps",
                                 title: "Limites de temps", subtitle: "Chaque jour",
                                 tokens: Array(access.state.applications)) { EmptyView() }
                    }
                    .buttonStyle(.plain)
                    Button { addRule() } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus").font(.largeTitle)
                            Text("Nouvelle règle").font(.headline)
                        }
                        .frame(width: 160, height: 250)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 34))
                        .overlay(RoundedRectangle(cornerRadius: 34).strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apps").font(.title3.weight(.semibold))
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    groupTile(.allowed, title: "Toujours autorisées", tokens: access.state.allowedApplications, emptySymbol: "checkmark.shield")
                    groupTile(.never, title: "Jamais autorisées", tokens: access.state.neverAllowed, emptySymbol: "eye.slash", pro: true)
                    groupTile(.distracting, title: "Distrayantes", tokens: access.state.applications, emptySymbol: "sparkles")
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func groupTile(_ list: AppList, title: String, tokens: Set<ApplicationToken>, emptySymbol: String, pro: Bool = false) -> some View {
        Button {
            guard store.isPro || !pro else { requestPro(); return }
            selection = FamilyActivitySelection()
            selection.applicationTokens = tokens
            picking = list
        } label: {
            VStack(spacing: 12) {
                Group {
                    if tokens.isEmpty {
                        Image(systemName: emptySymbol).font(.system(size: 40)).foregroundStyle(SeuilTheme.secondaryInk)
                    } else {
                        LazyVGrid(columns: [GridItem(.fixed(52)), GridItem(.fixed(52))], spacing: 10) {
                            ForEach(Array(tokens.prefix(3)), id: \.self) { token in
                                Label(token).labelStyle(.iconOnly).scaleEffect(1.5).frame(width: 52, height: 52)
                            }
                            if tokens.count > 3 {
                                Text("+\(tokens.count - 3)").font(.title3.weight(.semibold)).frame(width: 52, height: 52)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
                .frame(width: 150, height: 150)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 34))
                VStack(spacing: 6) {
                    Text(title).font(.headline).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if pro, !store.isPro { ProBadge() }
                }
                Text("\(tokens.count) élément\(tokens.count > 1 ? "s" : "")").font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
    }

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

    private func caption(for routine: Routine) -> String {
        if access.state.activeRoutineIDs.contains(routine.id) { return "En cours" }
        guard routine.isEnabled else { return "Désactivée" }
        if let next = RoutineSchedule.next([routine], after: Date()) {
            return "Commence " + RoutineSchedule.relative(next.start, from: Date())
        }
        return routine.window.summary
    }

    private func blockLabel(_ routine: Routine) -> String {
        if routine.blocksAll { return "Bloquer tout" }
        let count = routine.applications.count + routine.categories.count
        return "Bloquer \(count) élément\(count > 1 ? "s" : "")"
    }
}

/// Picker of rule types and ready-made routines, like Screen Time presets.
struct NewRuleSheet: View {
    @ObservedObject var access: AccessController
    let onRoutine: (Routine) -> Void
    let onLimits: () -> Void
    @Environment(\.dismiss) private var dismiss

    private struct Template: Identifiable {
        let name: String, artwork: String, start: Int, end: Int, days: Set<Int>
        var strict = false
        var id: String { name }
    }

    private static let sections: [(String, String, [Template])] = [
        ("Sois plus productif", "Avance sur l’essentiel, sans t’épuiser.", [
            Template(name: "Travail", artwork: "work", start: 9 * 60, end: 17 * 60, days: [2, 3, 4, 5, 6]),
            Template(name: "Focus laser", artwork: "laser", start: 14 * 60, end: 15 * 60, days: [2, 3, 4, 5, 6]),
        ]),
        ("Dormir, décompresser, repartir", "Dors mieux et réveille-toi frais.", [
            Template(name: "Décompression", artwork: "unwind", start: 20 * 60, end: 22 * 60, days: RoutineWindow.allWeekdays),
            Template(name: "Sommeil profond", artwork: "sleep", start: 22 * 60, end: 6 * 60, days: RoutineWindow.allWeekdays, strict: true),
        ]),
        ("Des habitudes saines", "Du temps pour ce qui compte vraiment.", [
            Template(name: "Lecture", artwork: "read", start: 18 * 60, end: 18 * 60 + 45, days: RoutineWindow.allWeekdays),
            Template(name: "Sport", artwork: "sport", start: 17 * 60 + 30, end: 18 * 60 + 30, days: [2, 4, 6]),
            Template(name: "Week-end zen", artwork: "weekend", start: 9 * 60, end: 12 * 60, days: [1, 7]),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            typeCard("timer", "Session", "ex. 30 min, tout de suite") { dismiss() }
                            typeCard("calendar", "Planification", "ex. 9h–17h, en semaine") {
                                onRoutine(Routine(name: "Ma routine", artwork: "default"))
                            }
                            typeCard("hourglass", "Limite de temps", "ex. 45 min / jour", action: onLimits)
                            typeCard("lock.fill", "Limite d’ouverture", "ex. 3 déblocages / jour", action: onLimits)
                        }
                    }
                    .scrollIndicators(.hidden)
                    ForEach(Self.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(title: section.0, subtitle: section.1)
                            ScrollView(.horizontal) {
                                HStack(spacing: 14) {
                                    ForEach(section.2) { template in
                                        RuleCard(artwork: template.artwork, icon: "calendar",
                                                 caption: "\(RoutineWindow.timeLabel(template.start)) – \(RoutineWindow.timeLabel(template.end))",
                                                 title: template.name, subtitle: RoutineWindow.daysLabel(template.days)) {
                                            CircleIconButton(symbol: "plus", size: 48) { onRoutine(routine(from: template)) }
                                                .accessibilityLabel("Ajouter \(template.name)")
                                        }
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.black)
            .navigationTitle("Nouvelle règle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityIdentifier("sheet.close")
                        .accessibilityLabel("Fermer")
                }
            }
        }
        .presentationBackground(.black)
    }

    private func routine(from template: Template) -> Routine {
        Routine(name: template.name,
                window: RoutineWindow(startMinute: template.start, endMinute: template.end, weekdays: template.days),
                applications: access.state.applications, isStrict: template.strict, artwork: template.artwork)
    }

    private func typeCard(_ symbol: String, _ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title).foregroundStyle(SeuilTheme.accentGradient)
                Spacer()
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .padding(18)
            .frame(width: 170, height: 170, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

/// Per-app daily allowance and unlock cap.
struct LimitsSheet: View {
    @ObservedObject var access: AccessController
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            ScrollView {
                RulesSection(
                    rules: access.state.rules,
                    locked: access.state.session != nil,
                    onPick: {
                        selection = FamilyActivitySelection()
                        selection.applicationTokens = access.state.applications
                        showPicker = true
                    },
                    onLimit: { access.setDailyLimit($0, for: $1) },
                    onQuota: { access.setMaxUnlocks($0, for: $1) },
                    onUnlock: { _ in dismiss() })
                .padding(20)
                if !access.message.isEmpty {
                    Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk).padding(.horizontal, 20)
                }
            }
            .background(Color.black)
            .navigationTitle("Limites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            .onChange(of: showPicker) { old, new in if old && !new { access.protect(selection) } }
        }
        .presentationBackground(.black)
    }
}
