import Foundation
import UserNotifications
import IntentionCore

/// Local notifications scheduled from the app: routine starts, daily report, streak
/// nudges and the "we have not seen you" reminder. Usage and limit alerts come from
/// the monitor extension instead, because only it sees usage.
enum NotificationScheduler {
    private static let managedPrefix = "seuil.scheduled."
    static let inactivityDays = 3
    static let reportHour = 21
    static let streakHour = 9

    static func once(id: String, after seconds: TimeInterval, title: String, body: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        add(id: id, title: title, body: body, trigger: trigger)
    }

    /// Replaces every repeating notification from the current preferences and routines.
    static func reschedule(state: SharedState) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(managedPrefix) })
            let preferences = state.preferences
            if preferences.serviceNotifications {
                for routine in state.routines where routine.isEnabled && routine.window.isValid {
                    for weekday in routine.window.weekdays {
                        var parts = DateComponents()
                        parts.weekday = weekday
                        parts.hour = routine.window.startMinute / 60
                        parts.minute = routine.window.startMinute % 60
                        add(id: "\(managedPrefix)routine.\(routine.id).\(weekday)",
                            title: "\(routine.name) commence",
                            body: "Tes apps distrayantes sont bloquées jusqu’à \(RoutineWindow.timeLabel(routine.window.endMinute)).",
                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true))
                    }
                }
            }
            if preferences.dailyReport {
                add(id: "\(managedPrefix)report", title: "Ton score du jour est prêt",
                    body: "Regarde comment s’est passée ta journée côté écran.",
                    trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reportHour), repeats: true))
            }
            if preferences.streakNotifications {
                add(id: "\(managedPrefix)streak", title: "Garde ta flamme allumée 🔥",
                    body: "Une journée sans déblocage ni limite dépassée, et ta série continue.",
                    trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: streakHour), repeats: true))
            }
            if preferences.reminders {
                add(id: "\(managedPrefix)inactive", title: "On ne t’a pas vu depuis un moment",
                    body: "Tes règles tournent toujours. Passe voir ton score et ta série.",
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(inactivityDays * 86_400), repeats: false))
            }
        }
    }

    private static func add(id: String, title: String, body: String, trigger: UNNotificationTrigger) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
