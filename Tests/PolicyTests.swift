import XCTest
@testable import IntentionCore

final class PolicyTests: XCTestCase {
    func testSpecificLearningGetsRequestedDuration() {
        let assessment = Policy.localAssessment("Je veux comprendre comment connecter Supabase à mon app")
        XCTAssertEqual(Policy.decide(assessment, requestedMinutes: 15, hasSession: false), .allow(minutes: 15))
        XCTAssertEqual(Policy.decide(assessment, requestedMinutes: 5, hasSession: false), .allow(minutes: 5))
    }
    func testCommunicationWithRecipientUnlocks() {
        let assessment = Policy.localAssessment("Répondre au message de Léa pour samedi")
        XCTAssertEqual(assessment.kind, .communication)
        XCTAssertEqual(Policy.decide(assessment, requestedMinutes: 30, hasSession: false), .allow(minutes: 30))
    }
    func testSearchPhrasingUnlocks() {
        let assessment = Policy.localAssessment("Chercher la recette du gâteau au chocolat")
        XCTAssertEqual(assessment.kind, .learning)
        XCTAssertTrue(assessment.specific)
    }
    func testDurationOnlyFromFixedOptions() {
        let learning = Assessment(kind: .learning, specific: true)
        XCTAssertEqual(Policy.decide(learning, requestedMinutes: 60, hasSession: false), .invalidDuration)
        XCTAssertEqual(Policy.decide(learning, requestedMinutes: -5, hasSession: false), .invalidDuration)
    }
    func testScrollingWinsEvenWithLearningWords() {
        let assessment = Policy.localAssessment("Je veux apprendre à coder puis scroller pour passer le temps")
        XCTAssertEqual(Policy.decide(assessment, requestedMinutes: 15, hasSession: false), .deny)
    }
    func testBoredomIsDenied() {
        XCTAssertEqual(Policy.localAssessment("Je m'ennuie un peu ce soir").kind, .scrolling)
    }
    func testNegationDoesNotUnlock() {
        XCTAssertEqual(Policy.localAssessment("Je veux apprendre à ne pas travailler sur mon app").kind, .unclear)
    }
    func testVagueRequestNeedsClarification() {
        XCTAssertEqual(Policy.decide(.init(kind: .learning, specific: false), requestedMinutes: 15, hasSession: false), .clarify)
        XCTAssertEqual(Policy.localAssessment("Les nouveautés IA").kind, .unclear)
        XCTAssertFalse(Policy.localAssessment("Répondre à Léa").specific)
    }
    func testCannotExtendAnActiveSession() {
        XCTAssertEqual(Policy.decide(.init(kind: .communication, specific: true), requestedMinutes: 15, hasSession: true), .sessionAlreadyActive)
    }
    func testUnknownCategoryAndOversizedInputDoNotUnlock() {
        XCTAssertEqual(Policy.decide(.init(kind: .unclear, specific: true), requestedMinutes: 15, hasSession: false), .clarify)
        XCTAssertEqual(Policy.localAssessment(String(repeating: "a", count: 601)).kind, .unclear)
    }
    func testDailyLimitResetsOnNewDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let reached = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 22))!
        let sameDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 23, minute: 50))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 0, minute: 1))!
        XCTAssertTrue(DailyLimit.isReached(reachedAt: reached, now: sameDay, calendar: calendar))
        XCTAssertFalse(DailyLimit.isReached(reachedAt: reached, now: nextDay, calendar: calendar))
        XCTAssertFalse(DailyLimit.isReached(reachedAt: nil, now: sameDay, calendar: calendar))
        XCTAssertFalse(DailyLimit.isReached(reachedAt: nextDay, now: sameDay, calendar: calendar))
    }
    func testLimitLabels() {
        XCTAssertEqual(DailyLimit.label(0), "Toujours demander")
        XCTAssertEqual(DailyLimit.label(30), "30 min / jour")
        XCTAssertEqual(DailyLimit.label(90), "1 h 30 / jour")
        XCTAssertEqual(DailyLimit.label(120), "2 h / jour")
    }
}
