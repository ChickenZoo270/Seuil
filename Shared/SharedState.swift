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

struct SharedState: Codable {
    var applications: Set<ApplicationToken> = []
    var session: AccessSession?
    var receipts: [Receipt] = []
    var pendingApplication: ApplicationToken?
}

enum AppError: LocalizedError {
    case storage, unsupportedSelection, unauthorized, unavailableApplication, activeSession, budget, invalidDecision
    var errorDescription: String? {
        switch self {
        case .storage: return "Le stockage partagé est inaccessible. Vérifie la configuration App Groups."
        case .unsupportedSelection: return "Sélectionne uniquement des apps individuelles, sans catégorie ni site web."
        case .unauthorized: return "Autorise d’abord l’accès à Temps d’écran."
        case .unavailableApplication: return "Choisis une app dans ta liste protégée."
        case .activeSession: return "Une session est déjà en cours. Termine-la avant de continuer."
        case .budget: return "Les 45 minutes disponibles sur les dernières 24 heures sont utilisées."
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

    static func applyShield(_ state: SharedState, now: Date = Date()) {
        var blocked = state.applications
        if let session = state.session, session.isArmed, session.expiresAt > now { blocked.remove(session.application) }
        AppConfiguration.store.shield.applications = blocked.isEmpty ? nil : blocked
    }
}
