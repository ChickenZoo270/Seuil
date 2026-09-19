import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

struct TodayView: View {
    @ObservedObject var access: AccessController
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var target: ApplicationToken?
    @State private var focusChoice: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !access.authorized {
                    authorizationCard
                } else {
                    if let session = access.state.session {
                        sessionCard(session)
                    } else if let target {
                        UnlockFlow(application: target, state: access.state,
                                   onGranted: { grant(target, minutes: $0) },
                                   onDismiss: dismissUnlock)
                    }
                    feedback
                    FocusCard(access: access, focusChoice: $focusChoice)
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
                        onUnlock: { token in
                            access.message = ""
                            target = token
                        })
                }
                Text("Tout reste sur cet iPhone. Tu peux retirer l’accès à tout moment dans Réglages › Temps d’écran.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            }.padding(24)
        }
        .background(SeuilTheme.paper)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { old, new in
            if old && !new { access.protect(selection) }
        }
        // Opening a blocked app from its shield lands here with that app preselected.
        .onChange(of: access.state.pendingApplication) { _, pending in
            if let pending { target = pending }
        }
        .onAppear { if let pending = access.state.pendingApplication { target = pending } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SeuilMark()
                Text("seuil.").font(.system(size: 30, weight: .semibold, design: .rounded))
            }.padding(.bottom, 18)
            Text("Reprends la main.").font(.largeTitle.weight(.semibold)).tracking(-1)
            Text("Les apps que tu ouvres sans cesse se méritent.")
                .foregroundStyle(SeuilTheme.secondaryInk)
        }
    }

    private var authorizationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active ta protection").font(.headline)
                Text("Seuil utilise Temps d’écran pour verrouiller les apps que tu choisis, et les notifications pour te prévenir quand tu scrolles trop.")
                Button("Autoriser Temps d’écran") { Task { await access.authorize() } }
                    .foregroundStyle(SeuilTheme.onAccent)
                    .buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if !access.message.isEmpty {
            Text(access.message).padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Résultat : \(access.message)")
        }
    }

    private func sessionCard(_ session: AccessSession) -> some View {
        GroupBox("Une seule chose à la fois") {
            VStack(spacing: 16) {
                Label(session.application)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(Countdown.text(until: session.expiresAt, now: timeline.date))
                        .font(.system(size: 54, weight: .regular, design: .serif).monospacedDigit())
                        .padding(35)
                        .overlay(Circle().stroke(SeuilTheme.accent.opacity(0.25), lineWidth: 1))
                }
                Text("Retourne dans cette app. Elle sera reverrouillée à la fin.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
                Button("J’ai terminé · reverrouiller") { access.endSession() }
                    .foregroundStyle(SeuilTheme.onAccent)
                    .buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity)
        }
    }

    private func grant(_ application: ApplicationToken, minutes: Int) {
        do {
            try access.grant(application: application, minutes: minutes)
            target = nil
        } catch { access.message = error.localizedDescription }
    }

    private func dismissUnlock() {
        target = nil
        access.message = ""
        access.dismissPending()
    }
}

enum Countdown {
    static func text(until end: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// "Block everything now": strict, cannot be stopped early.
struct FocusCard: View {
    @ObservedObject var access: AccessController
    @Binding var focusChoice: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let focus = access.state.focus, access.state.isFocusActive(now: Date()) {
                Label("Focus en cours", systemImage: "moon.stars.fill").font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(Countdown.text(until: focus.endsAt, now: timeline.date))
                        .font(.system(size: 40, design: .serif).monospacedDigit())
                }
                Text("Toutes tes apps verrouillées et tes routines sont bloquées, sans déblocage possible.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            } else {
                Label("Session Focus", systemImage: "moon.stars").font(.headline)
                Text("Bloque tout, tout de suite. Impossible d’arrêter avant la fin.")
                    .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                HStack {
                    ForEach(FocusMonitoring.options, id: \.self) { minutes in
                        Button("\(minutes) min") { focusChoice = minutes }
                            .buttonStyle(.bordered)
                            .disabled(access.state.rules.isEmpty && access.state.routines.isEmpty)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        .confirmationDialog("Lancer un Focus strict ?", isPresented: Binding(
            get: { focusChoice != nil }, set: { if !$0 { focusChoice = nil } }), titleVisibility: .visible) {
            if let minutes = focusChoice {
                Button("Bloquer tout \(minutes) min") { access.startFocus(minutes: minutes); focusChoice = nil }
            }
            Button("Annuler", role: .cancel) { focusChoice = nil }
        } message: {
            Text("Aucun déblocage ne sera possible avant la fin.")
        }
    }
}
