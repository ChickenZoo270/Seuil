import Foundation

public enum IntentKind: String, Codable, Sendable {
    case learning, communication, scrolling, unclear
}

public struct Assessment: Sendable {
    public let kind: IntentKind
    public let specific: Bool
    public init(kind: IntentKind, specific: Bool) {
        self.kind = kind
        self.specific = specific
    }
}

public enum Decision: Equatable, Sendable {
    case allow(minutes: Int)
    case clarify
    case deny
    case invalidDuration
    case sessionAlreadyActive
}

public enum Policy {
    /// Durations the user may request once a valid reason is given.
    public static let unlockOptions = [5, 15, 30]
    public static let defaultUnlockMinutes = 15
    /// Daily allowance choices per app. 0 means the app always asks for a reason.
    public static let dailyLimitOptions = [0, 5, 10, 15, 30, 45, 60, 90, 120]
    public static let defaultDailyLimitMinutes = 30
    public static let maxCharacters = 600
    static let minimumWords = 4

    // The classifier never controls the duration: it only comes from the fixed options.
    public static func decide(_ assessment: Assessment, requestedMinutes: Int, hasSession: Bool) -> Decision {
        if hasSession { return .sessionAlreadyActive }
        guard unlockOptions.contains(requestedMinutes) else { return .invalidDuration }
        if assessment.kind == .scrolling { return .deny }
        guard assessment.specific else { return .clarify }
        switch assessment.kind {
        case .learning, .communication: return .allow(minutes: requestedMinutes)
        case .unclear: return .clarify
        case .scrolling: return .deny
        }
    }

    public static func normalized(_ input: String) -> String {
        input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let scrollingMarkers = [
        "scroll", "m'ennuie", "m’ennuie", "je m ennuie", "passer le temps", "voir ce qu", "pour toi", "for you",
        "juste regarder", "reels", "fil d'actu", "fil d’actu", "rien de special", "tuer le temps",
    ]
    private static let communicationVerbs = [
        "repondre", "envoyer", "ecrire", "appeler", "contacter", "prevenir", "demander", "souhaiter",
        "publier", "poster", "partager", "confirmer", "organiser", "inviter", "remercier", "feliciter",
    ]
    private static let learningVerbs = [
        "apprendre", "comprendre", "chercher", "rechercher", "trouver", "verifier", "consulter",
        "lire", "regarder comment", "suivre le tuto", "suivre un tuto", "reviser", "etudier",
    ]

    // Conservative offline grammar: an action verb plus enough words to name the topic
    // or recipient. Unknown, negated or boredom-driven phrases never unlock.
    public static func localAssessment(_ input: String) -> Assessment {
        let text = normalized(input)
        guard text.count >= 12, text.count <= maxCharacters else {
            return Assessment(kind: .unclear, specific: false)
        }
        if scrollingMarkers.contains(where: text.contains) {
            return Assessment(kind: .scrolling, specific: false)
        }
        let tokens = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if tokens.contains("pas") || tokens.contains("sans") || tokens.contains("rien") || text.contains("ignore") {
            return Assessment(kind: .unclear, specific: false)
        }
        let specific = tokens.count >= minimumWords
        if communicationVerbs.contains(where: { tokens.contains($0) }) {
            return Assessment(kind: .communication, specific: specific)
        }
        if learningVerbs.contains(where: { $0.contains(" ") ? text.contains($0) : tokens.contains($0) }) {
            return Assessment(kind: .learning, specific: specific)
        }
        return Assessment(kind: .unclear, specific: false)
    }
}

public enum DailyLimit {
    /// A limit reached on a previous day no longer blocks the app, even if the
    /// midnight callback was missed.
    public static func isReached(reachedAt: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let reachedAt, reachedAt <= now else { return false }
        return calendar.isDate(reachedAt, inSameDayAs: now)
    }

    public static func label(_ minutes: Int) -> String {
        if minutes == 0 { return "Toujours demander" }
        if minutes < 60 { return "\(minutes) min / jour" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) h / jour" : "\(hours) h \(rest) / jour"
    }
}
