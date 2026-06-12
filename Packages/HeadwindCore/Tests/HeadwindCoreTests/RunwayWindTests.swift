import XCTest
@testable import HeadwindCore

final class RunwayWindTests: XCTestCase {
    private let runway = Runway(
        ident: "10/28", lengthFt: 5000, surface: "Asphalt",
        leIdent: "10", leHeadingDegT: 100, heIdent: "28", heHeadingDegT: 280
    )

    func testDirectHeadwindPicksAlignedEnd() throws {
        let ends = RunwayWindCalculator.evaluate(runways: [runway], windFromDegT: 280, windSpeedKts: 15)
        XCTAssertEqual(ends.count, 2)

        let best = try XCTUnwrap(ends.first)
        XCTAssertEqual(best.endIdent, "28")
        XCTAssertEqual(best.headwindKts, 15, accuracy: 0.001)
        XCTAssertEqual(best.crosswindKts, 0, accuracy: 0.001)

        let worst = try XCTUnwrap(ends.last)
        XCTAssertEqual(worst.endIdent, "10")
        XCTAssertEqual(worst.headwindKts, -15, accuracy: 0.001)
    }

    func testPureCrosswindComponents() throws {
        // Wind from 010° on a 100° runway end: full crosswind from the left.
        let ends = RunwayWindCalculator.evaluate(runways: [runway], windFromDegT: 10, windSpeedKts: 12)
        let end10 = try XCTUnwrap(ends.first { $0.endIdent == "10" })
        XCTAssertEqual(end10.headwindKts, 0, accuracy: 0.001)
        XCTAssertEqual(end10.crosswindKts, -12, accuracy: 0.001)
    }

    func testQuarteringWind() throws {
        // Wind 240@20 on runway end 28 (280°T): 40° off the nose.
        let ends = RunwayWindCalculator.evaluate(runways: [runway], windFromDegT: 240, windSpeedKts: 20)
        let end28 = try XCTUnwrap(ends.first { $0.endIdent == "28" })
        XCTAssertEqual(end28.headwindKts, 20 * cos(40 * Double.pi / 180), accuracy: 0.01)
        XCTAssertEqual(end28.crosswindKts, -20 * sin(40 * Double.pi / 180), accuracy: 0.01)
        XCTAssertEqual(ends.first?.endIdent, "28")
    }

    func testRunwaysWithoutHeadingsAreSkipped() {
        let bare = Runway(ident: "13/31", lengthFt: 2400, surface: "Asphalt")
        XCTAssertTrue(RunwayWindCalculator.evaluate(runways: [bare], windFromDegT: 0, windSpeedKts: 10).isEmpty)
    }
}
