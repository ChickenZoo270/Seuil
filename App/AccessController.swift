import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity
import IntentionCore

@MainActor
final class AccessController: ObservableObject {
    @Published private(set) var state = SharedState()
    @Published var message = ""
    @Published private(set) var authorized = false
    private let center = DeviceActivityCenter()

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
            try DailyMonitoring.restart(for: state.rules, center: center)
        } catch { message = error.localizedDescription }
    }

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        do {
            var expired: String?
            state = try SharedStorage.locked { current, save in
                if let session = current.session,
                   !session.isArmed || session.expiresAt <= Date() || !center.activities.contains(.init(session.id)) {
                    expired = session.id
                    // Reblock before persisting so write failure cannot leave access open.
                    current.session = nil
                    SharedStorage.applyShield(current)
                    try save(current)
                } else if authorized {
                    SharedStorage.applyShield(current)
                }
                return current
            }
            if let expired { center.stopMonitoring([.init(expired)]) }
            if authorized, state.rules.contains(where: { $0.dailyMinutes > 0 }),
               !center.activities.contains(DailyMonitoring.activity) {
                try DailyMonitoring.restart(for: state.rules, center: center)
            }
        } catch { message = "Impossible de charger la protection : \(error.localizedDescription)" }
    }

    /// Keeps each existing app's allowance; newly picked apps start with the default.
    func protect(_ selection: FamilyActivitySelection) {
        do {
            guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AppError.unauthorized }
            guard selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else { throw AppError.unsupportedSelection }
            try SharedStorage.locked { current, save in
                guard current.session == nil else { throw AppError.activeSession }
                let picked = selection.applicationTokens
                let kept = current.rules.filter { picked.contains($0.token) }
                let added = picked.subtracting(kept.map(\.token))
                    .map { AppRule(token: $0, dailyMinutes: Policy.defaultDailyLimitMinutes) }
                current.rules = kept + added
                current.pendingApplication = nil
                SharedStorage.applyShield(current)
                try save(current)
                try DailyMonitoring.restart(for: current.rules, center: center)
            }
            message = "Protection mise à jour."
            refresh()
        } catch { message = error.localizedDescription }
    }

    func setDailyLimit(_ minutes: Int, for token: ApplicationToken) {
        guard Policy.dailyLimitOptions.contains(minutes) else { return }
        do {
            try SharedStorage.locked { current, save in
                guard let index = current.rules.firstIndex(where: { $0.token == token }) else { throw AppError.unavailableApplication }
                current.rules[index].dailyMinutes = minutes
                // Re-evaluated from today's real usage when monitoring restarts.
                current.rules[index].limitReachedAt = nil
                SharedStorage.applyShield(current)
                try save(current)
                try DailyMonitoring.restart(for: current.rules, center: center)
            }
            refresh()
        } catch { message = error.localizedDescription }
    }

    func grant(application: ApplicationToken, assessment: Assessment, minutes requested: Int) throws {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AppError.unauthorized }
        try Task.checkCancellation()
        let now = Date()
        var monitorToCancel: String?
        defer { if let monitorToCancel { center.stopMonitoring([.init(monitorToCancel)]) } }
        var granted = 0
        try SharedStorage.locked { current, save in
            guard current.applications.contains(application) else { throw AppError.unavailableApplication }
            guard current.session == nil else { throw AppError.activeSession }
            guard case .allow(let minutes) = Policy.decide(assessment, requestedMinutes: requested, hasSession: false) else {
                throw AppError.invalidDecision
            }
            granted = minutes
            let previous = current
            let start = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970))
            let end = start.addingTimeInterval(TimeInterval(minutes * 60))
            let id = "intention.\(UUID().uuidString)"
            let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            // DeviceActivity rejects intervals shorter than 15 minutes: shorter sessions pad
            // the schedule and reblock from the end warning, which fires exactly at `end`.
            let minimumMinutes = 15
            let scheduleEnd = max(end, start.addingTimeInterval(TimeInterval(minimumMinutes * 60)))
            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(components, from: start),
                intervalEnd: Calendar.current.dateComponents(components, from: scheduleEnd), repeats: false,
                warningTime: minutes < minimumMinutes ? DateComponents(minute: minimumMinutes - minutes) : nil)
            current.session = AccessSession(id: id, application: application, startedAt: now, expiresAt: end, isArmed: false)
            current.pendingApplication = nil
            // Persist -> register reblocking -> unlock. Never unlock on registration failure.
            try save(current)
            do {
                monitorToCancel = id
                try center.startMonitoring(.init(id), during: schedule)
                current.session?.isArmed = true
                try save(current)
            } catch {
                current = previous
                SharedStorage.applyShield(current)
                try save(current)
                throw error
            }
            SharedStorage.applyShield(current)
            monitorToCancel = nil
        }
        message = "\(granted) minutes accordées. Retourne dans l’app choisie."
        refresh()
    }

    func dismissPending() {
        try? SharedStorage.locked { current, save in
            current.pendingApplication = nil
            try save(current)
        }
        refresh()
    }

    func endSession() {
        var monitorToStop: String?
        defer { if let monitorToStop { center.stopMonitoring([.init(monitorToStop)]) } }
        do {
            try SharedStorage.locked { current, save in
                monitorToStop = current.session?.id
                current.session = nil
                SharedStorage.applyShield(current)
                try save(current)
            }
            if let id = monitorToStop { center.stopMonitoring([.init(id)]); monitorToStop = nil }
            message = "Session terminée. L’app est à nouveau protégée."
            refresh()
        } catch { message = error.localizedDescription }
    }
}
