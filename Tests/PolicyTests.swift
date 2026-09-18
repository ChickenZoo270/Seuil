import XCTest
@testable import IntentionCore

final class PolicyTests: XCTestCase {
    func testSpecificLearningGetsExactlyFifteenMinutes() {
        let assessment = Policy.localAssessment("Je veux comprendre comment connecter Supabase à mon app")
        XCTAssertEqual(Policy.decide(assessment, usedMinutes: 0, hasSession: false), .allow(minutes: 15))
    }
    func testScrollingWinsEvenWithLearningWords() {
        let assessment = Policy.localAssessment("Je veux apprendre à coder puis scroller pour passer le temps")
        XCTAssertEqual(Policy.decide(assessment, usedMinutes: 0, hasSession: false), .deny)
    }
    func testNegationDoesNotUnlock() {
        XCTAssertEqual(Policy.localAssessment("Je veux apprendre à ne pas travailler sur mon app").kind, .unclear)
    }
    func testVagueRequestNeedsClarification() {
        XCTAssertEqual(Policy.decide(.init(kind: .learning, specific: false), usedMinutes: 0, hasSession: false), .clarify)
        XCTAssertEqual(Policy.localAssessment("Les nouveautés IA").kind, .unclear)
    }
    func testBudgetCannotBeOverriddenByClassifier() {
        let learning = Assessment(kind: .learning, specific: true)
        XCTAssertEqual(Policy.decide(learning, usedMinutes: 30, hasSession: false), .allow(minutes: 15))
        XCTAssertEqual(Policy.decide(learning, usedMinutes: 31, hasSession: false), .budgetExhausted)
        XCTAssertEqual(Policy.decide(learning, usedMinutes: -1, hasSession: false), .budgetExhausted)
    }
    func testCannotExtendAnActiveSession() {
        XCTAssertEqual(Policy.decide(.init(kind: .communication, specific: true), usedMinutes: 0, hasSession: true), .sessionAlreadyActive)
    }
    func testUnknownCategoryAndOversizedInputDoNotUnlock() {
        XCTAssertEqual(Policy.decide(.init(kind: .unclear, specific: true), usedMinutes: 0, hasSession: false), .clarify)
        XCTAssertEqual(Policy.localAssessment(String(repeating: "a", count: 601)).kind, .unclear)
    }
    func testBudgetWindowAndClockRollback() {
        let now = Date(timeIntervalSince1970: 200_000)
        let receipts = [Receipt(startedAt: now.addingTimeInterval(-86_401), minutes: 15),
                        Receipt(startedAt: now.addingTimeInterval(-100), minutes: 15),
                        Receipt(startedAt: now.addingTimeInterval(100), minutes: 15)]
        XCTAssertEqual(Budget.used(receipts, now: now), 30)
        XCTAssertEqual(Budget.used([Receipt(startedAt: now.addingTimeInterval(-86_400), minutes: 15)], now: now), 0)
    }
}
