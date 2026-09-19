import Foundation

/// How an unlock has to be earned.
public enum ChallengeKind: String, Codable, CaseIterable, Sendable {
    case math, typing, pause, reason

    public var title: String {
        switch self {
        case .math: return "Calcul mental"
        case .typing: return "Phrase à recopier"
        case .pause: return "Pause respiration"
        case .reason: return "Motif valable"
        }
    }

    public var summary: String {
        switch self {
        case .math: return "Résous quelques calculs sans calculatrice."
        case .typing: return "Recopie une phrase qui te fait réfléchir."
        case .pause: return "Attends en respirant avant d’ouvrir l’app."
        case .reason: return "Explique ce que tu viens faire. Le scroll sans but est refusé."
        }
    }
}

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard

    public var title: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        }
    }
}

public struct MathProblem: Equatable, Sendable {
    public let text: String
    public let answer: Int
}

/// Deterministic generator so challenges are reproducible in tests.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

public enum MathChallenge {
    public static func problemCount(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 2
        case .medium: return 3
        case .hard: return 4
        }
    }

    public static func problems(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> [MathProblem] {
        (0..<problemCount(for: difficulty)).map { _ in problem(difficulty: difficulty, using: &rng) }
    }

    static func problem(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> MathProblem {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 12...89, using: &rng), b = Int.random(in: 12...89, using: &rng)
            return MathProblem(text: "\(a) + \(b)", answer: a + b)
        case .medium:
            let a = Int.random(in: 12...39, using: &rng), b = Int.random(in: 3...9, using: &rng)
            return MathProblem(text: "\(a) × \(b)", answer: a * b)
        case .hard:
            let a = Int.random(in: 13...49, using: &rng), b = Int.random(in: 12...29, using: &rng)
            let c = Int.random(in: 11...99, using: &rng)
            return MathProblem(text: "\(a) × \(b) − \(c)", answer: a * b - c)
        }
    }

    public static func isCorrect(_ input: String, for problem: MathProblem) -> Bool {
        let digits = input.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-")
        return Int(digits) == problem.answer
    }
}

public enum TypingChallenge {
    public static let phrases: [Difficulty: [String]] = [
        .easy: [
            "Je choisis d’ouvrir cette app en conscience.",
            "Mon temps a de la valeur.",
        ],
        .medium: [
            "Je sais que ce que je cherche n’est probablement pas dans ce fil.",
            "Je peux faire quelque chose qui me rendra fier dans une heure.",
        ],
        .hard: [
            "Chaque minute passée à faire défiler un fil est une minute que je ne rendrai jamais à mes projets, à mes proches ou à moi-même.",
            "Je reconnais que cette ouverture est un réflexe et je décide malgré tout de continuer, en assumant pleinement ce choix.",
        ],
    ]

    public static func phrase(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> String {
        phrases[difficulty]?.randomElement(using: &rng) ?? "Mon temps a de la valeur."
    }

    /// Case, accents, apostrophe style and spacing do not matter; words do.
    public static func matches(_ input: String, phrase: String) -> Bool {
        simplified(input) == simplified(phrase)
    }

    static func simplified(_ text: String) -> String {
        Policy.normalized(text)
            .replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" })
            .joined(separator: " ")
    }
}

public enum PauseChallenge {
    public static func seconds(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 10
        case .medium: return 30
        case .hard: return 60
        }
    }
}

/// How many times per day an app may be unlocked. 0 means no cap.
public enum UnlockQuota {
    public static let options = [0, 1, 2, 3, 5, 10]

    public static func remaining(max: Int, used: Int) -> Int? {
        max == 0 ? nil : Swift.max(0, max - used)
    }

    public static func label(_ max: Int) -> String {
        switch max {
        case 0: return "Déblocages illimités"
        case 1: return "1 déblocage / jour"
        default: return "\(max) déblocages / jour"
        }
    }
}

/// Usage reminders sent while an app is in use, e.g. "15 min sur TikTok aujourd’hui".
public enum UsageAlert {
    public static let thresholds = [15, 30, 60]

    public static func message(minutes: Int, appName: String?) -> (title: String, body: String) {
        let app = appName ?? "cette app"
        let body: String
        switch minutes {
        case ..<30: body = "Ça fait \(minutes) min que tu es sur \(app) aujourd’hui. Tu cherches quelque chose de précis ?"
        case ..<60: body = "\(minutes) min sur \(app) aujourd’hui. C’est peut-être le moment de poser ton téléphone."
        default: body = "Déjà \(minutes / 60) h sur \(app) aujourd’hui. Qu’est-ce que tu aurais pu faire à la place ?"
        }
        return ("Seuil", body)
    }
}
