import Foundation
import FamilyControls
import ManagedSettings
import IntentionCore

extension AccessController {
    /// Apps shielded right now, for the "Apps bloquées" row.
    var blockedApplications: [ApplicationToken] {
        let now = Date()
        var tokens = state.rules.filter { $0.isBlocked(now: now) }.map(\.token)
        tokens += state.neverAllowed
        for routine in state.activeRoutines { tokens += routine.applications }
        if let session = state.session, session.expiresAt > now { tokens.removeAll { $0 == session.application } }
        var seen = Set<ApplicationToken>()
        return tokens.filter { !state.allowedApplications.contains($0) && seen.insert($0).inserted }
    }

    var isHardModeActive: Bool { state.preferences.isHardModeActive(now: Date()) }

    func setAllowedApplications(_ tokens: Set<ApplicationToken>) {
        if isHardModeActive, !tokens.isSubset(of: state.allowedApplications) {
            message = AppError.hardMode.localizedDescription
            return
        }
        mutate { $0.allowedApplications = tokens }
    }

    func setNeverAllowed(_ tokens: Set<ApplicationToken>) {
        if isHardModeActive, !state.neverAllowed.isSubset(of: tokens) {
            message = AppError.hardMode.localizedDescription
            return
        }
        mutate { $0.neverAllowed = tokens }
    }

    /// Hard Mode starts at once; switching it off takes effect after 24 hours.
    func setHardMode(_ enabled: Bool) {
        let cooling: TimeInterval = 24 * 3600
        mutate { current in
            if enabled {
                current.preferences.hardMode = true
                current.preferences.hardModeOffAt = nil
            } else if current.preferences.hardMode, current.preferences.hardModeOffAt == nil {
                current.preferences.hardModeOffAt = Date().addingTimeInterval(cooling)
            }
        }
        message = enabled ? "Hard Mode activé. Aucun déblocage possible." : "Hard Mode se désactivera dans 24 h."
    }

    /// Clears Hard Mode once its cooling-off delay has passed.
    func settleHardMode() {
        guard state.preferences.hardMode, let offAt = state.preferences.hardModeOffAt, offAt <= Date() else { return }
        mutate { current in
            current.preferences.hardMode = false
            current.preferences.hardModeOffAt = nil
        }
    }

    var isEmergencyPassAvailable: Bool {
        EmergencyPass.isAvailable(lastUsed: state.preferences.emergencyPassUsedAt, now: Date())
    }

    /// Re-applies every shield and re-registers all monitoring, for when something looks stuck.
    func reload() {
        do {
            try restartMonitoring(state)
            Shielding.apply(state)
            refresh()
            NotificationScheduler.reschedule(state: state)
            message = "Seuil rechargé : règles et blocages réappliqués."
        } catch { message = error.localizedDescription }
    }

    func updatePreferences(_ change: (inout Preferences) -> Void) {
        var preferences = state.preferences
        change(&preferences)
        setPreferences(preferences)
        NotificationScheduler.reschedule(state: state)
    }

    /// In Hard Mode, limits can only get tighter.
    func allowsLoosening() -> Bool { !isHardModeActive }
}
