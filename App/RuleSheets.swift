import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

/// Rule detail/edit sheets and the "Nouvelle règle" flow, rebuilt to match the
/// reference app: a bottom sheet that swaps its header and body in place
/// (view → edit, templates → form) instead of stacking a second sheet.
/// Every primitive below (`ProBadge`, `WeekdayCircles`, `ChevronStepper`,
/// `CountStepper`, `SheetChrome`, `InfoRowsCard`/`InfoRow`, `TimeRangeCard`,
/// `RuleCard`, `CircleIconButton`, `SectionTitle`, `HoldToCommitButton`, …)
/// already lives in SeuilKit.swift/Artwork.swift/TimerView.swift and is only
/// reused here, never redefined.

// MARK: - Status text shared by rule cards and the detail sheet

/// "Commence dans 1h" / "En cours" / "Désactivée" — the same wording the root
/// screen's rule cards and the detail sheet caption both need.
enum RuleStatus {
    static func caption(for routine: Routine, state: SharedState, now: Date = Date()) -> String {
        if state.activeRoutineIDs.contains(routine.id) { return "En cours" }
        guard routine.isEnabled else { return "Désactivée" }
        if let next = RoutineSchedule.next([routine], after: now) {
            return "Commence " + RoutineSchedule.relative(next.start, from: now)
        }
        return routine.window.summary
    }
}

// MARK: - Small shared glyphs

/// The calendar → arrow → shield pill every rule card and sheet opens with.
struct RuleGlyphPill: View {
    var body: some View {
        HStack(spacing: 8) {
            glyph("calendar")
            Image(systemName: "arrow.right").font(.caption.weight(.semibold)).foregroundStyle(SeuilTheme.secondaryInk)
            glyph("shield.fill")
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func glyph(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.subheadline.weight(.semibold))
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Square tile for one app category: icon cluster above, title/count below it.
struct AppCategoryTile: View {
    let title: String
    let count: Int
    let symbol: String
    var tokens: [ApplicationToken] = []
    var showsProBadge = false

    var body: some View {
        VStack(spacing: 10) {
            content
                .frame(width: 110, height: 110)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                    if showsProBadge { ProBadge() }
                }
                Text("\(count) élément\(count > 1 ? "s" : "")").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
            }
        }
        .frame(width: 130)
    }

    @ViewBuilder private var content: some View {
        if tokens.isEmpty {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(SeuilTheme.secondaryInk)
        } else {
            LazyVGrid(columns: [GridItem(.fixed(44)), GridItem(.fixed(44))], spacing: 8) {
                ForEach(Array(tokens.prefix(3)), id: \.self) { token in
                    Label(token).labelStyle(.iconOnly).scaleEffect(1.3).frame(width: 44, height: 44)
                }
                if tokens.count > 3 {
                    Text("+\(tokens.count - 3)").font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Unsaved-changes guard

/// Floating card that intercepts a dismiss while a form is dirty, matching the
/// reference app's "Modifications non enregistrées" (spec v6 §2.2) — a custom
/// overlay, not a system alert, so it can sit inside the sheet.
struct UnsavedChangesAlert: View {
    let onDiscard: () -> Void
    let onKeepEditing: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Modifications non enregistrées").font(.headline)
                Text("Tes modifications seront perdues.")
                    .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .multilineTextAlignment(.center)
            Button("Ignorer les modifications", action: onDiscard)
                .font(.body.weight(.semibold)).foregroundStyle(Color.red)
                .accessibilityIdentifier("rule.discardChanges")
            Button("Continuer l'édition", action: onKeepEditing)
                .font(.body.weight(.medium)).foregroundStyle(SeuilTheme.ink)
                .accessibilityIdentifier("rule.keepEditing")
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 36)
    }
}

// MARK: - Schedule draft

/// Editable copy of a `Routine`. Forms stage changes here so nothing touches
/// shared state until "Maintenir pour s'engager" commits, and so dirtiness can
/// be detected by simple equality against a baseline.
struct RoutineDraft: Equatable {
    var name: String
    var artwork: String
    var startMinute: Int
    var endMinute: Int
    var weekdays: Set<Int>
    var applications: Set<ApplicationToken>
    var isStrict: Bool
    /// Neither is shown in this form (the reference UI has no "block
    /// everything"/category picker here) but both are carried through so
    /// saving never silently clears what an older editor set.
    var blocksAll: Bool
    var categories: Set<ActivityCategoryToken>

    init(_ routine: Routine) {
        name = routine.name
        artwork = routine.artwork
        startMinute = routine.window.startMinute
        endMinute = routine.window.endMinute
        weekdays = routine.window.weekdays
        applications = routine.applications
        isStrict = routine.isStrict
        blocksAll = routine.blocksAll
        categories = routine.categories
    }

    func routine(id: String, isEnabled: Bool) -> Routine {
        Routine(id: id, name: name,
                window: RoutineWindow(startMinute: startMinute, endMinute: endMinute, weekdays: weekdays),
                applications: applications, categories: categories, isStrict: isStrict, isEnabled: isEnabled,
                blocksAll: blocksAll, artwork: artwork)
    }
}

// MARK: - Rule detail / edit host for an existing routine

/// One sheet for an existing routine: read-only detail first, its edit form
/// behind "Modifier" — the reference app swaps header controls (X/Modifier ↔
/// back/pencil) in place rather than presenting a second sheet (spec v3 §2.3–2.4).
struct RuleSheetHost: View {
    @ObservedObject var access: AccessController
    let routineID: String
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .view
    @State private var draft: RoutineDraft
    @State private var baseline: RoutineDraft
    @State private var showUnsavedAlert = false

    private enum Mode: Equatable { case view, edit }

    init(access: AccessController, routine: Routine) {
        self.access = access
        routineID = routine.id
        let initial = RoutineDraft(routine)
        _draft = State(initialValue: initial)
        _baseline = State(initialValue: initial)
    }

    private var routine: Routine {
        access.state.routines.first { $0.id == routineID } ?? draft.routine(id: routineID, isEnabled: true)
    }

    private var isDirty: Bool { draft != baseline }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if mode == .view {
                    RuleDetailBody(routine: routine, state: access.state,
                                   onEdit: {
                                       baseline = RoutineDraft(routine)
                                       draft = baseline
                                       mode = .edit
                                   },
                                   onClose: { dismiss() },
                                   onPause: { access.setRoutineEnabled(false, id: routineID) })
                } else {
                    RoutineEditForm(draft: $draft, title: routine.name, isNew: false,
                                     onBack: attemptBack,
                                     onCommit: {
                                         access.saveRoutine(draft.routine(id: routineID, isEnabled: routine.isEnabled))
                                         mode = .view
                                     },
                                     onDelete: { access.deleteRoutine(id: routineID); dismiss() })
                }
            }
            if showUnsavedAlert {
                UnsavedChangesAlert(onDiscard: { draft = baseline; showUnsavedAlert = false; mode = .view },
                                     onKeepEditing: { showUnsavedAlert = false })
            }
        }
        .animation(.easeInOut(duration: 0.28), value: mode)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showUnsavedAlert)
        .interactiveDismissDisabled(mode == .edit && isDirty)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationBackground(.black)
    }

    private func attemptBack() {
        if isDirty { showUnsavedAlert = true } else { mode = .view }
    }
}

/// Read-only body of the rule detail sheet (spec v5 §2.2 / v3 §2.3).
private struct RuleDetailBody: View {
    let routine: Routine
    let state: SharedState
    let onEdit: () -> Void
    let onClose: () -> Void
    let onPause: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                SheetChrome(title: "", leading: {
                    CircleIconButton(symbol: "xmark", size: 32, action: onClose).accessibilityLabel("Fermer")
                }, trailing: {
                    Button("Modifier", action: onEdit)
                        .font(.body.weight(.medium))
                        .accessibilityIdentifier("rule.edit")
                })
                VStack(spacing: 10) {
                    RuleGlyphPill()
                    Text("Planification, " + RuleStatus.caption(for: routine, state: state))
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                    Text(routine.name).font(.title2.weight(.bold))
                }
                InfoRowsCard {
                    InfoRow(label: "Pendant cette période") {
                        Text("\(RoutineWindow.timeLabel(routine.window.startMinute)) – \(RoutineWindow.timeLabel(routine.window.endMinute))")
                    }
                    RowDivider()
                    InfoRow(label: "Ces jours-ci") { Text(WeekdayCircles.summary(routine.window.weekdays)) }
                    RowDivider()
                    InfoRow(label: "Bloquer") {
                        HStack(spacing: 8) {
                            if !routine.applications.isEmpty { AppIconRow(tokens: Array(routine.applications), size: 20) }
                            Text(routine.blocksAll ? "Tout" : "\(routine.applications.count) App\(routine.applications.count > 1 ? "s" : "")")
                        }
                    }
                    RowDivider()
                    InfoRow(label: "Mode strict") { Text(routine.isStrict ? "Oui" : "Non") }
                }
                .padding(.horizontal, 20)
                Button(action: onPause) {
                    Label("Mettre la règle en pause", systemImage: "pause.fill")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(SeuilTheme.ink)
                .accessibilityIdentifier("rule.pause")
                Color.clear.frame(height: 12)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Shared edit-form rows

/// "Ces jours-ci" card with the seven weekday circles, shared by every form.
private struct WeekdaysCard: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ces jours-ci").font(.body)
                Spacer()
                Text(WeekdayCircles.summary(weekdays)).foregroundStyle(SeuilTheme.secondaryInk)
            }
            WeekdayCircles(days: $weekdays)
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20)
    }
}

/// "Mode strict" row: PRO badge, caption and a toggle gated behind Pro.
private struct StrictModeRow: View {
    @Binding var isStrict: Bool
    let caption: String
    @ObservedObject private var store = ProStore.shared
    @Environment(\.requestPro) private var requestPro

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Mode strict").font(.body)
                ProBadge()
                Spacer()
                Toggle("", isOn: binding).labelsHidden().tint(SeuilTheme.accent)
                    .accessibilityLabel("Mode strict")
            }
            Text(caption).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var binding: Binding<Bool> {
        Binding(get: { isStrict }, set: { newValue in
            guard store.isPro || !newValue else { requestPro(); return }
            isStrict = newValue
        })
    }
}

/// "Les apps sont bloquées" / "Apps" row: stacked icons and a chevron that
/// opens the system app picker.
private struct BlockedAppsRow: View {
    let label: String
    @Binding var applications: Set<ApplicationToken>
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        Button {
            selection = FamilyActivitySelection()
            selection.applicationTokens = applications
            showPicker = true
        } label: {
            HStack {
                Text(label).font(.body)
                Spacer()
                if applications.isEmpty {
                    Text("Sélectionner").foregroundStyle(SeuilTheme.secondaryInk)
                } else {
                    AppIconRow(tokens: Array(applications), size: 26)
                }
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
            .foregroundStyle(SeuilTheme.ink)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { old, new in if old && !new { applications = selection.applicationTokens } }
        .accessibilityIdentifier("rule.pickApps")
    }
}

/// Circular back/pencil chrome shared by every edit-form header. The pencil is
/// decorative in edit mode (mirrors the detail sheet's own X/Modifier slot).
private struct EditFormHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        SheetChrome(title: title, leading: {
            CircleIconButton(symbol: "chevron.left", size: 36, action: onBack).accessibilityLabel("Retour")
        }, trailing: {
            CircleIconButton(symbol: "pencil", size: 36, action: {})
                .accessibilityHidden(true)
        })
    }
}

// MARK: - Schedule edit form ("Lève-tôt")

/// Edit form for a schedule-based rule: blocked apps, a De/À time range,
/// weekdays and strict mode, ending in the hold-to-commit gradient button
/// (spec v5 §2.4).
struct RoutineEditForm: View {
    @Binding var draft: RoutineDraft
    let title: String
    let isNew: Bool
    let onBack: () -> Void
    let onCommit: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                EditFormHeader(title: title, onBack: onBack)
                BlockedAppsRow(label: "Les apps sont bloquées", applications: $draft.applications)
                TimeRangeCard(start: $draft.startMinute, end: $draft.endMinute)
                    .padding(.horizontal, 20)
                WeekdaysCard(weekdays: $draft.weekdays)
                StrictModeRow(isStrict: $draft.isStrict, caption: "Aucun déblocage autorisé")
                HoldToCommitButton(title: "Maintenir pour s'engager", action: onCommit)
                    .padding(.horizontal, 20)
                if let onDelete, !isNew {
                    Button(action: onDelete) {
                        Label("Supprimer la règle", systemImage: "trash")
                    }
                    .foregroundStyle(Color.red)
                    .accessibilityIdentifier("rule.delete")
                }
                Color.clear.frame(height: 12)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Limit draft & edit form ("Gardien du temps" / "Vérification rapide")

/// Editable state for a duration- or openings-based limit. Neither template
/// has a dedicated persisted model in Core yet (only `Routine` and `AppRule`
/// exist), so committing applies the closest equivalent per-app setting
/// (`dailyMinutes` / `maxUnlocks`) to every selected app — see
/// `NewRuleSheet.commitLimit`.
struct LimitDraft: Equatable {
    var name: String
    var applications: Set<ApplicationToken> = []
    var weekdays: Set<Int> = RoutineWindow.allWeekdays
    var isStrict = false
    var allowedMinutes = 45
    var perOpeningMinutes = 5
    var openings = 10
}

struct LimitEditForm: View {
    enum Kind: Equatable { case duration, openings }

    @Binding var draft: LimitDraft
    let kind: Kind
    let title: String
    let isNew: Bool
    let onBack: () -> Void
    let onCommit: () -> Void

    private static let durationOptions = Array(stride(from: 30, through: 60, by: 5))
    private static let openingDurations = [5, 10, 15, 20, 30]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                EditFormHeader(title: title, onBack: onBack)
                BlockedAppsRow(label: "Apps", applications: $draft.applications)
                if kind == .duration { durationRows } else { openingsRows }
                WeekdaysCard(weekdays: $draft.weekdays)
                StrictModeRow(isStrict: $draft.isStrict, caption: "Aucune réinitialisation autorisée")
                HoldToCommitButton(title: "Maintenir pour s'engager", action: onCommit)
                    .padding(.horizontal, 20)
                Color.clear.frame(height: 12)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var durationRows: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Temps autorisé").font(.body)
                    Text("Quotidien").font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                ChevronStepper(values: Self.durationOptions, title: Self.minutesLabel, selection: $draft.allowedMinutes)
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
            RowDivider()
            HStack {
                Text("Puis bloquer jusqu'à").font(.body)
                Spacer()
                Text("Demain").font(.title3.weight(.medium)).foregroundStyle(SeuilTheme.accent)
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
        }
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var openingsRows: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ouvertures d'app").font(.body)
                    Text("Quotidien").font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                CountStepper(value: $draft.openings, range: 1...50)
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
            RowDivider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jusqu'à").font(.body)
                    Text("Par ouverture").font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                ChevronStepper(values: Self.openingDurations, title: { "\($0)min" }, selection: $draft.perOpeningMinutes)
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
        }
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 20)
    }

    private static func minutesLabel(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)min"
    }
}

// MARK: - "Nouvelle règle" template picker + push flow

/// Picker of rule templates and ready-made routines. Tapping a template or a
/// preset card swaps content in place (spec v5 §2.3 → §2.4/§2.5), matching the
/// reference app's push-within-sheet rather than opening a second sheet.
struct NewRuleSheet: View {
    @ObservedObject var access: AccessController
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .templates
    @State private var scheduleBaseline: RoutineDraft?
    @State private var limitBaseline: LimitDraft?
    @State private var showUnsavedAlert = false

    private enum Stage: Equatable {
        case templates
        case schedule(RoutineDraft)
        case limit(LimitDraft, LimitEditForm.Kind)
    }

    private struct Template: Identifiable {
        let name: String, artwork: String, start: Int, end: Int, days: Set<Int>
        var strict = false
        var id: String { name }
    }

    private static let sections: [(String, String, [Template])] = [
        ("Sois plus productif", "Avance sur l'essentiel, sans t'épuiser.", [
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
        ZStack(alignment: .top) {
            Group {
                switch stage {
                case .templates: templatePicker
                case .schedule: scheduleStage
                case .limit: limitStage
                }
            }
            if showUnsavedAlert {
                UnsavedChangesAlert(onDiscard: { stage = .templates; showUnsavedAlert = false },
                                     onKeepEditing: { showUnsavedAlert = false })
            }
        }
        .animation(.easeInOut(duration: 0.28), value: stageKey)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showUnsavedAlert)
        .background(Color.black)
        .interactiveDismissDisabled(isStageDirty)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationBackground(.black)
    }

    /// A hashable summary of `stage`, since the enum's associated drafts churn
    /// on every keystroke and would otherwise re-trigger the transition.
    private var stageKey: Int {
        switch stage {
        case .templates: return 0
        case .schedule: return 1
        case .limit(_, .duration): return 2
        case .limit(_, .openings): return 3
        }
    }

    @ViewBuilder private var scheduleStage: some View {
        if case .schedule(let current) = stage {
            RoutineEditForm(draft: scheduleBinding(current), title: current.name, isNew: true,
                             onBack: attemptBack,
                             onCommit: {
                                 access.saveRoutine(current.routine(id: UUID().uuidString, isEnabled: true))
                                 dismiss()
                             })
        }
    }

    @ViewBuilder private var limitStage: some View {
        if case .limit(let current, let kind) = stage {
            LimitEditForm(draft: limitBinding(current), kind: kind, title: current.name, isNew: true,
                           onBack: attemptBack,
                           onCommit: { commitLimit(current, kind: kind); dismiss() })
        }
    }

    private var templatePicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                SheetChrome(title: "Nouvelle règle", leading: {
                    CircleIconButton(symbol: "xmark", size: 32, action: { dismiss() })
                        .accessibilityIdentifier("sheet.close")
                        .accessibilityLabel("Fermer")
                }, trailing: { EmptyView() })
                templateRow
                ForEach(Self.sections, id: \.0) { section in presetRail(section) }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var templateRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                templateTile("timer", "Session", "ex. 30 min ou Toujours active") { dismiss() }
                templateTile("calendar", "Planification", "ex. 9h-17h, Quotidien") {
                    enterSchedule(Routine(name: "Ma routine", artwork: "default"))
                }
                templateTile("hourglass", "Limite de temps", "ex. 45 min/jour") {
                    enterLimit(LimitDraft(name: "Gardien du temps"), kind: .duration)
                }
                templateTile("lock.fill", "Limite d'ouverture", "ex. 3 déblocages/jour") {
                    enterLimit(LimitDraft(name: "Vérification rapide"), kind: .openings)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private func templateTile(_ symbol: String, _ title: String, _ example: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title).foregroundStyle(SeuilTheme.accentGradient)
                Spacer()
                Text(title).font(.title3.weight(.semibold))
                Text(example).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            }
            .padding(18)
            .frame(width: 150, height: 170, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("template.\(title)")
    }

    private func presetRail(_ section: (String, String, [Template])) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: section.0, subtitle: section.1)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(section.2) { template in
                        RuleCard(artwork: template.artwork, icon: "calendar",
                                 caption: "\(RoutineWindow.timeLabel(template.start)) – \(RoutineWindow.timeLabel(template.end))",
                                 title: template.name, subtitle: RoutineWindow.daysLabel(template.days)) {
                            CircleIconButton(symbol: "plus", size: 44, action: { enterSchedule(routine(from: template)) })
                                .accessibilityLabel("Ajouter \(template.name)")
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
    }

    private func routine(from template: Template) -> Routine {
        Routine(name: template.name,
                window: RoutineWindow(startMinute: template.start, endMinute: template.end, weekdays: template.days),
                applications: access.state.applications, isStrict: template.strict, artwork: template.artwork)
    }

    private func enterSchedule(_ routine: Routine) {
        let draft = RoutineDraft(routine)
        scheduleBaseline = draft
        stage = .schedule(draft)
    }

    private func enterLimit(_ draft: LimitDraft, kind: LimitEditForm.Kind) {
        limitBaseline = draft
        stage = .limit(draft, kind)
    }

    private func scheduleBinding(_ current: RoutineDraft) -> Binding<RoutineDraft> {
        Binding(get: {
            if case .schedule(let draft) = stage { return draft }
            return current
        }, set: { stage = .schedule($0) })
    }

    private func limitBinding(_ current: LimitDraft) -> Binding<LimitDraft> {
        Binding(get: {
            if case .limit(let draft, _) = stage { return draft }
            return current
        }, set: { newValue in
            if case .limit(_, let kind) = stage { stage = .limit(newValue, kind) }
        })
    }

    private var isStageDirty: Bool {
        switch stage {
        case .templates: return false
        case .schedule(let draft): return draft != scheduleBaseline
        case .limit(let draft, _): return draft != limitBaseline
        }
    }

    private func attemptBack() {
        if isStageDirty { showUnsavedAlert = true } else { stage = .templates }
    }

    /// Duration/openings templates have no dedicated model (see `LimitDraft`),
    /// so committing applies the closest per-app equivalent to every selected app.
    private func commitLimit(_ draft: LimitDraft, kind: LimitEditForm.Kind) {
        for token in draft.applications {
            switch kind {
            case .duration: access.setDailyLimit(draft.allowedMinutes, for: token)
            case .openings: access.setMaxUnlocks(draft.openings, for: token)
            }
        }
    }
}
