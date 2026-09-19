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
    /// Blocks every app except the always-allowed ones.
    var blocksAll = false
    /// Artwork used by its card.
    var artwork = "work"

    var isEmpty: Bool { !blocksAll && applications.isEmpty && categories.isEmpty }

    init(id: String = UUID().uuidString, name: String = "Concentration",
         window: RoutineWindow = RoutineWindow(startMinute: 9 * 60, endMinute: 12 * 60, weekdays: [2, 3, 4, 5, 6]),
         applications: Set<ApplicationToken> = [], categories: Set<ActivityCategoryToken> = [],
         isStrict: Bool = false, isEnabled: Bool = true, blocksAll: Bool = false, artwork: String = "work") {
        self.id = id
        self.name = name
        self.window = window
        self.applications = applications
        self.categories = categories
        self.isStrict = isStrict
        self.isEnabled = isEnabled
        self.blocksAll = blocksAll
        self.artwork = artwork
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, window, applications, categories, isStrict, isEnabled, blocksAll, artwork
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        window = try c.decode(RoutineWindow.self, forKey: .window)
        applications = try c.decodeIfPresent(Set<ApplicationToken>.self, forKey: .applications) ?? []
        categories = try c.decodeIfPresent(Set<ActivityCategoryToken>.self, forKey: .categories) ?? []
        isStrict = try c.decodeIfPresent(Bool.self, forKey: .isStrict) ?? false
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        blocksAll = try c.decodeIfPresent(Bool.self, forKey: .blocksAll) ?? false
        artwork = try c.decodeIfPresent(String.self, forKey: .artwork) ?? "work"
    }
}

/// "Block everything now" session started from the timer.
struct FocusSession: Codable {
    let id: String
    let endsAt: Date
    var name = "Minuteur"
    /// Strict sessions cannot be unlocked with a challenge.
    var isStrict = true

    init(id: String, endsAt: Date, name: String = "Minuteur", isStrict: Bool = true) {
        self.id = id
        self.endsAt = endsAt
        self.name = name
        self.isStrict = isStrict
    }

    private enum CodingKeys: String, CodingKey { case id, endsAt, name, isStrict }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        endsAt = try c.decode(Date.self, forKey: .endsAt)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Minuteur"
        isStrict = try c.decodeIfPresent(Bool.self, forKey: .isStrict) ?? true
    }
}

struct Preferences: Codable, Equatable {
    var challenge: ChallengeKind = .math
    var difficulty: Difficulty = .medium
    var usageAlerts = true
    /// No temporary unlock, no cancelling, no bypass.
    var hardMode = false
    /// Switching Hard Mode off only takes effect after a cooling-off delay.
    var hardModeOffAt: Date?

    init() {}

    private enum CodingKeys: String, CodingKey { case challenge, difficulty, usageAlerts, hardMode, hardModeOffAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        challenge = try c.decodeIfPresent(ChallengeKind.self, forKey: .challenge) ?? .math
        difficulty = try c.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .medium
        usageAlerts = try c.decodeIfPresent(Bool.self, forKey: .usageAlerts) ?? true
        hardMode = try c.decodeIfPresent(Bool.self, forKey: .hardMode) ?? false
        hardModeOffAt = try c.decodeIfPresent(Date.self, forKey: .hardModeOffAt)
    }

    func isHardModeActive(now: Date) -> Bool {
        hardMode && (hardModeOffAt.map { $0 > now } ?? true)
    }
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
    /// Never blocked, even by focus sessions or "block everything" routines.
    var allowedApplications: Set<ApplicationToken> = []
    /// Always blocked, and no challenge can open them.
    var neverAllowed: Set<ApplicationToken> = []
    /// Days (yyyy-mm-dd) where an unlock was earned or an allowance ran out; they break the streak.
    var dirtyDays: Set<String> = []
    var installedAt = Date()

    var applications: Set<ApplicationToken> { Set(rules.map(\.token)) }
    var activeRoutines: [Routine] { routines.filter { $0.isEnabled && activeRoutineIDs.contains($0.id) } }

    func rule(for token: ApplicationToken) -> AppRule? { rules.first { $0.token == token } }

    func isFocusActive(now: Date) -> Bool { focus.map { $0.endsAt > now } ?? false }

    /// Apps that no challenge can open right now.
    func isStrictlyBlocked(_ token: ApplicationToken, now: Date) -> Bool {
        if neverAllowed.contains(token) || preferences.isHardModeActive(now: now) { return true }
        if let focus, focus.endsAt > now, focus.isStrict { return true }
        return activeRoutines.contains { $0.isStrict && ($0.blocksAll || $0.applications.contains(token)) }
    }

    /// Whether anything blocks every app right now (focus or a "block everything" routine).
    func blocksAll(now: Date) -> Bool {
        isFocusActive(now: now) || activeRoutines.contains(where: \.blocksAll)
    }

    mutating func markDirty(_ date: Date) { dirtyDays.insert(Streak.key(date)) }

    /// Consecutive clean days before today, since the app was installed.
    func streak(now: Date, calendar: Calendar = .current) -> Int {
        var clean = Set<String>()
        var day = calendar.startOfDay(for: installedAt)
        let today = calendar.startOfDay(for: now)
        while day < today {
            let key = Streak.key(day, calendar: calendar)
            if !dirtyDays.contains(key) { clean.insert(key) }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today
        }
        return Streak.count(cleanDays: clean, today: now, calendar: calendar, since: installedAt)
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case rules, routines, activeRoutineIDs, focus, preferences, session, pendingApplication, sentAlerts, applications
        case allowedApplications, neverAllowed, dirtyDays, installedAt
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
        allowedApplications = try container.decodeIfPresent(Set<ApplicationToken>.self, forKey: .allowedApplications) ?? []
        neverAllowed = try container.decodeIfPresent(Set<ApplicationToken>.self, forKey: .neverAllowed) ?? []
        dirtyDays = try container.decodeIfPresent(Set<String>.self, forKey: .dirtyDays) ?? []
        installedAt = try container.decodeIfPresent(Date.self, forKey: .installedAt) ?? Date()
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
        try container.encode(allowedApplications, forKey: .allowedApplications)
        try container.encode(neverAllowed, forKey: .neverAllowed)
        try container.encode(dirtyDays, forKey: .dirtyDays)
        try container.encode(installedAt, forKey: .installedAt)
    }

    static func alertKey(ruleID: String, minutes: Int, now: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: now)
        return "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)|\(ruleID)|\(minutes)"
    }
}

enum AppError: LocalizedError {
    case storage, unsupportedSelection, unauthorized, unavailableApplication, activeSession, invalidDecision
    case strict, quotaReached, invalidRoutine, focusActive, hardMode
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
        case .hardMode: return "Hard Mode actif : impossible d’assouplir tes règles pour l’instant."
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
