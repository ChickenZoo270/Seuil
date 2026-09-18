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
    @State private var source = ""
    @State private var busy = false
    @State private var classificationTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SeuilMark()
                            Text("seuil.").font(.system(size: 30, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("Ton espace").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
                        }.padding(.bottom, 22)
                        Text("Reprends la main.").font(.largeTitle.weight(.semibold)).tracking(-1)
                        Text("Décris ce que tu viens faire. Une session dure 15 minutes.")
                            .foregroundStyle(SeuilTheme.secondaryInk)
                    }
                    if !access.authorized {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Active ta protection").font(.headline)
                                Text("Seuil utilise Temps d’écran pour protéger les apps que tu choisis.")
                                Button("Autoriser Temps d’écran") { Task { await access.authorize() } }
                                    .foregroundStyle(SeuilTheme.onAccent)
                                    .buttonStyle(.borderedProminent)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        protectionSection
                        if let session = access.state.session {
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
                        } else if !access.state.applications.isEmpty {
                            intentionSection
                        }
                        Text("\(Budget.used(access.state.receipts, now: Date())) / 45 min accordées sur les dernières 24 h")
                            .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                        Text("Chaque session réserve 15 minutes, même si tu la termines plus tôt.")
                            .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
                    }
                    if !access.message.isEmpty {
                        Text(access.message).padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Résultat : \(access.message)")
                    }
                    if !source.isEmpty { Text(source).font(.caption).foregroundStyle(SeuilTheme.secondaryInk) }
                    Text("Ton intention reste sur cet iPhone. Tu gardes la possibilité de désactiver la protection dans Temps d’écran.")
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

    private var protectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tes apps protégées").font(.headline)
                Spacer()
                Button("Choisir mes apps") {
                    selection = FamilyActivitySelection()
                    selection.applicationTokens = access.state.applications
                    showPicker = true
                }.disabled(busy || access.state.session != nil)
            }
            if access.state.applications.isEmpty {
                Text("Facebook, Instagram, TikTok, jeux… Choisis les apps présentes sur ton iPhone dans le sélecteur Apple.").foregroundStyle(SeuilTheme.secondaryInk)
            }
            Text("La liste vient de ton appareil. Ouvre une catégorie pour choisir les apps individuellement.")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            ForEach(Array(access.state.applications), id: \.self) { token in
                Button {
                    target = token
                } label: {
                    HStack {
                        Label(token)
                        Spacer()
                        if target == token { Image(systemName: "checkmark.circle.fill") }
                    }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(busy || access.state.session != nil)
                    .accessibilityAddTraits(target == token ? .isSelected : [])
            }
        }
    }

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pourquoi ouvrir cette app ?").font(.title2.weight(.semibold))
            Text("Par exemple : « Je veux comprendre comment connecter Supabase à mon app. »")
                .font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
            TextEditor(text: $intention)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110).padding(8)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35)))
                .accessibilityLabel("Ton intention")
                .disabled(busy)
            Text("Écris ou utilise le micro du clavier pour dicter, puis relis avant de valider.")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            Text("\(intention.count)/600 caractères").font(.caption).foregroundStyle(SeuilTheme.secondaryInk)
            Button(busy ? "Analyse en cours…" : "Valider mon intention") { evaluate() }
                .foregroundStyle(SeuilTheme.onAccent)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(busy || target == nil || intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || intention.count > Policy.maxCharacters)
            if busy {
                Button("Annuler l’analyse") { classificationTask?.cancel() }
            }
        }
    }

    private func syncTarget() {
        if let pending = access.state.pendingApplication, access.state.applications.contains(pending) {
            target = pending
        } else if target.map({ !access.state.applications.contains($0) }) ?? true {
            target = access.state.applications.first
        }
    }

    private func evaluate() {
        guard let application = target else { return }
        let input = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= Policy.maxCharacters else { return }
        busy = true
        access.message = ""
        source = ""
        classificationTask = Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await IntentClassifier.classify(input)
                try Task.checkCancellation()
                source = result.source
                access.refresh()
                let decision = Policy.decide(result.assessment, usedMinutes: Budget.used(access.state.receipts, now: Date()), hasSession: access.state.session != nil)
                switch decision {
                case .allow:
                    try access.grant(application: application, assessment: result.assessment)
                    intention = ""
                case .clarify: access.message = "Précise l’action et le sujet recherchés. En mode règles locales, commence par « Je veux comprendre comment… » ou « Je veux apprendre à… »."
                case .deny: access.message = "Cette intention ressemble à du défilement sans objectif. L’app reste protégée."
                case .budgetExhausted: access.message = AppError.budget.localizedDescription
                case .sessionAlreadyActive: access.message = AppError.activeSession.localizedDescription
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
