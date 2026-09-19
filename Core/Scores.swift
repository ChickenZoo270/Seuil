import Foundation

/// Raw figures for one day, gathered by the Screen Time report extension.
public struct DayUsage: Equatable, Sendable {
    /// Screen time per hour of the day (index 0 = 00:00–01:00), in minutes.
    public var hourlyMinutes: [Double]
    /// Minutes spent in apps the user marked as distracting.
    public var distractingMinutes: Double
    public var pickups: Int
    public var unlocks: Int
    /// Current hour, so hours that have not happened yet are ignored.
    public var currentHour: Int

    public init(hourlyMinutes: [Double], distractingMinutes: Double, pickups: Int, unlocks: Int, currentHour: Int) {
        self.hourlyMinutes = hourlyMinutes.count == 24 ? hourlyMinutes : Array(repeating: 0, count: 24)
        self.distractingMinutes = max(0, distractingMinutes)
        self.pickups = max(0, pickups)
        self.unlocks = max(0, unlocks)
        self.currentHour = min(max(currentHour, 0), 23)
    }

    public var totalMinutes: Double { hourlyMinutes.reduce(0, +) }
}

/// How a figure compares with a healthy target.
public enum Rating: String, Sendable {
    case great, good, slow, bad

    public var label: String {
        switch self {
        case .great: return "Super"
        case .good: return "Bien"
        case .slow: return "Ralentis"
        case .bad: return "Mauvais"
        }
    }

    /// From a 0–100 sub-score.
    public init(score: Int) {
        switch score {
        case 85...: self = .great
        case 65..<85: self = .good
        case 40..<65: self = .slow
        default: self = .bad
        }
    }
}

public struct DailyScores: Equatable, Sendable {
    public let focus: Int
    public let rest: Int
    /// Nil until the night has been observed (before 06:00 nothing is known yet).
    public let sleep: Int?
    public var overall: Int {
        let parts = [focus, rest] + (sleep.map { [$0] } ?? [])
        return Int((Double(parts.reduce(0, +)) / Double(parts.count)).rounded())
    }
}

/// Seuil's own scoring: simple, explainable penalties against healthy targets.
public enum Scoring {
    public static let distractingBudget = 30.0       // minutes a day without penalty
    public static let distractingWorst = 180.0
    public static let pickupBudget = 30
    public static let pickupWorst = 120
    public static let screenTimeBudget = 120.0
    public static let screenTimeWorst = 480.0
    public static let offlineTarget = 3             // hours in a row away from the phone
    public static let nightHours = [0, 1, 2, 3, 4, 5]
    public static let nightWorst = 60.0
    public static let offlineThreshold = 5.0        // minutes in an hour still counted as offline

    /// 1 at or under `budget`, 0 at or beyond `worst`, linear in between.
    static func ratio(_ value: Double, budget: Double, worst: Double) -> Double {
        guard value > budget else { return 1 }
        guard value < worst else { return 0 }
        return 1 - (value - budget) / (worst - budget)
    }

    public static func focus(_ day: DayUsage) -> Int {
        let distraction = ratio(day.distractingMinutes, budget: distractingBudget, worst: distractingWorst)
        let pickups = ratio(Double(day.pickups), budget: Double(pickupBudget), worst: Double(pickupWorst))
        let unlockPenalty = min(Double(day.unlocks) * 0.08, 0.3)
        return clamp((0.6 * distraction + 0.4 * pickups - unlockPenalty) * 100)
    }

    /// Longest run of daytime hours (08:00 onward, up to now) nearly without the phone.
    public static func longestOfflineHours(_ day: DayUsage) -> Int {
        guard day.currentHour >= 8 else { return 0 }
        var best = 0, run = 0
        for hour in 8..<day.currentHour {
            run = day.hourlyMinutes[hour] <= offlineThreshold ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    /// The offline target shrinks early in the day to the daytime hours already elapsed.
    public static func rest(_ day: DayUsage) -> Int {
        let elapsed = day.currentHour - 8
        let target = min(offlineTarget, elapsed)
        let offline = target <= 0 ? 1 : min(Double(longestOfflineHours(day)) / Double(target), 1)
        let screen = ratio(day.totalMinutes, budget: screenTimeBudget, worst: screenTimeWorst)
        return clamp((0.5 * offline + 0.5 * screen) * 100)
    }

    public static func sleep(_ day: DayUsage) -> Int? {
        guard day.currentHour >= 6 else { return nil }
        let night = nightHours.map { day.hourlyMinutes[$0] }.reduce(0, +)
        return clamp(ratio(night, budget: 0, worst: nightWorst) * 100)
    }

    public static func scores(_ day: DayUsage) -> DailyScores {
        DailyScores(focus: focus(day), rest: rest(day), sleep: sleep(day))
    }

    static func clamp(_ value: Double) -> Int { Int(min(max(value, 0), 100).rounded()) }

    public static func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total)min" }
        let rest = total % 60
        return rest == 0 ? "\(total / 60)h" : "\(total / 60)h \(rest)min"
    }
}

/// Consecutive "clean" days: no unlock earned and no allowance used up.
public enum Streak {
    public static func count(cleanDays: Set<String>, today: Date, calendar: Calendar = .current, since start: Date) -> Int {
        var count = 0
        var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!
        let first = calendar.startOfDay(for: start)
        while day >= first, cleanDays.contains(key(day, calendar: calendar)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// One line of the "highlights of the day" list: a figure and how healthy it is.
public struct Highlight: Equatable, Sendable {
    public let title: String
    public let value: String
    /// 0 = far worse than the target, 100 = at or better than the target.
    public let score: Int
    public var rating: Rating { Rating(score: score) }
}

extension Scoring {
    public static func highlights(_ day: DayUsage) -> [Highlight] {
        let night = nightHours.map { day.hourlyMinutes[$0] }.reduce(0, +)
        var list = [
            Highlight(title: "Temps d’écran", value: duration(day.totalMinutes),
                      score: clamp(ratio(day.totalMinutes, budget: screenTimeBudget, worst: screenTimeWorst) * 100)),
            Highlight(title: "Distractions", value: duration(day.distractingMinutes),
                      score: clamp(ratio(day.distractingMinutes, budget: distractingBudget, worst: distractingWorst) * 100)),
            Highlight(title: "Prises en main", value: "\(day.pickups)",
                      score: clamp(ratio(Double(day.pickups), budget: Double(pickupBudget), worst: Double(pickupWorst)) * 100)),
            Highlight(title: "Déblocages", value: "\(day.unlocks)",
                      score: clamp(ratio(Double(day.unlocks), budget: 0, worst: 4) * 100)),
            Highlight(title: "Hors ligne", value: "\(longestOfflineHours(day)) h d’affilée",
                      score: clamp(min(Double(longestOfflineHours(day)) / Double(offlineTarget), 1) * 100)),
        ]
        if day.currentHour >= 6 {
            list.append(Highlight(title: "Écran la nuit", value: duration(night),
                                  score: clamp(ratio(night, budget: 0, worst: nightWorst) * 100)))
        }
        return list
    }
}
