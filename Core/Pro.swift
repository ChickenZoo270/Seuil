import Foundation

/// Features reserved for Seuil Pro.
public enum ProFeature: String, CaseIterable, Sendable {
    case strictMode, unlimitedRules, allowOnly, ambiences, messagePacks

    public var title: String {
        switch self {
        case .strictMode: return "Mode strict"
        case .unlimitedRules: return "Règles illimitées"
        case .allowOnly: return "Autoriser uniquement"
        case .ambiences: return "Ambiances sonores"
        case .messagePacks: return "Tous les écrans de blocage"
        }
    }

    public var summary: String {
        switch self {
        case .strictMode: return "Sans issue. Impossible de désactiver Seuil."
        case .unlimitedRules: return "Autant de routines et de limites que tu veux."
        case .allowOnly: return "Bloque tout sauf une liste d’apps choisies."
        case .ambiences: return "Pluie, océan, vent et nuit d’été, générés sur ton iPhone."
        case .messagePacks: return "Haïkus, piques, blagues et infos insolites."
        }
    }

    public var symbol: String {
        switch self {
        case .strictMode: return "lock.shield.fill"
        case .unlimitedRules: return "arrow.triangle.branch"
        case .allowOnly: return "checkmark.seal.fill"
        case .ambiences: return "waveform"
        case .messagePacks: return "text.bubble.fill"
        }
    }
}

/// What the free plan allows.
public enum FreePlan {
    public static let maxRules = 2
    public static let freePacks: Set<ShieldPack> = [.standard, .offline]

    public static func allowsRule(count: Int) -> Bool { count < maxRules }
    public static func allows(_ pack: ShieldPack) -> Bool { freePacks.contains(pack) }
}

/// Subscription options shown on the paywall.
public struct ProPlan: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let price: String
    public let detail: String
    public let perDay: String
    public let badge: String?

    public init(id: String, title: String, price: String, detail: String, perDay: String, badge: String?) {
        self.id = id
        self.title = title
        self.price = price
        self.detail = detail
        self.perDay = perDay
        self.badge = badge
    }

    /// Price per day, to show how small the yearly plan feels day by day.
    public static func perDay(price: Double, days: Int) -> String {
        let value = price / Double(max(days, 1))
        return String(format: "%.2f €/jour", value).replacingOccurrences(of: ".", with: ",")
    }
}

public enum ProProducts {
    public static let annual = "com.chickenzoo.seuil.pro.annual"
    public static let monthly = "com.chickenzoo.seuil.pro.monthly"
    public static let lifetime = "com.chickenzoo.seuil.pro.lifetime"
    public static let all = [annual, monthly, lifetime]
}
