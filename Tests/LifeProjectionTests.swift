import XCTest
@testable import IntentionCore

final class LifeProjectionTests: XCTestCase {
    func testYearsOnPhone() {
        // 6 h a day is a quarter of every remaining day: 55 years left → 13.75 years.
        XCTAssertEqual(LifeProjection.yearsOnPhone(hoursPerDay: 6, age: 25), 13.75, accuracy: 0.001)
        XCTAssertEqual(LifeProjection.yearsOnPhone(hoursPerDay: 4, age: 90), 0)
        XCTAssertEqual(LifeProjection.yearsOnPhone(hoursPerDay: 30, age: 56), 24, accuracy: 0.001, "clamped to 24 h")
    }
    func testSavingsAndShares() {
        XCTAssertEqual(LifeProjection.yearsSaved(hoursPerDay: 6, age: 25), 5.5, accuracy: 0.001)
        XCTAssertEqual(LifeProjection.awakeShare(hoursPerDay: 4), 0.25, accuracy: 0.001)
        XCTAssertEqual(LifeProjection.daysPerYear(hoursPerDay: 4), 61)
    }
    func testFormatting() {
        XCTAssertEqual(LifeProjection.format(years: 13.75), "13,8 ans")
        XCTAssertEqual(LifeProjection.format(years: 5), "5 ans")
        XCTAssertEqual(LifeProjection.format(years: 0.5), "0,5 an")
    }
}
