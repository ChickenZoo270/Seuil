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
    case budgetExhausted
    case sessionAlreadyActive
}

public enum Policy {
    public static let sessionMinutes = 15
    public static let budgetMinutes = 45
    public static let maxCharacters = 600

    // The classifier never controls the duration or the available budget.
    public static func decide(_ assessment: Assessment, usedMinutes: Int, hasSession: Bool) -> Decision {
        if hasSession { return .sessionAlreadyActive }
        if usedMinutes < 0 || usedMinutes + sessionMinutes > budgetMinutes { return .budgetExhausted }
        if assessment.kind == .scrolling { return .deny }
        guard assessment.specific else { return .clarify }
        switch assessment.kind {
        case .learning, .communication: return .allow(minutes: sessionMinutes)
        case .unclear: return .clarify
        case .scrolling: return .deny
        }
    }

    public static func normalized(_ input: String) -> String {
        input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Conservative offline grammar. Unknown or negated phrases require clarification.
    // This intentionally does not claim to understand arbitrary natural language.
    public static func localAssessment(_ input: String) -> Assessment {
        let text = normalized(input)
        guard text.count >= 12, text.count <= maxCharacters else {
            return Assessment(kind: .unclear, specific: false)
        }
        if ["scroll", "m'ennuie", "m’ennuie", "passer le temps", "voir ce qu", "pour toi", "for you"].contains(where: text.contains) {
            return Assessment(kind: .scrolling, specific: false)
        }
        let tokens = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if tokens.contains("pas") || tokens.contains("sans") || text.contains("ignore") {
            return Assessment(kind: .unclear, specific: false)
        }
        let learningPrefixes = ["je veux apprendre a ", "je veux comprendre comment ", "je veux chercher comment "]
        for prefix in learningPrefixes where text.hasPrefix(prefix) {
            let topic = text.dropFirst(prefix.count)
            if topic.split(separator: " ").count >= 3 {
                return Assessment(kind: .learning, specific: true)
            }
        }
        return Assessment(kind: .unclear, specific: false)
    }
}

public struct Receipt: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var minutes: Int
    public init(startedAt: Date, minutes: Int) {
        self.startedAt = startedAt
        self.minutes = minutes
    }
}

public enum Budget {
    // Rolling window avoids a midnight reset allowing back-to-back daily budgets.
    public static func used(_ receipts: [Receipt], now: Date) -> Int {
        receipts.filter { $0.startedAt > now.addingTimeInterval(-86_400) }
            .reduce(0) { $0 + max(0, $1.minutes) }
    }
}
