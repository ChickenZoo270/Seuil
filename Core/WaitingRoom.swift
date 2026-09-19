import Foundation

/// How the waiting room gets harder through the day.
public enum Resistance: String, Codable, CaseIterable, Sendable {
    case standard, growing

    public var title: String { self == .standard ? "Standard" : "Croissante" }
    public var summary: String {
        self == .standard ? "Une courte pause avant de continuer" : "Devient plus difficile à chaque fois que tu continues"
    }

    /// Growing resistance raises the base difficulty by one level per unlock already earned today.
    public func difficulty(base: Difficulty, unlocksToday: Int) -> Difficulty {
        guard self == .growing else { return base }
        let levels = Difficulty.allCases
        let index = min((levels.firstIndex(of: base) ?? 0) + max(0, unlocksToday), levels.count - 1)
        return levels[index]
    }
}

/// How often Autofocus pings while a distracting app is in use.
public enum AutofocusFrequency: String, Codable, CaseIterable, Sendable {
    case low, medium, high

    public var title: String {
        switch self {
        case .low: return "Faible"
        case .medium: return "Moyenne"
        case .high: return "Élevée"
        }
    }

    public var thresholds: [Int] {
        switch self {
        case .low: return [30, 60, 90]
        case .medium: return [15, 30, 60]
        case .high: return [10, 20, 30, 45, 60]
        }
    }
}

/// "Schulte table": tap the numbers in order as fast as possible.
public enum NumberPuzzle {
    public static func size(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 9
        case .medium: return 16
        case .hard: return 25
        }
    }

    public static func grid(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> [Int] {
        Array(1...size(for: difficulty)).shuffled(using: &rng)
    }

    /// The next number expected after `found` correct taps.
    public static func isNext(_ value: Int, found: Int) -> Bool { value == found + 1 }
}

/// Messages shown on the shield over a blocked app, grouped in packs the user switches on.
public enum ShieldPack: String, Codable, CaseIterable, Sendable {
    case standard, pop, haiku, luminaries, roast, dadJokes, offline, funFacts

    public var title: String {
        switch self {
        case .standard: return "Par défaut"
        case .pop: return "Culture pop"
        case .haiku: return "Haïkus de concentration"
        case .luminaries: return "Grands esprits"
        case .roast: return "Piques bien senties"
        case .dadJokes: return "Blagues de tonton"
        case .offline: return "Idées hors ligne"
        case .funFacts: return "Infos insolites"
        }
    }

    public var emoji: String {
        switch self {
        case .standard: return "👋"
        case .pop: return "🍿"
        case .haiku: return "🪶"
        case .luminaries: return "🏛️"
        case .roast: return "🌶️"
        case .dadJokes: return "🥸"
        case .offline: return "💡"
        case .funFacts: return "🔎"
        }
    }

    public var summary: String {
        switch self {
        case .standard: return "Cette app est bloquée par Seuil."
        case .pop: return "Des clins d’œil à la culture populaire à chaque ouverture."
        case .haiku: return "Trois lignes de sagesse avant de replonger."
        case .luminaries: return "La pensée des grands esprits pour nourrir la tienne."
        case .roast: return "Tu n’as pas peur d’être un peu secoué. Déconseillé aux âmes sensibles."
        case .dadJokes: return "Reste concentré, champion ! Les distractions, c’est comme les écureuils…"
        case .offline: return "Une idée d’activité à faire sans ton téléphone."
        case .funFacts: return "Une info insolite pour repartir plus malin."
        }
    }

    public var messages: [String] {
        switch self {
        case .standard: return [
            "Cette app est en pause. Respire, puis choisis vraiment.",
            "Petit rappel : cette app peut attendre.",
        ]
        case .pop: return [
            "Même les héros de film éteignent parfois leur téléphone.",
            "Le prochain épisode de ta vie ne se regarde pas en scrollant.",
            "Aucune série n’a jamais été aussi bien que ta vraie journée.",
        ]
        case .haiku: return [
            "Écran qui s’éteint —\nle silence de la pièce\nme rend mes pensées.",
            "Pouce suspendu,\nle fil infini attend.\nMoi, je vais marcher.",
            "Une notification\nse tait sous la pluie d’automne.\nJ’écoute la pluie.",
        ]
        case .luminaries: return [
            "« Ce n’est pas que nous ayons peu de temps, c’est que nous en perdons beaucoup. » — Sénèque",
            "« Tout le malheur des hommes vient d’une seule chose, qui est de ne savoir pas demeurer en repos dans une chambre. » — Pascal",
            "« Le temps est ce que nous voulons le plus, et ce que nous utilisons le plus mal. » — William Penn",
            "« Tu as du pouvoir sur ton esprit, pas sur les événements. » — Marc Aurèle",
        ]
        case .roast: return [
            "Encore toi ? Même l’algorithme commence à s’ennuyer.",
            "Ton pouce mériterait des vacances. Toi aussi.",
            "Tu voulais « juste regarder deux secondes ». On connaît la suite.",
        ]
        case .dadJokes: return [
            "Pourquoi le téléphone a-t-il des lunettes ? Parce qu’il a perdu ses contacts.",
            "Les distractions, c’est comme les écureuils : dès qu’on en voit un, on oublie tout.",
            "Tu sais ce qui a le plus de followers ? Les gens qui marchent dehors. Leurs pas les suivent.",
        ]
        case .offline: return [
            "Idée : sors marcher dix minutes sans écouteurs.",
            "Idée : appelle quelqu’un que tu n’as pas vu depuis longtemps.",
            "Idée : lis dix pages d’un livre qui traîne.",
            "Idée : range un tiroir. Satisfaction garantie.",
            "Idée : prépare-toi un vrai café et bois-le assis.",
        ]
        case .funFacts: return [
            "Les poulpes ont trois cœurs et le sang bleu.",
            "Une journée sur Vénus dure plus longtemps qu’une année sur Vénus.",
            "Le miel ne se périme pas : on en a retrouvé de comestible dans des tombes égyptiennes.",
            "Les loutres de mer se tiennent la main en dormant pour ne pas dériver.",
        ]
        }
    }

    /// One message among the enabled packs; the standard pack is the fallback.
    public static func pick(from packs: Set<ShieldPack>, using rng: inout some RandomNumberGenerator) -> (pack: ShieldPack, text: String) {
        let pool = packs.isEmpty ? [ShieldPack.standard] : ShieldPack.allCases.filter(packs.contains)
        let pack = pool.randomElement(using: &rng) ?? .standard
        return (pack, pack.messages.randomElement(using: &rng) ?? ShieldPack.standard.messages[0])
    }
}

/// One emergency unlock a week, even through strict rules.
public enum EmergencyPass {
    public static let cooldown: TimeInterval = 7 * 86_400
    public static let minutes = 15

    public static func isAvailable(lastUsed: Date?, now: Date) -> Bool {
        guard let lastUsed else { return true }
        return now.timeIntervalSince(lastUsed) >= cooldown || lastUsed > now
    }

    public static func nextAvailable(lastUsed: Date?) -> Date? { lastUsed.map { $0.addingTimeInterval(cooldown) } }
}
