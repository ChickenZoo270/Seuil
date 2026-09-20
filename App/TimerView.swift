import SwiftUI
import UIKit
import FamilyControls
import IntentionCore

struct TimerView: View {
    @ObservedObject var access: AccessController
    @State private var minutes = 30
    @State private var committing: TimerPreset?
    @State private var showAllowed = false
    @State private var selection = FamilyActivitySelection()
    @StateObject private var ambience = AmbientPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Minuteur").font(.system(size: 40, weight: .bold))
                display
                if !isRunning {
                    VStack(spacing: 14) {
                        durationStepper
                        startButton
                        blockedAppsPill
                    }
                    AmbienceRow(player: ambience)
                }
                recentSection
                TimerRailSection(title: "Pour toi", items: TimerRailItem.forYou, isEnabled: !isRunning) { committing = $0.asPreset }
                TimerRailSection(title: "Détox numérique", subtitle: "Une pause plus longue.", items: TimerRailItem.detox, isEnabled: !isRunning) { committing = $0.asPreset }
                TimerRailSection(title: "Histoires pour s’endormir", subtitle: "Détends-toi et endors-toi.", items: TimerRailItem.sleepStories, isEnabled: !isRunning) { committing = $0.asPreset }
                TimerRailSection(title: "Méditations", subtitle: "De courtes méditations guidées.", items: TimerRailItem.meditations, cardHeight: 220, isEnabled: !isRunning) { committing = $0.asPreset }
                if !access.message.isEmpty {
                    Text(access.message).font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Color.clear.frame(height: 180)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $committing) { preset in
            CommitSheet(access: access, preset: preset).presentationBackground(.black)
        }
        .fullScreenCover(isPresented: runningBinding) { TimerRunningView(access: access) }
        .familyActivityPicker(isPresented: $showAllowed, selection: $selection)
        .onChange(of: showAllowed) { old, new in
            if old && !new { access.setAllowedApplications(selection.applicationTokens) }
        }
    }

    private var isRunning: Bool { access.state.isFocusActive(now: Date()) }

    /// The cover presents itself whenever a focus session is active and dismisses on its own
    /// once `access.state.focus` is cleared (naturally, or via the "Partir tôt ?" hold).
    private var runningBinding: Binding<Bool> {
        Binding(get: { isRunning }, set: { _ in })
    }

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds: Int = {
                if let focus = access.state.focus, focus.endsAt > timeline.date {
                    return Int(focus.endsAt.timeIntervalSince(timeline.date).rounded(.up))
                }
                return minutes * 60
            }()
            LCDClock(seconds: seconds)
        }
    }

    /// One grouped capsule: circular "−" at the left end, the duration label centred, "+" at the right end.
    private var durationStepper: some View {
        ZStack {
            Capsule().fill(Color.white.opacity(0.06))
            Text(Scoring.duration(Double(minutes)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            HStack {
                CircleIconButton(symbol: "minus", size: 48) { minutes = max(5, minutes - step(for: minutes - 1)) }
                    .accessibilityLabel("Moins")
                Spacer()
                CircleIconButton(symbol: "plus", size: 48) { minutes = min(24 * 60, minutes + step(for: minutes)) }
                    .accessibilityLabel("Plus")
            }
            .padding(6)
        }
        .frame(height: 60)
        .accessibilityIdentifier("timer.duration")
    }

    private var startButton: some View {
        Button {
            committing = TimerPreset(name: "Minuteur", minutes: minutes, artwork: "default")
        } label: {
            GradientPillLabel(title: "Démarrer", symbol: "play.fill")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timer.start")
    }

    private var blockedAppsPill: some View {
        Button { openAllowedPicker() } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill").foregroundStyle(SeuilTheme.accent)
                Text(access.state.allowedApplications.isEmpty ? "Apps bloquées" : "Tout sauf \(access.state.allowedApplications.count) apps autorisées")
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("timer.blockedApps")
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            RailHeader(title: "Récents")
            TimerRailCard(item: .recent, width: nil, height: 180) { committing = TimerRailItem.recent.asPreset }
                .disabled(isRunning)
        }
    }

    /// Fine steps for short sessions, coarser ones for long detoxes.
    private func step(for minutes: Int) -> Int {
        switch minutes {
        case ..<60: return 5
        case ..<180: return 15
        default: return 60
        }
    }

    private func openAllowedPicker() {
        selection = FamilyActivitySelection()
        selection.applicationTokens = access.state.allowedApplications
        showAllowed = true
    }
}

struct TimerPreset: Identifiable {
    let name: String
    let minutes: Int
    let artwork: String
    var subtitle: String? = nil
    var id: String { "\(name)-\(minutes)" }
}

/// Retro LCD countdown drawn with seven-segment digits.
struct LCDClock: View {
    let seconds: Int

    var body: some View {
        let hours = seconds / 3600
        let text = hours > 0
            ? String(format: "%d:%02d", hours, (seconds % 3600) / 60)
            : String(format: "%02d:%02d", seconds / 60, seconds % 60)
        HStack(spacing: 10) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                if character == ":" {
                    VStack(spacing: 22) {
                        Rectangle().frame(width: 9, height: 9)
                        Rectangle().frame(width: 9, height: 9)
                    }
                } else {
                    SevenSegmentDigit(digit: Int(String(character)) ?? 0)
                        .frame(width: 46, height: 82)
                }
            }
        }
        .foregroundStyle(Color(red: 0.08, green: 0.1, blue: 0.08))
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.62, green: 0.7, blue: 0.62), Color(red: 0.45, green: 0.52, blue: 0.46)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        )
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Color(white: 0.07)))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 2))
        .shadow(color: SeuilTheme.glow.opacity(0.5), radius: 30)
        .accessibilityElement()
        .accessibilityLabel("Minuteur \(text)")
    }
}

struct SevenSegmentDigit: View {
    let digit: Int
    // Segments: a (top), b (top right), c (bottom right), d (bottom), e (bottom left), f (top left), g (middle).
    private static let map: [Int: Set<Character>] = [
        0: ["a", "b", "c", "d", "e", "f"], 1: ["b", "c"], 2: ["a", "b", "g", "e", "d"], 3: ["a", "b", "g", "c", "d"],
        4: ["f", "g", "b", "c"], 5: ["a", "f", "g", "c", "d"], 6: ["a", "f", "g", "e", "c", "d"], 7: ["a", "b", "c"],
        8: ["a", "b", "c", "d", "e", "f", "g"], 9: ["a", "b", "c", "d", "f", "g"],
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, t = w * 0.18
            let on = Self.map[digit] ?? []
            ZStack(alignment: .topLeading) {
                segment("a", on, x: t * 0.6, y: 0, width: w - t * 1.2, height: t)
                segment("d", on, x: t * 0.6, y: h - t, width: w - t * 1.2, height: t)
                segment("g", on, x: t * 0.6, y: (h - t) / 2, width: w - t * 1.2, height: t)
                segment("f", on, x: 0, y: t * 0.6, width: t, height: h / 2 - t * 0.9)
                segment("b", on, x: w - t, y: t * 0.6, width: t, height: h / 2 - t * 0.9)
                segment("e", on, x: 0, y: h / 2 + t * 0.3, width: t, height: h / 2 - t * 0.9)
                segment("c", on, x: w - t, y: h / 2 + t * 0.3, width: t, height: h / 2 - t * 0.9)
            }
        }
    }

    private func segment(_ name: Character, _ on: Set<Character>, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: min(width, height) / 3)
            .frame(width: width, height: height)
            .opacity(on.contains(name) ? 1 : 0.07)
            .offset(x: x, y: y)
    }
}

/// Confirms a timer session: which apps, how long, strict or not, then hold to commit.
struct CommitSheet: View {
    @ObservedObject var access: AccessController
    @ObservedObject private var store = ProStore.shared
    @Environment(\.requestPro) private var requestPro
    let preset: TimerPreset
    @State private var minutes: Int
    @State private var strict = false
    @Environment(\.dismiss) private var dismiss

    init(access: AccessController, preset: TimerPreset) {
        self.access = access
        self.preset = preset
        _minutes = State(initialValue: preset.minutes)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                CircleIconButton(symbol: "xmark", size: 46) { dismiss() }
                    .accessibilityIdentifier("sheet.close")
                    .accessibilityLabel("Fermer")
                Spacer()
                Text(preset.name).font(.title2.weight(.semibold))
                Spacer()
                Color.clear.frame(width: 46, height: 46)
            }
            row {
                Text("Les apps sont bloquées")
                Spacer()
                Text(access.state.allowedApplications.isEmpty ? "Toutes" : "Sauf \(access.state.allowedApplications.count) autorisées")
                    .foregroundStyle(SeuilTheme.secondaryInk)
            }
            row {
                Text("Pendant")
                Spacer()
                Stepper(Scoring.duration(Double(minutes)), value: $minutes, in: FocusMonitoring.range, step: minutes < 60 ? 5 : 15)
                    .fixedSize()
                    .foregroundStyle(SeuilTheme.secondaryInk)
            }
            row {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Mode strict")
                        if !store.isPro { ProBadge() }
                    }
                    Text("Aucun déblocage autorisé").font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                }
                Spacer()
                Toggle("Mode strict", isOn: Binding(
                    get: { access.isHardModeActive || strict },
                    set: { value in
                        guard store.isPro else { requestPro(); return }
                        strict = value
                    }))
                    .labelsHidden().tint(SeuilTheme.accent)
                    .disabled(access.isHardModeActive)
            }
            .padding(.top, 8)
            Spacer(minLength: 8)
            HoldToCommitButton(title: "Maintenir pour s’engager") {
                access.startFocus(minutes: minutes, name: preset.name, strict: strict)
                dismiss()
            }
        }
        .font(.title3)
        .padding(20)
        .presentationDetents([.medium])
        .presentationBackground(.black)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack { content() }
            .padding(.horizontal, 22).frame(minHeight: 64)
            .background(Color.white.opacity(0.07), in: Capsule())
    }
}

/// Filling pill: the action only fires after a deliberate long press.
struct HoldToCommitButton: View {
    let title: String
    let action: () -> Void
    @State private var progress: CGFloat = 0
    @GestureState private var pressing = false
    private let duration = 1.2

    var body: some View {
        Text(title)
            .font(.title3.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(alignment: .leading) {
                GeometryReader { geo in
                    Capsule().fill(SeuilTheme.accentGradient.opacity(0.45)).frame(width: geo.size.width * progress)
                }
            }
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(alignment: .bottom) {
                Capsule().fill(LinearGradient(colors: Aurora.colors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3).blur(radius: 3).padding(.horizontal, 30)
            }
            .clipShape(Capsule())
            .gesture(LongPressGesture(minimumDuration: duration)
                .updating($pressing) { value, state, _ in state = value }
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    action()
                })
            .onChange(of: pressing) { _, isPressing in
                withAnimation(isPressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) { progress = isPressing ? 1 : 0 }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityIdentifier("commit.hold")
    }
}

/// Full-screen live countdown, presented while a focus session is running.
struct TimerRunningView: View {
    @ObservedObject var access: AccessController
    @Environment(\.dismiss) private var dismiss
    @State private var showLeave = false

    var body: some View {
        ZStack {
            runningBackground
            VStack {
                HStack {
                    CircleIconButton(symbol: "xmark", size: 40) { showLeave = true }
                        .accessibilityIdentifier("session.leave")
                        .accessibilityLabel("Quitter le minuteur")
                    Spacer()
                }
                Spacer()
                display
                Spacer()
                Spacer()
            }
            .padding(20)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showLeave) {
            LeaveEarlySheet {
                access.mutate { $0.focus = nil }
                showLeave = false
                dismiss()
            }
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
    }

    /// Same moody, procedurally-drawn backdrop the whole running screen bleeds from.
    private var runningBackground: some View {
        ZStack {
            Color.black
            Artwork(key: "limit").opacity(0.6)
            LinearGradient(colors: [.black.opacity(0.1), .black], startPoint: .top, endPoint: .bottom)
        }
    }

    private var display: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds: Int = {
                guard let focus = access.state.focus, focus.endsAt > timeline.date else { return 0 }
                return Int(focus.endsAt.timeIntervalSince(timeline.date).rounded(.up))
            }()
            LCDClock(seconds: seconds)
        }
    }
}

/// "Partir tôt ?" bottom sheet: maroon-to-black gradient, hold-to-confirm pill, plain cancel link.
struct LeaveEarlySheet: View {
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 10)
            ZStack {
                Circle().strokeBorder(Color(red: 0.94, green: 0.42, blue: 0.42).opacity(0.6), lineWidth: 1.5).frame(width: 56, height: 56)
                Image(systemName: "figure.run").font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.94, green: 0.42, blue: 0.42))
            }
            Text("Partir tôt ?").font(.title2.weight(.bold))
            Text("N’abandonne pas, tu as commencé pour une raison.")
                .font(.subheadline)
                .foregroundStyle(SeuilTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HoldToLeaveButton(onConfirm: onConfirm)
                .padding(.horizontal, 24)
            Button("Laisse tomber") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [Color(red: 0.24, green: 0.08, blue: 0.09), Color.black],
                           startPoint: .top, endPoint: .bottom)
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Hold-to-confirm pill whose fill sweeps left-to-right, then swaps to a white "Terminer" pill.
struct HoldToLeaveButton: View {
    let onConfirm: () -> Void
    @State private var progress: CGFloat = 0
    @State private var completed = false
    @GestureState private var pressing = false
    private let duration = 1.4

    var body: some View {
        Text(completed ? "Terminer" : (pressing ? "Maintenez appuyé…" : "Maintiens pour partir"))
            .font(.headline)
            .foregroundStyle(completed ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(alignment: .leading) {
                GeometryReader { geo in
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: geo.size.width * progress)
                }
            }
            .background(completed ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.12)), in: Capsule())
            .clipShape(Capsule())
            .gesture(LongPressGesture(minimumDuration: duration)
                .updating($pressing) { value, state, _ in state = value }
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    completed = true
                    onConfirm()
                })
            .onChange(of: pressing) { _, isPressing in
                withAnimation(isPressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) { progress = isPressing ? 1 : 0 }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onConfirm() }
            .accessibilityIdentifier("session.hold")
    }
}
