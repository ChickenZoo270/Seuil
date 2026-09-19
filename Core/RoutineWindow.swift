import Foundation

/// Recurring time window of a routine, like Screen Time's downtime.
/// Weekdays follow `Calendar`: 1 = Sunday … 7 = Saturday.
public struct RoutineWindow: Codable, Equatable, Sendable {
    public static let minimumMinutes = 15
    public static let dayMinutes = 24 * 60
    public static let allWeekdays: Set<Int> = Set(1...7)

    public var startMinute: Int
    public var endMinute: Int
    public var weekdays: Set<Int>

    public init(startMinute: Int, endMinute: Int, weekdays: Set<Int>) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public var crossesMidnight: Bool { endMinute < startMinute }

    public var durationMinutes: Int {
        crossesMidnight ? 24 * 60 - startMinute + endMinute : endMinute - startMinute
    }

    /// Apple refuses schedules shorter than 15 minutes.
    public var isValid: Bool {
        !weekdays.isEmpty && weekdays.isSubset(of: Self.allWeekdays)
            && (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute)
            && durationMinutes >= Self.minimumMinutes
    }

    /// An overnight window belongs to the weekday it starts on.
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isValid else { return false }
        let parts = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let hour = parts.hour, let minute = parts.minute, let weekday = parts.weekday else { return false }
        let now = hour * 60 + minute
        if !crossesMidnight {
            return weekdays.contains(weekday) && now >= startMinute && now < endMinute
        }
        if now >= startMinute { return weekdays.contains(weekday) }
        if now < endMinute { return weekdays.contains(weekday == 1 ? 7 : weekday - 1) }
        return false
    }

    public static func timeLabel(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    public var summary: String {
        "\(Self.timeLabel(startMinute)) – \(Self.timeLabel(endMinute)) · \(Self.daysLabel(weekdays))"
    }

    public static let shortDayNames = [1: "Dim", 2: "Lun", 3: "Mar", 4: "Mer", 5: "Jeu", 6: "Ven", 7: "Sam"]
    /// Monday-first order for display.
    public static let displayOrder = [2, 3, 4, 5, 6, 7, 1]

    public static func daysLabel(_ days: Set<Int>) -> String {
        if days == allWeekdays { return "Tous les jours" }
        if days == [2, 3, 4, 5, 6] { return "En semaine" }
        if days == [1, 7] { return "Le week-end" }
        return displayOrder.filter(days.contains).compactMap { shortDayNames[$0] }.joined(separator: " ")
    }

    /// A midnight-free piece of the window as registered with DeviceActivity.
    public struct SchedulePart: Equatable, Sendable {
        public let suffix: String
        public let startMinute: Int
        /// `dayMinutes` means the end of the day (23:59:59).
        public let endMinute: Int
        /// Minutes before the scheduled end at which the real boundary happens (0 = none).
        public let warningMinutes: Int
    }

    /// DeviceActivity handles midnight poorly and refuses intervals under 15 minutes:
    /// overnight windows are split at midnight, and a short piece is padded while its
    /// interval warning fires at the real boundary. The end of day is 23:59:59, one
    /// second short of a whole minute, hence the extra minute of padding there.
    public var scheduleParts: [SchedulePart] {
        let minimum = Self.minimumMinutes, day = Self.dayMinutes
        guard crossesMidnight else {
            return [SchedulePart(suffix: "a", startMinute: startMinute, endMinute: endMinute, warningMinutes: 0)]
        }
        var parts: [SchedulePart] = []
        let eveningLength = day - startMinute
        if eveningLength > minimum {
            parts.append(SchedulePart(suffix: "a", startMinute: startMinute, endMinute: day, warningMinutes: 0))
        } else {
            parts.append(SchedulePart(suffix: "a", startMinute: day - minimum - 1, endMinute: day, warningMinutes: eveningLength))
        }
        if endMinute > 0 {
            let end = max(endMinute, minimum)
            parts.append(SchedulePart(suffix: "b", startMinute: 0, endMinute: end, warningMinutes: end - endMinute))
        }
        return parts
    }
}
