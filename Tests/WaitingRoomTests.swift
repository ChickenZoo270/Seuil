import XCTest
@testable import IntentionCore

final class WaitingRoomTests: XCTestCase {
    func testGrowingResistanceRaisesDifficulty() {
        XCTAssertEqual(Resistance.standard.difficulty(base: .easy, unlocksToday: 5), .easy)
        XCTAssertEqual(Resistance.growing.difficulty(base: .easy, unlocksToday: 0), .easy)
        XCTAssertEqual(Resistance.growing.difficulty(base: .easy, unlocksToday: 1), .medium)
        XCTAssertEqual(Resistance.growing.difficulty(base: .medium, unlocksToday: 4), .hard, "capped at hard")
    }
    func testAutofocusFrequencies() {
        XCTAssertEqual(AutofocusFrequency.medium.thresholds, UsageAlert.thresholds)
        XCTAssertLessThan(AutofocusFrequency.high.thresholds.first!, AutofocusFrequency.low.thresholds.first!)
    }
    func testNumberPuzzleHoldsEveryNumberOnce() {
        var rng = SeededGenerator(seed: 3)
        for difficulty in Difficulty.allCases {
            let grid = NumberPuzzle.grid(difficulty: difficulty, using: &rng)
            XCTAssertEqual(grid.sorted(), Array(1...NumberPuzzle.size(for: difficulty)))
        }
        XCTAssertTrue(NumberPuzzle.isNext(1, found: 0))
        XCTAssertFalse(NumberPuzzle.isNext(3, found: 1))
    }
    func testShieldPacksHaveContentAndFallback() {
        for pack in ShieldPack.allCases {
            XCTAssertFalse(pack.messages.isEmpty, pack.title)
        }
        var rng = SeededGenerator(seed: 9)
        XCTAssertEqual(ShieldPack.pick(from: [], using: &rng).pack, .standard)
        let picked = ShieldPack.pick(from: [.haiku], using: &rng)
        XCTAssertEqual(picked.pack, .haiku)
        XCTAssertTrue(ShieldPack.haiku.messages.contains(picked.text))
    }
    func testEmergencyPassOncePerWeek() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(EmergencyPass.isAvailable(lastUsed: nil, now: now))
        XCTAssertFalse(EmergencyPass.isAvailable(lastUsed: now.addingTimeInterval(-86_400), now: now))
        XCTAssertTrue(EmergencyPass.isAvailable(lastUsed: now.addingTimeInterval(-8 * 86_400), now: now))
        XCTAssertTrue(EmergencyPass.isAvailable(lastUsed: now.addingTimeInterval(3600), now: now), "clock rollback never locks it")
    }
}
