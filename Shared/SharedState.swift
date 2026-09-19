import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Darwin
import IntentionCore

enum AppConfiguration {
    static var group: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "IntentionAppGroup") as? String,
              !value.isEmpty else { preconditionFailure("Missing IntentionAppGroup build setting") }
        return value
    }
    static let store = ManagedSettingsStore(named: .init("intention"))
}

struct AccessSession: Codable {
    let id: String
    let application: ApplicationToken
    let startedAt: Date
    let expiresAt: Date
    var isArmed: Bool
}

/// One protected app: daily allowance, unlock cap and today's state.
struct AppRule: Codable, Identifiable {
    let id: String
    let token: ApplicationToken
    var dailyMinutes: Int
    var maxUnlocks = 0
    var limitReachedAt: Date?
    var unlocks: [Date] = []
    /// Display name, captured by the shield when iOS reveals it (tokens are opaque).
    var name: String?

    init(token: ApplicationToken, dailyMinutes: Int) {
        id = UUID().uuidString
        self.token = token
        self.dailyMinutes = dailyMinutes
    }

    private enum CodingKeys: String, CodingKey { case id, token, dailyMinutes, maxUnlocks, limitReachedAt, unlocks, name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        token = try container.decode(ApplicationToken.self, forKey: .token)
        dailyMinutes = try container.decode(Int.self, forKey: .dailyMinutes)
        maxUnlocks = try container.decodeIfPresent(Int.self, forKey: .maxUnlocks) ?? 0
        limitReachedAt = try container.decodeIfPresent(Date.self, forKey: .limitReachedAt)
        unlocks = try container.decodeIfPresent([Date].self, forKey: .unlocks) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }

    func isBlocked(now: Date) -> Bool {
        dailyMinutes == 0 || DailyLimit.isReached(reachedAt: limitReachedAt, now: now)
    }

    func unlocksToday(now: Date, calendar: Calendar = .current) -> Int {
        unlocks.filter { calendar.isDate($0, inSameDayAs: now) }.count
    }

    func remainingUnlocks(now: Date) -> Int? {
        UnlockQuota.remaining(max: maxUnlocks, used: unlocksToday(now: now))
    }
}

/// Scheduled blocking, like Screen Time downtime.
struct Routine: Codable, Identifiable {
    var id = UUID().uuidString
    var name = "Concentration"
    var window = RoutineWindow(startMinute: 9 * 60, endMinute: 12 * 60, weekdays: [2, 3, 4, 5, 6])
    var applications: Set<ApplicationToken> = []
    var categories: Set<ActivityCategoryToken> = []
    /// Strict routines cannot be unlocked, even with a challenge.
    var isStrict = false
    var isEnabled = true

    var isEmpty: Bool { applications.isEmpty && categories.isEmpty }
}

/// "Block everything now" session; always strict.
struct FocusSession: Codable {
    let id: String
    let endsAt: Date
}

struct Preferences: Codable, Equatable {
    var challenge: ChallengeKind = .math
    var difficulty: Difficulty = .medium
    var usageAlerts = true
}

struct SharedState: Codable {
    var rules: [AppRule] = []
    var routines: [Routine] = []
    /// Routines currently blocking, maintained by the monitor and reconciled by the app.
    var activeRoutineIDs: Set<String> = []
    var focus: FocusSession?
    var preferences = Preferences()
    var session: AccessSession?
    var pendingApplication: ApplicationToken?
    /// Usage reminders already sent, as "day|rule|minutes", so restarts never repeat them.
    var sentAlerts: [String] = []

    var applications: Set<ApplicationToken> { Set(rules.map(\.token)) }
    var activeRoutines: [Routine] { routines.filter { $0.isEnabled && activeRoutineIDs.contains($0.id) } }

    func rule(for token: ApplicationToken) -> AppRule? { rules.first { $0.token == token } }

    func isFocusActive(now: Date) -> Bool { focus.map { $0.endsAt > now } ?? false }

    /// Apps that no challenge can open right now.
    func isStrictlyBlocked(_ token: ApplicationToken, now: Date) -> Bool {
        if isFocusActive(now: now) { return true }
        return activeRoutines.contains { $0.isStrict && $0.applications.contains(token) }
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case rules, routines, activeRoutineIDs, focus, preferences, session, pendingApplication, sentAlerts, applications
    }

    // Older versions stored fewer fields; version 1 stored a bare set of always-blocked apps.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decodeIfPresent(AccessSession.self, forKey: .session)
        pendingApplication = try container.decodeIfPresent(ApplicationToken.self, forKey: .pendingApplication)
        routines = try container.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        activeRoutineIDs = try container.decodeIfPresent(Set<String>.self, forKey: .activeRoutineIDs) ?? []
        focus = try container.decodeIfPresent(FocusSession.self, forKey: .focus)
        preferences = try container.decodeIfPresent(Preferences.self, forKey: .preferences) ?? Preferences()
        sentAlerts = try container.decodeIfPresent([String].self, forKey: .sentAlerts) ?? []
        if let rules = try container.decodeIfPresent([AppRule].self, forKey: .rules) {
            self.rules = rules
        } else {
            let legacy = try container.decodeIfPresent(Set<ApplicationToken>.self, forKey: .applications) ?? []
            rules = legacy.map { AppRule(token: $0, dailyMinutes: 0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encode(routines, forKey: .routines)
        try container.encode(activeRoutineIDs, forKey: .activeRoutineIDs)
        try container.encodeIfPresent(focus, forKey: .focus)
        try container.encode(preferences, forKey: .preferences)
        try container.encodeIfPresent(session, forKey: .session)
        try container.encodeIfPresent(pendingApplication, forKey: .pendingApplication)
        try container.encode(sentAlerts, forKey: .sentAlerts)
    }

    static func alertKey(ruleID: String, minutes: Int, now: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)|\(ruleID)|\(minutes)"
    }
}

enum AppError: LocalizedError {
    case storage, unsupportedSelection, unauthorized, unavailableApplication, activeSession, invalidDecision
    case strict, quotaReached, invalidRoutine, focusActive
    var errorDescription: String? {
        switch self {
        case .storage: return "Le stockage partagé est inaccessible. Vérifie la configuration App Groups."
        case .unsupportedSelection: return "Sélectionne uniquement des apps individuelles, sans catégorie ni site web."
        case .unauthorized: return "Autorise d’abord l’accès à Temps d’écran."
        case .unavailableApplication: return "Choisis une app dans ta liste protégée."
        case .activeSession: return "Une session est déjà en cours. Termine-la avant de continuer."
        case .invalidDecision: return "Ce déblocage n’a pas été mérité."
        case .strict: return "Mode strict en cours : aucun déblocage possible avant la fin."
        case .quotaReached: return "Plus aucun déblocage disponible aujourd’hui pour cette app."
        case .invalidRoutine: return "Une routine doit durer au moins 15 minutes, sur au moins un jour, avec au moins une app."
        case .focusActive: return "Une session Focus est déjà en cours."
        }
    }
}

// The app and its extensions serialize their read/modify/write operations through
// the same OS file lock. Atomic JSON replacement alone would not prevent lost updates.
enum SharedStorage {
    static func locked<T>(_ operation: (inout SharedState, (SharedState) throws -> Void) throws -> T) throws -> T {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.group) else {
            throw AppError.storage
        }
        let lockURL = directory.appendingPathComponent("state.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw AppError.storage }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw AppError.storage }
        defer { flock(descriptor, LOCK_UN) }
        let url = directory.appendingPathComponent("state.json")
        var state: SharedState
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(SharedState.self, from: Data(contentsOf: url))
        } else {
            state = SharedState()
        }
        return try operation(&state) { updated in
            let data = try JSONEncoder().encode(updated)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    /// Read-only access for extensions whose sandbox may forbid writing the lock file.
    static func snapshot() throws -> SharedState {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.group) else {
            throw AppError.storage
        }
        let url = directory.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return SharedState() }
        return try JSONDecoder().decode(SharedState.self, from: Data(contentsOf: url))
    }
}
