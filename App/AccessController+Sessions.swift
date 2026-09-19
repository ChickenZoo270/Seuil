import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import IntentionCore

extension AccessController {
    /// DeviceActivity rejects intervals shorter than 15 minutes: shorter sessions pad
    /// the schedule and end from the interval end warning, which fires exactly at `end`.
    private func schedule(from start: Date, minutes: Int) -> DeviceActivitySchedule {
        let minimumMinutes = RoutineWindow.minimumMinutes
        let end = start.addingTimeInterval(TimeInterval(max(minutes, minimumMinutes) * 60))
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(components, from: start),
            intervalEnd: Calendar.current.dateComponents(components, from: end), repeats: false,
            warningTime: minutes < minimumMinutes ? DateComponents(minute: minimumMinutes - minutes) : nil)
    }

    /// Opens one app for `requested` minutes once its challenge has been passed.
    func grant(application: ApplicationToken, minutes requested: Int) throws {
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AppError.unauthorized }
        guard Policy.unlockOptions.contains(requested) else { throw AppError.invalidDecision }
        try Task.checkCancellation()
        let now = Date()
        var monitorToCancel: String?
        defer { if let monitorToCancel { center.stopMonitoring([.init(monitorToCancel)]) } }
        try SharedStorage.locked { current, save in
            guard current.session == nil else { throw AppError.activeSession }
            guard !current.isStrictlyBlocked(application, now: now) else { throw AppError.strict }
            if let index = current.rules.firstIndex(where: { $0.token == application }) {
                guard current.rules[index].remainingUnlocks(now: now) != 0 else { throw AppError.quotaReached }
                current.rules[index].unlocks = current.rules[index].unlocks.filter { $0 > now.addingTimeInterval(-2 * 86_400) } + [now]
            }
            current.markDirty(now)
            let previous = current
            let start = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970))
            let id = "intention.\(UUID().uuidString)"
            current.session = AccessSession(id: id, application: application, startedAt: now,
                                            expiresAt: start.addingTimeInterval(TimeInterval(requested * 60)), isArmed: false)
            current.pendingApplication = nil
            // Persist -> register reblocking -> unlock. Never unlock on registration failure.
            try save(current)
            do {
                monitorToCancel = id
                try center.startMonitoring(.init(id), during: schedule(from: start, minutes: requested))
                current.session?.isArmed = true
                try save(current)
            } catch {
                current = previous
                Shielding.apply(current)
                try save(current)
                throw error
            }
            Shielding.apply(current)
            monitorToCancel = nil
        }
        message = "\(requested) minutes débloquées. Retourne dans l’app."
        refresh()
    }

    func dismissPending() {
        mutate { $0.pendingApplication = nil }
    }

    func endSession() {
        let id = state.session?.id
        mutate { $0.session = nil }
        if let id { center.stopMonitoring([.init(id)]) }
        message = "Session terminée. L’app est à nouveau protégée."
    }

    /// "Block everything now" session from the timer. Strict ones cannot be unlocked.
    func startFocus(minutes: Int, name: String = "Minuteur", strict: Bool = true) {
        guard FocusMonitoring.range.contains(minutes) else { return }
        guard state.focus == nil || !state.isFocusActive(now: Date()) else { message = AppError.focusActive.localizedDescription; return }
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let id = FocusMonitoring.prefix + UUID().uuidString
        do {
            try center.startMonitoring(.init(id), during: schedule(from: start, minutes: minutes))
        } catch {
            message = error.localizedDescription
            return
        }
        let sessionID = state.session?.id
        mutate { current in
            current.focus = FocusSession(id: id, endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
                                         name: name, isStrict: strict || current.preferences.isHardModeActive(now: start))
            // Focus closes any open unlock.
            current.session = nil
        }
        if let sessionID { center.stopMonitoring([.init(sessionID)]) }
        message = "\(name) lancé : tout est bloqué pendant \(Scoring.duration(Double(minutes)))."
    }
}
