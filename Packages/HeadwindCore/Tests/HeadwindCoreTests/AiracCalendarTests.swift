import XCTest
@testable import HeadwindCore

final class AiracCalendarTests: XCTestCase {
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
        AiracCalendar.makeUTC(year: y, month: m, day: day)
    }

    func testEffectiveDateFloorsToGrid() {
        // Anchor cycle 2606 effective 2026-06-11, next 2026-07-09.
        XCTAssertEqual(AiracCalendar.effectiveDate(onOrBefore: d(2026, 6, 11)), d(2026, 6, 11))
        XCTAssertEqual(AiracCalendar.effectiveDate(onOrBefore: d(2026, 6, 20)), d(2026, 6, 11))
        XCTAssertEqual(AiracCalendar.effectiveDate(onOrBefore: d(2026, 7, 8)), d(2026, 6, 11))
        XCTAssertEqual(AiracCalendar.effectiveDate(onOrBefore: d(2026, 7, 9)), d(2026, 7, 9))
        XCTAssertEqual(AiracCalendar.effectiveDate(onOrBefore: d(2026, 6, 10)), d(2026, 5, 14))
    }

    func testNextEffectiveDate() {
        XCTAssertEqual(AiracCalendar.nextEffectiveDate(after: d(2026, 6, 11)), d(2026, 7, 9))
        XCTAssertEqual(AiracCalendar.nextEffectiveDate(after: d(2026, 6, 20)), d(2026, 7, 9))
        XCTAssertEqual(AiracCalendar.nextEffectiveDate(after: d(2026, 7, 8)), d(2026, 7, 9))
    }

    func testCycleLabels() {
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 6, 15)), "2606")
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 6, 11)), "2606")
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 7, 9)), "2607")
        // First cycle of 2026 is 2026-01-22 → 2601.
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 1, 22)), "2601")
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 2, 18)), "2601")
        // The day before rolls back into 2025's 13th cycle (2025-12-25).
        XCTAssertEqual(AiracCalendar.cycleLabel(for: d(2026, 1, 21)), "2513")
    }

    func testLabelsStepContiguouslyAcrossAYear() {
        // 13 cycles in 2026 then roll to 2701; every label is 4 digits and
        // the cycle never exceeds the count of grid dates that year.
        var date = d(2026, 1, 22)
        var labels: [String] = []
        for _ in 0..<13 {
            labels.append(AiracCalendar.cycleLabel(for: date))
            date = AiracCalendar.nextEffectiveDate(after: date)
        }
        XCTAssertEqual(labels.first, "2601")
        XCTAssertEqual(labels.last, "2613")
        XCTAssertEqual(AiracCalendar.cycleLabel(for: date), "2701")
    }

    func testCurrencyDerivedFromGrid() {
        let currency = AiracCalendar.currency(for: d(2026, 6, 15))
        XCTAssertEqual(currency.cycleLabel, "2606")
        XCTAssertEqual(currency.effectiveDate, d(2026, 6, 11))
        XCTAssertEqual(currency.expirationDate, d(2026, 7, 9))
    }
}
