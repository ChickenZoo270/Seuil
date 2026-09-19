import XCTest
@testable import IntentionCore

final class MilestoneTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    func testFirstDoorOpensOnFirstDay() {
        XCTAssertFalse(Door.wood.isUnlocked(ProgressStats()))
        XCTAssertTrue(Door.wood.isUnlocked(ProgressStats(openStreak: 1)))
        XCTAssertEqual(Door.latest(ProgressStats(openStreak: 1)), .wood)
        XCTAssertNil(Door.latest(ProgressStats()))
    }
    func testProgressIsCappedAtTarget() {
        let stats = ProgressStats(focusStreak: 1)
        XCTAssertEqual(Door.stone.progress(stats).current, 1)
        XCTAssertEqual(Door.stone.progress(stats).target, 3)
        XCTAssertEqual(Door.stone.progress(ProgressStats(focusStreak: 9)).current, 3)
        XCTAssertTrue(Door.moon.isUnlocked(ProgressStats(usedHardMode: true)))
    }
    func testLatestIsTheMostAdvancedEarned() {
        let stats = ProgressStats(openStreak: 5, focusStreak: 8, cleanStreak: 4, focusSessions: 3)
        XCTAssertEqual(Door.latest(stats), .glass)
    }
    func testEveryDoorHasCopy() {
        for door in Door.allCases {
            XCTAssertFalse(door.title.isEmpty)
            XCTAssertFalse(door.goal.isEmpty)
            XCTAssertFalse(door.celebration.isEmpty)
        }
    }
    func testDayRunAcceptsTodayNotDoneYet() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 12))!
        XCTAssertEqual(DayRun.current(["2026-09-20", "2026-09-19", "2026-09-18"], today: today, calendar: calendar), 3)
        XCTAssertEqual(DayRun.current(["2026-09-19", "2026-09-18"], today: today, calendar: calendar), 2)
        XCTAssertEqual(DayRun.current(["2026-09-18"], today: today, calendar: calendar), 0)
        XCTAssertEqual(DayRun.current([], today: today, calendar: calendar), 0)
    }
}
