import SwiftUI
import IntentionCore

/// The challenge chosen in settings, used both to unlock and to try it out.
struct ChallengeView: View {
    let preferences: Preferences
    let minutes: Int
    let onPassed: () -> Void

    var body: some View {
        switch preferences.challenge {
        case .math: MathChallengeView(difficulty: preferences.difficulty, onPassed: onPassed)
        case .typing: TypingChallengeView(difficulty: preferences.difficulty, onPassed: onPassed)
        case .pause: PauseChallengeView(difficulty: preferences.difficulty, onPassed: onPassed)
        case .reason: ReasonChallengeView(minutes: minutes, onPassed: onPassed)
        }
    }
}

struct MathChallengeView: View {
    let difficulty: Difficulty
    let onPassed: () -> Void
    @State private var problems: [MathProblem] = []
    @State private var answers: [String] = []
    @State private var feedback = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Résous sans calculatrice").font(.headline)
            ForEach(Array(problems.enumerated()), id: \.offset) { index, problem in
                HStack {
                    Text("\(problem.text) =").font(.title3.monospacedDigit())
                        .accessibilityIdentifier("math.problem.\(index)")
                    Spacer()
                    TextField("?", text: answerBinding(index))
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .accessibilityLabel("Réponse à \(problem.text)")
                        .accessibilityIdentifier("math.answer.\(index)")
                }
            }
            if !feedback.isEmpty { Text(feedback).font(.footnote).foregroundStyle(.red) }
            Button("Valider", action: check)
                .accessibilityIdentifier("challenge.validate")
                .buttonStyle(.borderedProminent).foregroundStyle(SeuilTheme.onAccent)
                .disabled(answers.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
        .onAppear { if problems.isEmpty { regenerate() } }
    }

    private func answerBinding(_ index: Int) -> Binding<String> {
        Binding(get: { answers.indices.contains(index) ? answers[index] : "" },
                set: { if answers.indices.contains(index) { answers[index] = $0 } })
    }

    private func regenerate() {
        var rng = SystemRandomNumberGenerator()
        problems = MathChallenge.problems(difficulty: difficulty, using: &rng)
        answers = Array(repeating: "", count: problems.count)
    }

    private func check() {
        if zip(answers, problems).allSatisfy({ MathChallenge.isCorrect($0, for: $1) }) {
            onPassed()
        } else {
            feedback = "Au moins une réponse est fausse. Voici de nouveaux calculs."
            regenerate()
        }
    }
}

struct TypingChallengeView: View {
    let difficulty: Difficulty
    let onPassed: () -> Void
    @State private var phrase = ""
    @State private var input = ""
    @State private var feedback = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recopie cette phrase").font(.headline)
            Text("« \(phrase) »").font(.body.italic())
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .textSelection(.disabled)
                .accessibilityIdentifier("typing.phrase")
            TextField("Ta phrase", text: $input, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("typing.input")
            if !feedback.isEmpty { Text(feedback).font(.footnote).foregroundStyle(.red) }
            Button("Valider") {
                if TypingChallenge.matches(input, phrase: phrase) { onPassed() } else { feedback = "Ce n’est pas exactement la phrase. Réessaie." }
            }
            .buttonStyle(.borderedProminent).foregroundStyle(SeuilTheme.onAccent)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear {
            guard phrase.isEmpty else { return }
            var rng = SystemRandomNumberGenerator()
            phrase = TypingChallenge.phrase(difficulty: difficulty, using: &rng)
        }
    }
}

struct PauseChallengeView: View {
    let difficulty: Difficulty
    let onPassed: () -> Void
    @State private var remaining = 0
    @State private var inhale = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                DriftingSky()
                BreathingRing(size: 170, expanded: inhale)
                VStack(spacing: 6) {
                    Text(remaining > 0 ? (inhale ? "Inspire…" : "Expire…") : "Prêt")
                        .font(.title2.weight(.semibold))
                    Text(remaining > 0 ? "\(remaining)" : "✓")
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(.white)
                .shadow(radius: 6)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            Text("Reste sur cet écran. Quitter Seuil relance la pause.")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            Button("Continuer", action: onPassed)
                .buttonStyle(PillButtonStyle(variant: .bright))
                .disabled(remaining > 0)
        }
        .frame(maxWidth: .infinity)
        .task {
            let total = PauseChallenge.seconds(for: difficulty)
            let breathSeconds = 4
            remaining = total
            while remaining > 0 {
                if (total - remaining) % breathSeconds == 0 { inhale.toggle() }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                remaining -= 1
            }
        }
    }
}

struct ReasonChallengeView: View {
    let minutes: Int
    let onPassed: () -> Void
    @State private var intention = ""
    @State private var feedback = ""
    @State private var source = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pourquoi veux-tu la débloquer ?").font(.headline)
            Text("Par exemple : « Répondre au message de Léa pour samedi ».")
                .font(.footnote).foregroundStyle(SeuilTheme.secondaryInk)
            TextEditor(text: $intention)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90).padding(8)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35)))
                .accessibilityLabel("Ton motif")
                .disabled(busy)
            if !feedback.isEmpty { Text(feedback).font(.footnote).foregroundStyle(.red) }
            if !source.isEmpty { Text(source).font(.caption2).foregroundStyle(SeuilTheme.secondaryInk) }
            Button(busy ? "Analyse en cours…" : "Valider mon motif", action: evaluate)
                .buttonStyle(.borderedProminent).foregroundStyle(SeuilTheme.onAccent)
                .disabled(busy || intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || intention.count > Policy.maxCharacters)
        }
    }

    private func evaluate() {
        let input = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        feedback = ""
        Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await IntentClassifier.classify(input)
                source = result.source
                switch Policy.decide(result.assessment, requestedMinutes: minutes, hasSession: false) {
                case .allow: onPassed()
                case .clarify: feedback = "Précise ce que tu vas faire, avec qui ou sur quel sujet."
                case .deny: feedback = "Ça ressemble à du défilement sans objectif. Refusé."
                case .invalidDuration, .sessionAlreadyActive: feedback = AppError.invalidDecision.localizedDescription
                }
            } catch { feedback = error.localizedDescription }
        }
    }
}
