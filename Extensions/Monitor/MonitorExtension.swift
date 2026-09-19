import DeviceActivity
import Foundation
import os
import IntentionCore

final class MonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "Intention", category: "Monitor")
    /// Callbacks can arrive slightly before the scheduled minute.
    private let clockTolerance: TimeInterval = 120

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Daily allowances need no reset: a limit only counts on the day it was reached.
        if RoutineMonitoring.isRoutineActivity(activity) { reconcileRoutines() }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == DailyMonitoring.activity, let parsed = DailyMonitoring.parse(event) else { return }
        switch parsed {
        case .limit(let ruleID):
            update("Limit reached") { state in
                guard let index = state.rules.firstIndex(where: { $0.id == ruleID }) else { return }
                state.rules[index].limitReachedAt = Date()
                state.markDirty(Date())
                if state.preferences.limitNotifications {
                    let app = state.rules[index].name ?? "une app"
                    Notifier.post(title: "Limite atteinte",
                                  body: "Ton temps libre sur \(app) est écoulé pour aujourd’hui. Chaque ouverture se mérite désormais.",
                                  id: "limit.\(ruleID)")
                }
            }
        case .alert(let ruleID, let minutes):
            var message: (title: String, body: String)?
            update("Usage alert") { state in
                let key = SharedState.alertKey(ruleID: ruleID, minutes: minutes, now: Date())
                let today = String(key.split(separator: "|")[0])
                // Past usage can fire several thresholds at once: only the highest one speaks.
                let higherSent = state.sentAlerts.contains { sent in
                    let parts = sent.split(separator: "|")
                    return parts.count == 3 && parts[0] == Substring(today) && parts[1] == Substring(ruleID)
                        && (Int(parts[2]) ?? 0) > minutes
                }
                guard state.preferences.usageAlerts, !state.sentAlerts.contains(key), !higherSent,
                      let rule = state.rules.first(where: { $0.id == ruleID }) else { return }
                state.sentAlerts = state.sentAlerts.filter { $0.hasPrefix(today + "|") } + [key]
                message = UsageAlert.message(minutes: minutes, appName: rule.name)
            }
            if let message { Notifier.post(title: message.title, body: message.body, id: "alert.\(ruleID).\(minutes)") }
        }
    }

    // Sessions shorter than Apple's 15-minute minimum end at this warning;
    // padded routine parts reach their real boundary here too.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        if RoutineMonitoring.isRoutineActivity(activity) { reconcileRoutines() } else { endTemporary(activity) }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if RoutineMonitoring.isRoutineActivity(activity) { reconcileRoutines() } else { endTemporary(activity) }
    }

    /// Boundary callbacks can come slightly early or late: judge from just after now.
    private func reconcileRoutines() {
        update("Routine boundary") { state in
            Shielding.reconcileRoutines(&state, at: Date().addingTimeInterval(clockTolerance))
        }
    }

    /// Ends an unlock session or a focus session registered under this activity.
    private func endTemporary(_ activity: DeviceActivityName) {
        guard activity != DailyMonitoring.activity else { return }
        var matched = false
        update("Session end") { state in
            // Late callbacks from previous sessions must never close a new one.
            if state.session?.id == activity.rawValue { state.session = nil; matched = true }
            if state.focus?.id == activity.rawValue { state.focus = nil; matched = true }
        }
        if matched { DeviceActivityCenter().stopMonitoring([activity]) }
    }

    private func update(_ label: String, _ change: (inout SharedState) -> Void) {
        do {
            try SharedStorage.locked { state, save in
                change(&state)
                // Shield first so a failed write cannot leave a blocked app open.
                Shielding.apply(state)
                try save(state)
            }
        } catch {
            logger.error("\(label, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
