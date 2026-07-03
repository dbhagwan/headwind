import XCTest
@testable import HeadwindCore

final class WMMTests: XCTestCase {
    /// Ground truth generated with the reference WMM-2025 implementation
    /// (pygeomag, official NOAA coefficient file) — see scripts/build-wmm.py.
    /// Spans E/W declination, both hemispheres, altitude, and the model
    /// life span.
    private let referenceCases: [(name: String, lat: Double, lon: Double, altKm: Double, year: Double, dec: Double)] = [
        ("KSFO", 37.6188, -122.375, 0.0, 2026.5, 12.817616),
        ("KBOS", 42.3656, -71.0096, 0.0, 2026.5, -13.966339),
        ("PANC Anchorage", 61.1743, -149.9963, 0.0, 2026.5, 14.025967),
        ("KMIA", 25.7959, -80.287, 0.0, 2027.0, -7.354206),
        ("KDEN at 10k ft", 39.8617, -104.6731, 3.048, 2026.5, 7.356368),
        ("Sydney", -33.9461, 151.1772, 0.0, 2026.5, 12.841256),
        ("Quito (equator)", -0.1292, -78.3575, 2.4, 2028.25, -5.462579),
        ("Reykjavik", 64.13, -21.94, 0.0, 2029.5, -10.236061),
        ("Epoch start KSEA", 47.449, -122.309, 0.0, 2025.0, 15.050947),
    ]

    func testDeclinationMatchesReferenceImplementation() {
        for c in referenceCases {
            let dec = WMM.declination(
                at: Coordinate(latitude: c.lat, longitude: c.lon),
                altitudeKm: c.altKm,
                decimalYear: c.year
            )
            XCTAssertEqual(dec, c.dec, accuracy: 0.0005, c.name)
        }
    }

    func testGeographicPoleDoesNotCrash() {
        let dec = WMM.declination(
            at: Coordinate(latitude: 90.0, longitude: 0.0),
            decimalYear: 2026.5
        )
        XCTAssertTrue(dec.isFinite)
    }

    func testDatesOutsideLifespanClampToEdges(){
        let p = Coordinate(latitude: 37.6188, longitude: -122.375)
        XCTAssertEqual(
            WMM.declination(at: p, decimalYear: 2031.0),
            WMM.declination(at: p, decimalYear: 2030.0),
            accuracy: 1e-12
        )
        XCTAssertEqual(
            WMM.declination(at: p, decimalYear: 2024.0),
            WMM.declination(at: p, decimalYear: 2025.0),
            accuracy: 1e-12
        )
    }

    func testMagneticFromTrue() {
        // East is least: SFO true 137° with +12.8°E variation → mag ≈ 124.2°.
        XCTAssertEqual(WMM.magneticFromTrue(137, declinationDeg: 12.8), 124.2, accuracy: 1e-9)
        // West is best: Boston true 90° with −14°W variation → mag 104°.
        XCTAssertEqual(WMM.magneticFromTrue(90, declinationDeg: -14), 104, accuracy: 1e-9)
        // Wraps correctly.
        XCTAssertEqual(WMM.magneticFromTrue(5, declinationDeg: 12.8), 352.2, accuracy: 1e-9)
    }

    func testDecimalYear() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let jan1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertEqual(jan1.decimalYear, 2026.0, accuracy: 1e-9)
        let midYearIsh = cal.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 12))!
        XCTAssertEqual(midYearIsh.decimalYear, 2026.5, accuracy: 0.002)
    }
}
