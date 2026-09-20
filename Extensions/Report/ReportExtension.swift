import DeviceActivity
import ManagedSettings
import SwiftUI
import IntentionCore

extension DeviceActivityReport.Context {
    static let home = Self("home")
    static let detail = Self("detail")
    static let breakdown = Self("breakdown")
}

@main
struct SeuilReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        HomeReport { HomeReportView(model: $0) }
        DetailReport { DetailReportView(model: $0) }
        BreakdownReport { BreakdownReportView(model: $0) }
    }
}

struct AppUsage: Identifiable {
    let id: String
    let name: String
    let token: ApplicationToken?
    let minutes: Double
    let isDistracting: Bool
}

struct ReportModel {
    var usage = DayUsage(hourlyMinutes: [], distractingMinutes: 0, pickups: 0, unlocks: 0, currentHour: 0)
    var apps: [AppUsage] = []
    /// Day-over-day trend for the Home header arrow. The extension only ever sees
    /// today's activity segments, so there is no honest source for this yet; it
    /// stays nil (ScoreHeader hides the arrow) rather than showing a fake direction.
    var trendUp: Bool?
    var scores: DailyScores { Scoring.scores(usage) }
}

/// Reads today's Screen Time data. Only this extension may see usage and app names;
/// nothing leaves it, so the scores are computed and drawn here.
enum ReportBuilder {
    static func build(_ data: DeviceActivityResults<DeviceActivityData>) async -> ReportModel {
        let state = try? SharedStorage.snapshot()
        let distracting = (state?.applications ?? []).union(state?.neverAllowed ?? [])
        let now = Date()
        var hourly = Array(repeating: 0.0, count: 24)
        var pickups = 0
        var perApp: [String: AppUsage] = [:]
        let calendar = Calendar.current
        for await device in data {
            for await segment in device.activitySegments {
                let hour = calendar.component(.hour, from: segment.dateInterval.start)
                hourly[hour] += segment.totalActivityDuration / 60
                for await category in segment.categories {
                    for await activity in category.applications {
                        pickups += activity.numberOfPickups
                        let app = activity.application
                        let key = app.bundleIdentifier ?? app.localizedDisplayName ?? UUID().uuidString
                        let minutes = activity.totalActivityDuration / 60
                        let isDistracting = app.token.map { distracting.contains($0) } ?? false
                        let previous = perApp[key]?.minutes ?? 0
                        perApp[key] = AppUsage(id: key, name: app.localizedDisplayName ?? "App", token: app.token,
                                               minutes: previous + minutes, isDistracting: isDistracting)
                    }
                }
            }
        }
        let apps = perApp.values.sorted { $0.minutes > $1.minutes }
        let unlocks = state?.rules.reduce(0) { $0 + $1.unlocksToday(now: now) } ?? 0
        let usage = DayUsage(hourlyMinutes: hourly,
                             distractingMinutes: apps.filter(\.isDistracting).reduce(0) { $0 + $1.minutes },
                             pickups: pickups, unlocks: unlocks,
                             currentHour: calendar.component(.hour, from: now))
        return ReportModel(usage: usage, apps: apps)
    }
}

struct HomeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .home
    let content: (ReportModel) -> HomeReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportModel {
        await ReportBuilder.build(data)
    }
}

struct DetailReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .detail
    let content: (ReportModel) -> DetailReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportModel {
        await ReportBuilder.build(data)
    }
}

struct BreakdownReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .breakdown
    let content: (ReportModel) -> BreakdownReportView
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ReportModel {
        await ReportBuilder.build(data)
    }
}
