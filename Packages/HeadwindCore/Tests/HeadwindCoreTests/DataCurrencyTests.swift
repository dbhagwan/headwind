import XCTest
@testable import HeadwindCore

final class DataCurrencyTests: XCTestCase {
    private func d(_ y: Int, _ m: Int, _ day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = day; c.hour = hour
        return AiracCalendar.utcCalendar.date(from: c)!
    }

    private let currency = DataCurrency(
        cycleLabel: "2606",
        effectiveDate: AiracCalendar.makeUTC(year: 2026, month: 6, day: 11),
        expirationDate: AiracCalendar.makeUTC(year: 2026, month: 7, day: 9)
    )

    func testCurrentDeepInWindow() {
        XCTAssertEqual(currency.daysRemaining(asOf: d(2026, 6, 12)), 27)
        XCTAssertEqual(currency.status(asOf: d(2026, 6, 12)), .current(daysRemaining: 27))
        XCTAssertTrue(currency.isCurrent(asOf: d(2026, 6, 12)))
    }

    func testExpiringSoonWithinThreshold() {
        XCTAssertEqual(currency.status(asOf: d(2026, 7, 7)), .expiringSoon(daysRemaining: 2))
        XCTAssertEqual(currency.status(asOf: d(2026, 7, 8)), .expiringSoon(daysRemaining: 1))
        XCTAssertTrue(currency.status(asOf: d(2026, 7, 7)).isUsable)
    }

    func testExpiredOnAndAfterExpirationDay() {
        XCTAssertEqual(currency.status(asOf: d(2026, 7, 9, hour: 6)), .expired(daysAgo: 0))
        XCTAssertEqual(currency.status(asOf: d(2026, 7, 12)), .expired(daysAgo: 3))
        XCTAssertFalse(currency.isCurrent(asOf: d(2026, 7, 12)))
    }

    func testCustomSoonThreshold() {
        XCTAssertEqual(
            currency.status(asOf: d(2026, 7, 1), soonThresholdDays: 10),
            .expiringSoon(daysRemaining: 8)
        )
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(currency)
        let decoded = try JSONDecoder().decode(DataCurrency.self, from: data)
        XCTAssertEqual(decoded, currency)

        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"2026-06-11\""))
        XCTAssertTrue(json.contains("\"2026-07-09\""))
    }
}
