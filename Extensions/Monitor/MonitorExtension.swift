import DeviceActivity
import Foundation
import os

final class MonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "Intention", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == DailyMonitoring.activity else { return }
        // New day: every allowance is available again.
        update("Daily reset") { state in
            for index in state.rules.indices { state.rules[index].limitReachedAt = nil }
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == DailyMonitoring.activity, let id = DailyMonitoring.ruleID(from: event) else { return }
        update("Limit reached") { state in
            guard let index = state.rules.firstIndex(where: { $0.id == id }) else { return }
            state.rules[index].limitReachedAt = Date()
        }
    }

    // Sessions shorter than Apple's 15-minute minimum end at this warning.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        endSession(activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        endSession(activity)
    }

    private func endSession(_ activity: DeviceActivityName) {
        guard activity != DailyMonitoring.activity else { return }
        do {
            try SharedStorage.locked { state, save in
                // Late callbacks from previous sessions must never close a new session.
                guard state.session?.id == activity.rawValue else { return }
                state.session = nil
                SharedStorage.applyShield(state)
                try save(state)
            }
            DeviceActivityCenter().stopMonitoring([activity])
        } catch {
            logger.error("Reblocking failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func update(_ label: String, _ change: (inout SharedState) -> Void) {
        do {
            try SharedStorage.locked { state, save in
                change(&state)
                // Shield first so a failed write cannot leave a used-up app open.
                SharedStorage.applyShield(state)
                try save(state)
            }
        } catch {
            logger.error("\(label, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
