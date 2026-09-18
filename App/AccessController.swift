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
                    if !session.isArmed {
                        current.receipts.removeAll { $0.startedAt == session.startedAt }
                    }
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
        } catch { message = "Impossible de charger la protection : \(error.localizedDescription)" }
    }

    func protect(_ selection: FamilyActivitySelection) {
        do {
            guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AppError.unauthorized }
            guard selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else { throw AppError.unsupportedSelection }
            try SharedStorage.locked { current, save in
                guard current.session == nil else { throw AppError.activeSession }
                current.applications = selection.applicationTokens
                current.pendingApplication = nil
                try save(current)
                SharedStorage.applyShield(current)
            }
            message = "Protection mise à jour."
            refresh()
        } catch { message = error.localizedDescription }
    }

    func grant(application: ApplicationToken, assessment: Assessment) throws {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AppError.unauthorized }
        try Task.checkCancellation()
        let now = Date()
        var monitorToCancel: String?
        defer { if let monitorToCancel { center.stopMonitoring([.init(monitorToCancel)]) } }
        try SharedStorage.locked { current, save in
            guard current.applications.contains(application) else { throw AppError.unavailableApplication }
            guard current.session == nil else { throw AppError.activeSession }
            let decision = Policy.decide(assessment, usedMinutes: Budget.used(current.receipts, now: now), hasSession: false)
            guard case .allow(let minutes) = decision else {
                if decision == .budgetExhausted { throw AppError.budget }
                throw AppError.invalidDecision
            }
            let previous = current
            // Whole seconds ensure a schedule of exactly 900 seconds (Apple minimum).
            let start = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970))
            let end = start.addingTimeInterval(TimeInterval(minutes * 60))
            let id = "intention.\(UUID().uuidString)"
            let calendar = Calendar.current
            let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let schedule = DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(components, from: start),
                intervalEnd: calendar.dateComponents(components, from: end), repeats: false)
            current.session = AccessSession(id: id, application: application, startedAt: now, expiresAt: end, isArmed: false)
            current.receipts.removeAll { $0.startedAt <= now.addingTimeInterval(-86_400) }
            current.receipts.append(Receipt(startedAt: now, minutes: minutes))
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
        message = "15 minutes accordées. Tu peux retourner dans l’app choisie."
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
            // Stop before refresh, even when persistence failed (see defer above).
            if let id = monitorToStop { center.stopMonitoring([.init(id)]); monitorToStop = nil }
            message = "Session terminée. Les apps sont à nouveau bloquées."
            refresh()
        } catch { message = error.localizedDescription }
    }
}
