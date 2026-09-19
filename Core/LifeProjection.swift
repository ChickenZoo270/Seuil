import Foundation

/// Onboarding wake-up call: what today's screen time adds up to over a lifetime.
public enum LifeProjection {
    public static let lifeExpectancy = 80
    public static let awakeHoursPerDay = 16.0
    /// Reduction Seuil aims for once distracting apps are locked.
    public static let targetReduction = 0.4

    public static func remainingYears(age: Int) -> Int { max(0, lifeExpectancy - age) }

    /// Full years of life spent on the phone from now on.
    public static func yearsOnPhone(hoursPerDay: Double, age: Int) -> Double {
        let hours = min(max(hoursPerDay, 0), 24)
        return hours / 24 * Double(remainingYears(age: age))
    }

    /// Share of waking time, e.g. 0.25 for 4 hours a day.
    public static func awakeShare(hoursPerDay: Double) -> Double {
        min(max(hoursPerDay, 0), awakeHoursPerDay) / awakeHoursPerDay
    }

    public static func yearsSaved(hoursPerDay: Double, age: Int, reduction: Double = targetReduction) -> Double {
        yearsOnPhone(hoursPerDay: hoursPerDay, age: age) * min(max(reduction, 0), 1)
    }

    public static func daysPerYear(hoursPerDay: Double) -> Int {
        Int((min(max(hoursPerDay, 0), 24) * 365 / 24).rounded())
    }

    public static func format(years: Double) -> String {
        let rounded = (years * 10).rounded() / 10
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
        return rounded >= 2 ? "\(text) ans" : "\(text) an"
    }
}
