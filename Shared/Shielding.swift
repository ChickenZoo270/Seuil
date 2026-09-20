import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import UserNotifications
import IntentionCore

enum Shielding {
    /// Single source of truth for what is blocked right now: apps past their daily
    /// allowance, active routines and focus, minus the one app unlocked by a session.
    static func apply(_ state: SharedState, now: Date = Date()) {
        if state.isEmergencyActive(now: now) {
            // Emergency pass: every rule is lifted for the hour.
            AppConfiguration.store.shield.applications = nil
            AppConfiguration.store.shield.applicationCategories = nil
            return
        }
        var applications = Set(state.rules.filter { $0.isBlocked(now: now) }.map(\.token))
        applications.formUnion(state.neverAllowed)
        var categories = Set<ActivityCategoryToken>()
        for routine in state.activeRoutines {
            applications.formUnion(routine.applications)
            categories.formUnion(routine.categories)
        }
        var exceptions = state.allowedApplications.subtracting(state.neverAllowed)
        if let session = state.session, session.isArmed, session.expiresAt > now,
           session.isEmergency || !state.isStrictlyBlocked(session.application, now: now) {
            applications.remove(session.application)
            exceptions.insert(session.application)
        }
        applications.subtract(exceptions)
        let store = AppConfiguration.store
        store.shield.applications = applications.isEmpty ? nil : applications
        if state.blocksAll(now: now) {
            store.shield.applicationCategories = .all(except: exceptions)
        } else {
            store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: exceptions)
        }
    }

    /// Routine states from the clock. Used when the app opens and on every routine
    /// callback, so a late, early or missing boundary callback cannot leave a wrong state.
    static func reconcileRoutines(_ state: inout SharedState, at date: Date = Date()) {
        state.activeRoutineIDs = Set(state.routines.filter { $0.isEnabled && $0.window.isActive(at: date) }.map(\.id))
    }
}

/// Daily allowances and usage reminders use the same mechanism as Screen Time limits:
/// one repeating day-long activity with usage threshold events per app.
enum DailyMonitoring {
    static let activity = DeviceActivityName("seuil.daily")
    private static let limitPrefix = "limit."
    private static let alertPrefix = "alert."

    enum Event {
        case limit(ruleID: String)
        case alert(ruleID: String, minutes: Int)
    }

    static func parse(_ event: DeviceActivityEvent.Name) -> Event? {
        let raw = event.rawValue
        if raw.hasPrefix(limitPrefix) { return .limit(ruleID: String(raw.dropFirst(limitPrefix.count))) }
        guard raw.hasPrefix(alertPrefix) else { return nil }
        let parts = raw.dropFirst(alertPrefix.count).split(separator: "|")
        guard parts.count == 2, let minutes = Int(parts[1]) else { return nil }
        return .alert(ruleID: String(parts[0]), minutes: minutes)
    }

    static func restart(for state: SharedState, center: DeviceActivityCenter = DeviceActivityCenter()) throws {
        center.stopMonitoring([activity])
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for rule in state.rules {
            if rule.dailyMinutes > 0 {
                events[.init(limitPrefix + rule.id)] = event(for: rule.token, minutes: rule.dailyMinutes)
            }
            guard state.preferences.usageAlerts else { continue }
            for minutes in state.preferences.autofocusThresholds where rule.dailyMinutes == 0 || minutes < rule.dailyMinutes {
                events[.init("\(alertPrefix)\(rule.id)|\(minutes)")] = event(for: rule.token, minutes: minutes)
            }
        }
        guard !events.isEmpty else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true)
        try center.startMonitoring(activity, during: schedule, events: events)
    }

    // Past activity counts so that changing a limit mid-day keeps today's usage.
    private static func event(for token: ApplicationToken, minutes: Int) -> DeviceActivityEvent {
        DeviceActivityEvent(applications: [token], threshold: DateComponents(minute: minutes), includesPastActivity: true)
    }
}

/// Routines are registered as repeating daily activities that never cross midnight
/// (DeviceActivity handles that boundary poorly). An overnight routine gets two parts.
/// Parts shorter than Apple's 15-minute minimum are padded and signal their real
/// boundary through the interval warning. Every callback re-evaluates routines from
/// the clock, so the weekday and boundaries are always derived from `RoutineWindow`.
enum RoutineMonitoring {
    private static let prefix = "routine."

    static func isRoutineActivity(_ activity: DeviceActivityName) -> Bool { activity.rawValue.hasPrefix(prefix) }

    static func restart(for routines: [Routine], center: DeviceActivityCenter = DeviceActivityCenter()) throws {
        center.stopMonitoring(center.activities.filter(isRoutineActivity))
        for routine in routines where routine.isEnabled && routine.window.isValid && !routine.isEmpty {
            for part in routine.window.scheduleParts {
                let schedule = DeviceActivitySchedule(
                    intervalStart: components(part.startMinute, isEnd: false),
                    intervalEnd: components(part.endMinute, isEnd: true),
                    repeats: true,
                    warningTime: part.warningMinutes > 0 ? DateComponents(minute: part.warningMinutes) : nil)
                try center.startMonitoring(.init("\(prefix)\(routine.id).\(part.suffix)"), during: schedule)
            }
        }
    }

    static func isRegistered(_ routines: [Routine], center: DeviceActivityCenter) -> Bool {
        let expected = routines.contains { $0.isEnabled && $0.window.isValid && !$0.isEmpty }
        return !expected || center.activities.contains(where: isRoutineActivity)
    }

    /// DeviceActivity cannot express 24:00: the end of the day is 23:59:59.
    private static func components(_ minute: Int, isEnd: Bool) -> DateComponents {
        if isEnd && minute >= RoutineWindow.dayMinutes { return DateComponents(hour: 23, minute: 59, second: 59) }
        return DateComponents(hour: minute / 60, minute: minute % 60, second: 0)
    }
}

enum FocusMonitoring {
    static let prefix = "focus."
    static let emergencyPrefix = "emergency."
    /// From a quick pause to a full day of digital detox.
    static let range = 5...(24 * 60)
}

enum Notifier {
    static func post(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
