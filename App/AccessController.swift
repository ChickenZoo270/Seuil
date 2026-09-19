import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import IntentionCore

@MainActor
final class AccessController: ObservableObject {
    @Published private(set) var state = SharedState()
    @Published var message = ""
    @Published private(set) var authorized = false
    @Published private(set) var notificationsAllowed = false
    let center = DeviceActivityCenter()

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await requestNotifications()
            refresh()
            try restartMonitoring(state)
        } catch { message = error.localizedDescription }
    }

    func requestNotifications() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notificationsAllowed = granted
    }

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        defer { settleHardMode() }
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsAllowed = settings.authorizationStatus == .authorized
        }
        do {
            var finished: [String] = []
            state = try SharedStorage.locked { current, save in
                let now = Date()
                if let session = current.session,
                   !session.isArmed || session.expiresAt <= now || !center.activities.contains(.init(session.id)) {
                    finished.append(session.id)
                    current.session = nil
                }
                if let focus = current.focus, focus.endsAt <= now {
                    finished.append(focus.id)
                    current.focus = nil
                }
                let previousRoutines = current.activeRoutineIDs
                Shielding.reconcileRoutines(&current, at: now)
                if authorized {
                    // Reblock before persisting so write failure cannot leave access open.
                    Shielding.apply(current, now: now)
                }
                if !finished.isEmpty || previousRoutines != current.activeRoutineIDs { try save(current) }
                return current
            }
            if !finished.isEmpty { center.stopMonitoring(finished.map { .init($0) }) }
            if authorized, !state.rules.isEmpty, !center.activities.contains(DailyMonitoring.activity) {
                try DailyMonitoring.restart(for: state, center: center)
            }
            if authorized, !RoutineMonitoring.isRegistered(state.routines, center: center) {
                try RoutineMonitoring.restart(for: state.routines, center: center)
            }
        } catch { message = "Impossible de charger la protection : \(error.localizedDescription)" }
    }

    /// Applies a change under the file lock, reshields, then re-registers monitoring.
    /// `restart` re-registers monitoring; only needed when apps, limits, routines or alerts change.
    func mutate(restart: Bool = false, _ change: (inout SharedState) throws -> Void) {
        do {
            let updated = try SharedStorage.locked { current, save in
                try change(&current)
                Shielding.reconcileRoutines(&current)
                Shielding.apply(current)
                try save(current)
                return current
            }
            if restart {
                try restartMonitoring(updated)
                NotificationScheduler.reschedule(state: updated)
            }
            refresh()
        } catch { message = error.localizedDescription }
    }

    func restartMonitoring(_ state: SharedState) throws {
        try DailyMonitoring.restart(for: state, center: center)
        try RoutineMonitoring.restart(for: state.routines, center: center)
    }

    // MARK: Protected apps

    /// Keeps each existing app's settings; newly picked apps start with the default allowance.
    func protect(_ selection: FamilyActivitySelection) {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { message = AppError.unauthorized.localizedDescription; return }
        guard selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else {
            message = AppError.unsupportedSelection.localizedDescription
            return
        }
        mutate(restart: true) { current in
            let picked = selection.applicationTokens
            let kept = current.rules.filter { picked.contains($0.token) }
            let added = picked.subtracting(kept.map(\.token))
                .map { AppRule(token: $0, dailyMinutes: Policy.defaultDailyLimitMinutes) }
            current.rules = kept + added
            current.pendingApplication = nil
        }
        message = "Protection mise à jour."
    }

    func setDailyLimit(_ minutes: Int, for token: ApplicationToken) {
        guard Policy.dailyLimitOptions.contains(minutes) else { return }
        if isHardModeActive, let old = state.rule(for: token)?.dailyMinutes,
           !(minutes == 0 || (old > 0 && minutes < old)) {
            message = AppError.hardMode.localizedDescription
            return
        }
        updateRule(token) { rule in
            rule.dailyMinutes = minutes
            // Re-evaluated from today's real usage when monitoring restarts.
            rule.limitReachedAt = nil
        }
    }

    func setMaxUnlocks(_ count: Int, for token: ApplicationToken) {
        guard UnlockQuota.options.contains(count) else { return }
        if isHardModeActive, let old = state.rule(for: token)?.maxUnlocks,
           !(count != 0 && (old == 0 || count < old)) {
            message = AppError.hardMode.localizedDescription
            return
        }
        updateRule(token) { $0.maxUnlocks = count }
    }

    private func updateRule(_ token: ApplicationToken, _ change: @escaping (inout AppRule) -> Void) {
        mutate(restart: true) { current in
            guard let index = current.rules.firstIndex(where: { $0.token == token }) else { throw AppError.unavailableApplication }
            change(&current.rules[index])
        }
    }

    func setPreferences(_ preferences: Preferences) {
        let alertsChanged = preferences.usageAlerts != state.preferences.usageAlerts
            || preferences.autofocusFrequency != state.preferences.autofocusFrequency
        mutate(restart: alertsChanged) { $0.preferences = preferences }
        if alertsChanged, preferences.usageAlerts { Task { await requestNotifications() } }
    }
}
