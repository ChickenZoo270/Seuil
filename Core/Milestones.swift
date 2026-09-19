import Foundation

/// What the user has done so far, used to unlock doors.
public struct ProgressStats: Equatable, Sendable {
    public var openStreak: Int
    public var focusStreak: Int
    public var cleanStreak: Int
    public var focusSessions: Int
    public var usedHardMode: Bool

    public init(openStreak: Int = 0, focusStreak: Int = 0, cleanStreak: Int = 0, focusSessions: Int = 0, usedHardMode: Bool = false) {
        self.openStreak = openStreak
        self.focusStreak = focusStreak
        self.cleanStreak = cleanStreak
        self.focusSessions = focusSessions
        self.usedHardMode = usedHardMode
    }
}

/// Seuil's trophies: a door for every threshold crossed.
public enum Door: String, CaseIterable, Sendable {
    case wood, stone, torii, glass, moon, temple, gold, light

    public enum Requirement: Equatable, Sendable {
        case openDays(Int), focusStreak(Int), cleanStreak(Int), focusSessions(Int), hardMode
    }

    public var title: String {
        switch self {
        case .wood: return "La première porte"
        case .stone: return "La porte de pierre"
        case .torii: return "Le torii"
        case .glass: return "La porte de verre"
        case .moon: return "La porte de lune"
        case .temple: return "Le temple"
        case .gold: return "La porte d’or"
        case .light: return "Le seuil de lumière"
        }
    }

    public var requirement: Requirement {
        switch self {
        case .wood: return .openDays(1)
        case .stone: return .focusStreak(3)
        case .torii: return .cleanStreak(3)
        case .glass: return .focusStreak(7)
        case .moon: return .hardMode
        case .temple: return .focusSessions(25)
        case .gold: return .cleanStreak(30)
        case .light: return .cleanStreak(100)
        }
    }

    public var goal: String {
        switch requirement {
        case .openDays(let days): return "Ouvre Seuil \(days) jour\(days > 1 ? "s" : "") d’affilée."
        case .focusStreak(let days): return "Termine une session de Focus \(days) jours d’affilée."
        case .cleanStreak(let days): return "Tiens \(days) jours d’affilée sans déblocage ni limite dépassée."
        case .focusSessions(let count): return "Termine \(count) sessions de Focus."
        case .hardMode: return "Active le Hard Mode une première fois."
        }
    }

    public var celebration: String {
        switch self {
        case .wood: return "Félicitations ! Ton chemin vers le calme commence ici."
        case .stone: return "Trois jours de Focus : les fondations sont posées."
        case .torii: return "Tu passes du monde du bruit à celui de l’attention."
        case .glass: return "Une semaine de Focus. Tout devient plus clair."
        case .moon: return "Tu as choisi l’engagement total. Respect."
        case .temple: return "Vingt-cinq sessions. Ton attention a désormais un sanctuaire."
        case .gold: return "Un mois entier sans craquer. Rare et précieux."
        case .light: return "Cent jours. Tu as franchi le seuil."
        }
    }

    /// (current, target) towards this door.
    public func progress(_ stats: ProgressStats) -> (current: Int, target: Int) {
        switch requirement {
        case .openDays(let days): return (min(stats.openStreak, days), days)
        case .focusStreak(let days): return (min(stats.focusStreak, days), days)
        case .cleanStreak(let days): return (min(stats.cleanStreak, days), days)
        case .focusSessions(let count): return (min(stats.focusSessions, count), count)
        case .hardMode: return (stats.usedHardMode ? 1 : 0, 1)
        }
    }

    public func isUnlocked(_ stats: ProgressStats) -> Bool {
        let value = progress(stats)
        return value.current >= value.target
    }

    /// The most advanced door earned so far, shown on the home screen.
    public static func latest(_ stats: ProgressStats) -> Door? {
        allCases.last { $0.isUnlocked(stats) }
    }
}

public enum DayRun {
    /// Consecutive days in `days` ending today, or yesterday when today is not done yet.
    public static func current(_ days: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !days.contains(Streak.key(day, calendar: calendar)) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while days.contains(Streak.key(day, calendar: calendar)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
