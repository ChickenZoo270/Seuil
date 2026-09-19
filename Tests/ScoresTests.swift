import XCTest
@testable import IntentionCore

final class ScoresTests: XCTestCase {
    private func day(hourly: [Int: Double] = [:], distracting: Double = 0, pickups: Int = 0, unlocks: Int = 0, hour: Int = 20) -> DayUsage {
        var minutes = Array(repeating: 0.0, count: 24)
        for (hour, value) in hourly { minutes[hour] = value }
        return DayUsage(hourlyMinutes: minutes, distractingMinutes: distracting, pickups: pickups, unlocks: unlocks, currentHour: hour)
    }

    func testPerfectDayScoresHundred() {
        let scores = Scoring.scores(day())
        XCTAssertEqual(scores.focus, 100)
        XCTAssertEqual(scores.rest, 100)
        XCTAssertEqual(scores.sleep, 100)
        XCTAssertEqual(scores.overall, 100)
    }
    func testFocusDropsWithDistractionPickupsAndUnlocks() {
        XCTAssertEqual(Scoring.focus(day(distracting: 180, pickups: 120)), 0)
        XCTAssertEqual(Scoring.focus(day(distracting: 105)), 70)
        XCTAssertEqual(Scoring.focus(day(unlocks: 2)), 84)
        XCTAssertEqual(Scoring.focus(day(unlocks: 10)), 70, "unlock penalty is capped")
    }
    func testRestRewardsLongOfflineStretches() {
        var busy: [Int: Double] = [:]
        for hour in 8..<20 { busy[hour] = 30 }            // 6 h of screen time, never offline
        XCTAssertEqual(Scoring.longestOfflineHours(day(hourly: busy)), 0)
        XCTAssertEqual(Scoring.rest(day(hourly: busy)), 17)
        busy[12] = 2; busy[13] = 0; busy[14] = 4             // 3 quiet hours in a row
        XCTAssertEqual(Scoring.longestOfflineHours(day(hourly: busy)), 3)
    }
    func testRestIsFairEarlyInTheDay() {
        XCTAssertEqual(Scoring.rest(day(hour: 7)), 100)
        XCTAssertEqual(Scoring.rest(day(hourly: [8: 20], hour: 9)), 50, "the only elapsed hour was busy")
    }
    func testFutureHoursAreIgnored() {
        XCTAssertEqual(Scoring.longestOfflineHours(day(hour: 9)), 1)
        XCTAssertEqual(Scoring.longestOfflineHours(day(hour: 7)), 0)
    }
    func testSleepUnknownBeforeMorning() {
        XCTAssertNil(Scoring.sleep(day(hour: 5)))
        XCTAssertEqual(Scoring.sleep(day(hourly: [1: 30], hour: 9)), 50)
        XCTAssertEqual(Scoring.scores(day(hour: 5)).overall, 100, "overall ignores the unknown sleep score")
    }
    func testRatings() {
        XCTAssertEqual(Rating(score: 90), .great)
        XCTAssertEqual(Rating(score: 70), .good)
        XCTAssertEqual(Rating(score: 50), .slow)
        XCTAssertEqual(Rating(score: 10), .bad)
        XCTAssertEqual(Rating.slow.label, "Ralentis")
    }
    func testDurationLabels() {
        XCTAssertEqual(Scoring.duration(39), "39min")
        XCTAssertEqual(Scoring.duration(73), "1h 13min")
        XCTAssertEqual(Scoring.duration(120), "2h")
    }
    func testStreakCountsCleanDaysBeforeToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 10))!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let clean: Set<String> = ["2026-09-19", "2026-09-18", "2026-09-16"]
        XCTAssertEqual(Streak.count(cleanDays: clean, today: today, calendar: calendar, since: start), 2)
        XCTAssertEqual(Streak.count(cleanDays: [], today: today, calendar: calendar, since: start), 0)
        XCTAssertEqual(Streak.key(today, calendar: calendar), "2026-09-20")
    }
}

final class HighlightTests: XCTestCase {
    func testHighlightsRateEachFigure() {
        var hourly = Array(repeating: 0.0, count: 24)
        hourly[10] = 60; hourly[1] = 60
        let day = DayUsage(hourlyMinutes: hourly, distractingMinutes: 30, pickups: 75, unlocks: 2, currentHour: 20)
        let list = Scoring.highlights(day)
        XCTAssertEqual(list.map(\.title), ["Temps d’écran", "Distractions", "Prises en main", "Déblocages", "Hors ligne", "Écran la nuit"])
        XCTAssertEqual(list[0].value, "2h")
        XCTAssertEqual(list[0].rating, .great)
        XCTAssertEqual(list[2].score, 50)
        XCTAssertEqual(list[3].score, 50)
        XCTAssertEqual(list[5].rating, .bad)
        XCTAssertEqual(DayUsage(hourlyMinutes: [], distractingMinutes: 0, pickups: 0, unlocks: 0, currentHour: 4).totalMinutes, 0)
        XCTAssertEqual(Scoring.highlights(DayUsage(hourlyMinutes: [], distractingMinutes: 0, pickups: 0, unlocks: 0, currentHour: 4)).count, 5)
    }
}
