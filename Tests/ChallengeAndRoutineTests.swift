import XCTest
@testable import IntentionCore

final class ChallengeTests: XCTestCase {
    func testMathProblemsMatchDifficulty() {
        var rng = SeededGenerator(seed: 42)
        for difficulty in Difficulty.allCases {
            let problems = MathChallenge.problems(difficulty: difficulty, using: &rng)
            XCTAssertEqual(problems.count, MathChallenge.problemCount(for: difficulty))
            for problem in problems {
                XCTAssertTrue(MathChallenge.isCorrect(" \(problem.answer) ", for: problem))
                XCTAssertFalse(MathChallenge.isCorrect("\(problem.answer + 1)", for: problem))
                XCTAssertFalse(MathChallenge.isCorrect("", for: problem))
            }
        }
    }
    func testSeededGeneratorIsDeterministic() {
        var first = SeededGenerator(seed: 7), second = SeededGenerator(seed: 7)
        XCTAssertEqual(MathChallenge.problems(difficulty: .hard, using: &first),
                       MathChallenge.problems(difficulty: .hard, using: &second))
    }
    func testHardProblemAnswerComputed() {
        let problem = MathProblem(text: "13 × 12 − 11", answer: 145)
        XCTAssertTrue(MathChallenge.isCorrect("145", for: problem))
    }
    func testTypingIgnoresCaseAccentsAndPunctuation() {
        let phrase = "Je choisis d’ouvrir cette app en conscience."
        XCTAssertTrue(TypingChallenge.matches("je choisis d'ouvrir cette app en conscience", phrase: phrase))
        XCTAssertTrue(TypingChallenge.matches("  JE CHOISIS D’OUVRIR   cette app, en conscience ! ", phrase: phrase))
        XCTAssertFalse(TypingChallenge.matches("je choisis cette app", phrase: phrase))
    }
    func testEveryDifficultyHasPhrases() {
        var rng = SeededGenerator(seed: 1)
        for difficulty in Difficulty.allCases {
            XCTAssertFalse(TypingChallenge.phrase(difficulty: difficulty, using: &rng).isEmpty)
        }
    }
    func testPauseGrowsWithDifficulty() {
        XCTAssertLessThan(PauseChallenge.seconds(for: .easy), PauseChallenge.seconds(for: .medium))
        XCTAssertLessThan(PauseChallenge.seconds(for: .medium), PauseChallenge.seconds(for: .hard))
    }
    func testUnlockQuota() {
        XCTAssertNil(UnlockQuota.remaining(max: 0, used: 12))
        XCTAssertEqual(UnlockQuota.remaining(max: 3, used: 1), 2)
        XCTAssertEqual(UnlockQuota.remaining(max: 3, used: 5), 0)
        XCTAssertEqual(UnlockQuota.label(1), "1 déblocage / jour")
    }
    func testUsageAlertNamesTheApp() {
        XCTAssertTrue(UsageAlert.message(minutes: 15, appName: "TikTok").body.contains("15 min que tu es sur TikTok"))
        XCTAssertTrue(UsageAlert.message(minutes: 60, appName: nil).body.contains("1 h sur cette app"))
    }
}

final class RoutineWindowTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    // 2026-09-21 is a Monday (weekday 2).
    private func date(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testDaytimeWindow() {
        let work = RoutineWindow(startMinute: 9 * 60, endMinute: 12 * 60, weekdays: [2, 3, 4, 5, 6])
        XCTAssertTrue(work.isActive(at: date(day: 21, 9), calendar: calendar))
        XCTAssertTrue(work.isActive(at: date(day: 21, 11, 59), calendar: calendar))
        XCTAssertFalse(work.isActive(at: date(day: 21, 12), calendar: calendar))
        XCTAssertFalse(work.isActive(at: date(day: 20, 10), calendar: calendar), "Sunday excluded")
    }
    func testOvernightWindowBelongsToStartDay() {
        // Sunday night to Monday morning only.
        let night = RoutineWindow(startMinute: 22 * 60, endMinute: 7 * 60, weekdays: [1])
        XCTAssertTrue(night.isActive(at: date(day: 20, 23), calendar: calendar))
        XCTAssertTrue(night.isActive(at: date(day: 21, 6, 30), calendar: calendar))
        XCTAssertFalse(night.isActive(at: date(day: 21, 23), calendar: calendar), "Monday night not selected")
        XCTAssertFalse(night.isActive(at: date(day: 21, 7), calendar: calendar))
        XCTAssertEqual(night.durationMinutes, 9 * 60)
    }
    func testValidation() {
        XCTAssertFalse(RoutineWindow(startMinute: 600, endMinute: 610, weekdays: [2]).isValid)
        XCTAssertFalse(RoutineWindow(startMinute: 600, endMinute: 700, weekdays: []).isValid)
        XCTAssertFalse(RoutineWindow(startMinute: 600, endMinute: 600, weekdays: [2]).isValid)
        XCTAssertTrue(RoutineWindow(startMinute: 600, endMinute: 615, weekdays: [2]).isValid)
    }
    func testDaysLabel() {
        XCTAssertEqual(RoutineWindow.daysLabel(RoutineWindow.allWeekdays), "Tous les jours")
        XCTAssertEqual(RoutineWindow.daysLabel([2, 3, 4, 5, 6]), "En semaine")
        XCTAssertEqual(RoutineWindow.daysLabel([1, 3]), "Mar Dim")
        XCTAssertEqual(RoutineWindow(startMinute: 540, endMinute: 720, weekdays: [1, 7]).summary, "09:00 – 12:00 · Le week-end")
    }
}
