import SwiftUI
import FamilyControls
import ManagedSettings
import IntentionCore

struct ContentView: View {
    @StateObject private var access = AccessController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var target: ApplicationToken?
    @State private var intention = ""
    @State private var minutes = Policy.defaultUnlockMinutes
    @State private var source = ""
    @State private var busy = false
    @State private var classificationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if !access.authorized {
                        authorizationCard
                    } else {
                        if let session = access.state.session {
                            sessionCard(session)
                        } else if let target, let rule = access.state.rule(for: target) {
                            UnlockSection(
                                application: target, dailyMinutes: rule.dailyMinutes,
                                intention: $intention, minutes: $minutes, busy: busy,
                                onValidate: evaluate,
                                onCancelAnalysis: { classificationTask?.cancel() },
                                onDismiss: dismissUnlock)
                        }
                        feedback
                        RulesSection(
                            rules: access.state.rules,
                            locked: busy || access.state.session != nil,
                            onPick: {
                                selection = FamilyActivitySelection()
                                selection.applicationTokens = access.state.applications
                                showPicker = true
                            },
                            onLimit: { access.setDailyLimit($0, for: $1) },
                            onUnlock: { token in
                                access.message = ""
                                target = token
                            })
                    }
                    Text("Ton motif reste sur cet iPhone. Tu gardes la possibilité de désactiver la protection dans Temps d’écran.")
                        .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                }.padding(24)
            }
            .background(SeuilTheme.paper)
            .foregroundStyle(SeuilTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .tint(SeuilTheme.accent)
            .familyActivityPicker(isPresented: $showPicker, selection: $selection)
            .onChange(of: showPicker) { old, new in
                if old && !new { access.protect(selection); syncTarget() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { access.refresh(); syncTarget() }
                if phase == .background { classificationTask?.cancel() }
            }
            .task {
                access.refresh()
                syncTarget()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(2)) } catch { break }
                    if scenePhase == .active { access.refresh() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SeuilMark()
                Text("seuil.").font(.system(size: 30, weight: .semibold, design: .rounded))
                Spacer()
                Text("Ton espace").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
            }.padding(.bottom, 22)
            Text("Reprends la main.").font(.largeTitle.weight(.semibold)).tracking(-1)
            Text("Un temps libre par app et par jour. Au-delà, un motif valable.")
                .foregroundStyle(SeuilTheme.secondaryInk)
        }
    }

    private var authorizationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Active ta protection").font(.headline)
                Text("Seuil utilise Temps d’écran pour protéger les apps que tu choisis.")
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
        if !source.isEmpty { Text(source).font(.caption).foregroundStyle(SeuilTheme.secondaryInk) }
    }

    private func sessionCard(_ session: AccessSession) -> some View {
        GroupBox("Une seule chose à la fois") {
            VStack(spacing: 16) {
                Label(session.application)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(remaining(until: session.expiresAt, now: timeline.date))
                        .font(.system(size: 54, weight: .regular, design: .serif).monospacedDigit())
                        .padding(35)
                        .overlay(Circle().stroke(SeuilTheme.accent.opacity(0.25), lineWidth: 1))
                }
                Text("Retourne dans cette app. Elle sera rebloquée à la fin de la session.")
                    .foregroundStyle(SeuilTheme.secondaryInk)
                Button("J’ai terminé · rebloquer") { access.endSession() }
                    .foregroundStyle(SeuilTheme.onAccent)
                    .buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity)
        }
    }

    /// Opening a blocked app from its shield lands here with that app preselected.
    private func syncTarget() {
        if let pending = access.state.pendingApplication, access.state.applications.contains(pending) {
            target = pending
        } else if let current = target, !access.state.applications.contains(current) {
            target = nil
        }
    }

    private func dismissUnlock() {
        target = nil
        intention = ""
        access.message = ""
        access.dismissPending()
    }

    private func evaluate() {
        guard let application = target else { return }
        let input = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= Policy.maxCharacters else { return }
        busy = true
        access.message = ""
        source = ""
        let requested = minutes
        classificationTask = Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await IntentClassifier.classify(input)
                try Task.checkCancellation()
                source = result.source
                access.refresh()
                switch Policy.decide(result.assessment, requestedMinutes: requested, hasSession: access.state.session != nil) {
                case .allow:
                    try access.grant(application: application, assessment: result.assessment, minutes: requested)
                    intention = ""
                    target = nil
                case .clarify:
                    access.message = "Précise ce que tu vas faire et avec qui ou sur quel sujet. Par exemple : « Répondre au message de Léa pour samedi »."
                case .deny:
                    access.message = "Ça ressemble à du défilement sans objectif. L’app reste bloquée."
                case .invalidDuration:
                    access.message = "Choisis une durée de 5, 15 ou 30 minutes."
                case .sessionAlreadyActive:
                    access.message = AppError.activeSession.localizedDescription
                }
            } catch is CancellationError {
                access.message = "Analyse annulée. Aucune nouvelle autorisation."
            } catch { access.message = error.localizedDescription }
        }
    }

    private func remaining(until end: Date, now: Date) -> String {
        let seconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
