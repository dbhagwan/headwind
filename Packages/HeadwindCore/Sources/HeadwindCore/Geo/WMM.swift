import Foundation

/// World Magnetic Model (WMM-2025) magnetic declination.
///
/// A faithful port of NOAA/NCEI's legacy reference algorithm (the same one
/// production WMM libraries implement), evaluated against the official
/// coefficient table in `WMMCoefficients.swift`. Verified in tests against
/// reference-implementation outputs to sub-arcsecond agreement.
///
/// Declination is positive East. Magnetic course = true course − declination.
public enum WMM {
    static let maxOrder = 12
    private static let size = 13

    /// Precomputed, Schmidt-denormalized coefficient state (thread-safe:
    /// computed once, then read-only).
    private struct Model {
        var epoch: Double
        var c: [[Double]]
        var cd: [[Double]]
        var snorm: [Double]
        var fn: [Double]
        var fm: [Double]
        var k: [[Double]]
    }

    private static let model: Model = loadModel()

    private static func loadModel() -> Model {
        var c = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        var cd = c
        var snorm = [Double](repeating: 0, count: size * size)
        var fn = [Double](repeating: 0, count: size)
        var fm = [Double](repeating: 0, count: size)
        var k = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)

        for row in WMMCoefficients.rows where row.m <= row.n {
            c[row.m][row.n] = row.g
            cd[row.m][row.n] = row.dg
            if row.m != 0 {
                c[row.n][row.m - 1] = row.h
                cd[row.n][row.m - 1] = row.dh
            }
        }

        // Convert Schmidt-normalized Gauss coefficients to unnormalized.
        snorm[0] = 1.0
        fm[0] = 0.0
        for n in 1...maxOrder {
            snorm[n] = snorm[n - 1] * Double(2 * n - 1) / Double(n)
            var j = 2.0
            var m = 0
            while m <= n {
                k[m][n] = Double((n - 1) * (n - 1) - m * m) / Double((2 * n - 1) * (2 * n - 3))
                if m > 0 {
                    let flnmj = Double((n - m + 1)) * j / Double(n + m)
                    snorm[n + m * size] = snorm[n + (m - 1) * size] * flnmj.squareRoot()
                    j = 1.0
                    c[n][m - 1] = snorm[n + m * size] * c[n][m - 1]
                    cd[n][m - 1] = snorm[n + m * size] * cd[n][m - 1]
                }
                c[m][n] = snorm[n + m * size] * c[m][n]
                cd[m][n] = snorm[n + m * size] * cd[m][n]
                m += 1
            }
            fn[n] = Double(n + 1)
            fm[n] = Double(n)
        }
        k[1][1] = 0.0

        return Model(epoch: WMMCoefficients.epoch, c: c, cd: cd, snorm: snorm, fn: fn, fm: fm, k: k)
    }

    /// Magnetic declination in degrees (East positive).
    ///
    /// - Parameters:
    ///   - coordinate: geodetic position (WGS-84)
    ///   - altitudeKm: altitude above the ellipsoid in km (aviation altitudes
    ///     round to 0–15; the effect on declination is tiny)
    ///   - decimalYear: e.g. 2026.5. Values outside the model's 5-year life
    ///     span are clamped to its edges rather than rejected, since a
    ///     slightly-aged variation beats none for a cockpit aid.
    public static func declination(
        at coordinate: Coordinate,
        altitudeKm: Double = 0,
        decimalYear: Double
    ) -> Double {
        let m = model
        var dt = decimalYear - m.epoch
        dt = min(max(dt, 0.0), 5.0)

        var tc = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        var dp = tc
        var sp = [Double](repeating: 0, count: size)
        var cp = [Double](repeating: 0, count: size)
        var pp = [Double](repeating: 0, count: size)
        var p = m.snorm

        sp[0] = 0.0
        cp[0] = 1.0
        pp[0] = 1.0
        dp[0][0] = 0.0

        let a = 6378.137, b = 6356.7523142, re = 6371.2
        let a2 = a * a, b2 = b * b, c2 = a2 - b2
        let a4 = a2 * a2, b4 = b2 * b2, c4 = a4 - b4

        let rlon = coordinate.longitude * .pi / 180
        let rlat = coordinate.latitude * .pi / 180
        let srlon = sin(rlon), srlat = sin(rlat)
        let crlon = cos(rlon), crlat = cos(rlat)
        let srlat2 = srlat * srlat, crlat2 = crlat * crlat
        sp[1] = srlon
        cp[1] = crlon

        // Geodetic → spherical (geocentric) coordinates.
        let alt = altitudeKm
        let q = (a2 - c2 * srlat2).squareRoot()
        let q1 = alt * q
        let q2 = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2))
        let ct = srlat / (q2 * crlat2 + srlat2).squareRoot()
        let st = (1.0 - ct * ct).squareRoot()
        let r2 = alt * alt + 2.0 * q1 + (a4 - c4 * srlat2) / (q * q)
        let r = r2.squareRoot()
        let d = (a2 * crlat2 + b2 * srlat2).squareRoot()
        let ca = (alt + d) / r
        let sa = c2 * crlat * srlat / (r * d)

        if maxOrder >= 2 {
            for mm in 2...maxOrder {
                sp[mm] = sp[1] * cp[mm - 1] + cp[1] * sp[mm - 1]
                cp[mm] = cp[1] * cp[mm - 1] - sp[1] * sp[mm - 1]
            }
        }

        let aor = re / r
        var ar = aor * aor
        var br = 0.0, bt = 0.0, bp = 0.0, bpp = 0.0

        for n in 1...maxOrder {
            ar *= aor
            for mm in 0...n {
                // Unnormalized associated Legendre polynomials + derivatives.
                if n == mm {
                    p[n + mm * size] = st * p[n - 1 + (mm - 1) * size]
                    dp[mm][n] = st * dp[mm - 1][n - 1] + ct * p[n - 1 + (mm - 1) * size]
                } else if n == 1 && mm == 0 {
                    p[n + mm * size] = ct * p[n - 1 + mm * size]
                    dp[mm][n] = ct * dp[mm][n - 1] - st * p[n - 1 + mm * size]
                } else if n > 1 && n != mm {
                    if mm > n - 2 {
                        p[n - 2 + mm * size] = 0.0
                        dp[mm][n - 2] = 0.0
                    }
                    p[n + mm * size] = ct * p[n - 1 + mm * size] - m.k[mm][n] * p[n - 2 + mm * size]
                    dp[mm][n] = ct * dp[mm][n - 1] - st * p[n - 1 + mm * size] - m.k[mm][n] * dp[mm][n - 2]
                }

                // Time-adjust the Gauss coefficients.
                tc[mm][n] = m.c[mm][n] + dt * m.cd[mm][n]
                if mm != 0 {
                    tc[n][mm - 1] = m.c[n][mm - 1] + dt * m.cd[n][mm - 1]
                }

                // Accumulate spherical-harmonic terms.
                let par = ar * p[n + mm * size]
                let temp1: Double, temp2: Double
                if mm == 0 {
                    temp1 = tc[mm][n] * cp[mm]
                    temp2 = tc[mm][n] * sp[mm]
                } else {
                    temp1 = tc[mm][n] * cp[mm] + tc[n][mm - 1] * sp[mm]
                    temp2 = tc[mm][n] * sp[mm] - tc[n][mm - 1] * cp[mm]
                }
                bt -= ar * temp1 * dp[mm][n]
                bp += m.fm[mm] * temp2 * par
                br += m.fn[n] * temp1 * par

                // Special case: geographic poles.
                if st == 0.0 && mm == 1 {
                    if n == 1 {
                        pp[n] = pp[n - 1]
                    } else {
                        pp[n] = ct * pp[n - 1] - m.k[mm][n] * pp[n - 2]
                    }
                    bpp += m.fm[mm] * temp2 * ar * pp[n]
                }
            }
        }

        bp = st == 0.0 ? bpp : bp / st

        // Rotate from spherical to geodetic components.
        let bx = -bt * ca - br * sa
        let by = bp

        return atan2(by, bx) * 180 / .pi
    }

    /// Converts a true course/heading to magnetic using local declination.
    /// "East is least": magnetic = true − declination(E+).
    public static func magneticFromTrue(_ trueDeg: Double, declinationDeg: Double) -> Double {
        NavMath.normalizeDeg(trueDeg - declinationDeg)
    }
}

extension Date {
    /// Decimal year (UTC), e.g. 2026-07-02 ≈ 2026.5 — the time format WMM uses.
    public var decimalYear: Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let year = cal.component(.year, from: self)
        let start = cal.date(from: DateComponents(year: year))!
        let end = cal.date(from: DateComponents(year: year + 1))!
        let fraction = timeIntervalSince(start) / end.timeIntervalSince(start)
        return Double(year) + fraction
    }
}
