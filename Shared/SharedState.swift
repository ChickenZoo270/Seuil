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

/// One protected app: its daily allowance and whether it was used up today.
struct AppRule: Codable, Identifiable {
    let id: String
    let token: ApplicationToken
    var dailyMinutes: Int
    var limitReachedAt: Date?

    init(token: ApplicationToken, dailyMinutes: Int) {
        id = UUID().uuidString
        self.token = token
        self.dailyMinutes = dailyMinutes
    }

    func isBlocked(now: Date) -> Bool {
        dailyMinutes == 0 || DailyLimit.isReached(reachedAt: limitReachedAt, now: now)
    }
}

struct SharedState: Codable {
    var rules: [AppRule] = []
    var session: AccessSession?
    var pendingApplication: ApplicationToken?

    var applications: Set<ApplicationToken> { Set(rules.map(\.token)) }

    func rule(for token: ApplicationToken) -> AppRule? { rules.first { $0.token == token } }

    init() {}

    private enum CodingKeys: String, CodingKey { case rules, session, pendingApplication, applications }

    // Version 1 stored a bare set of always-blocked apps; keep them blocked after the update.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decodeIfPresent(AccessSession.self, forKey: .session)
        pendingApplication = try container.decodeIfPresent(ApplicationToken.self, forKey: .pendingApplication)
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
        try container.encodeIfPresent(session, forKey: .session)
        try container.encodeIfPresent(pendingApplication, forKey: .pendingApplication)
    }
}

enum AppError: LocalizedError {
    case storage, unsupportedSelection, unauthorized, unavailableApplication, activeSession, invalidDecision
    var errorDescription: String? {
        switch self {
        case .storage: return "Le stockage partagé est inaccessible. Vérifie la configuration App Groups."
        case .unsupportedSelection: return "Sélectionne uniquement des apps individuelles, sans catégorie ni site web."
        case .unauthorized: return "Autorise d’abord l’accès à Temps d’écran."
        case .unavailableApplication: return "Choisis une app dans ta liste protégée."
        case .activeSession: return "Une session est déjà en cours. Termine-la avant de continuer."
        case .invalidDecision: return "Cette intention n’a pas reçu d’autorisation."
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

    static func snapshot() throws -> SharedState { try locked { state, _ in state } }

    /// Shields apps that always ask for a reason or used up today's allowance,
    /// except the one app currently unlocked by an armed session.
    static func applyShield(_ state: SharedState, now: Date = Date()) {
        var blocked = Set(state.rules.filter { $0.isBlocked(now: now) }.map(\.token))
        if let session = state.session, session.isArmed, session.expiresAt > now { blocked.remove(session.application) }
        AppConfiguration.store.shield.applications = blocked.isEmpty ? nil : blocked
    }
}

/// Daily allowances use the same mechanism as Screen Time limits: one repeating
/// day-long activity with a usage threshold event per limited app.
enum DailyMonitoring {
    static let activity = DeviceActivityName("seuil.daily")
    static let eventPrefix = "limit."

    static func eventName(for rule: AppRule) -> DeviceActivityEvent.Name { .init(eventPrefix + rule.id) }

    static func ruleID(from event: DeviceActivityEvent.Name) -> String? {
        let raw = event.rawValue
        return raw.hasPrefix(eventPrefix) ? String(raw.dropFirst(eventPrefix.count)) : nil
    }

    static func restart(for rules: [AppRule], center: DeviceActivityCenter = DeviceActivityCenter()) throws {
        center.stopMonitoring([activity])
        let limited = rules.filter { $0.dailyMinutes > 0 }
        guard !limited.isEmpty else { return }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for rule in limited {
            // Past activity counts so that changing a limit mid-day keeps today's usage.
            events[eventName(for: rule)] = DeviceActivityEvent(
                applications: [rule.token],
                threshold: DateComponents(minute: rule.dailyMinutes),
                includesPastActivity: true)
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true)
        try center.startMonitoring(activity, during: schedule, events: events)
    }
}
