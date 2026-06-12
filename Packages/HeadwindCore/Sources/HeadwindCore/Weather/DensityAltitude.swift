import Foundation

/// Standard pressure/density altitude approximations used in performance
/// planning (the familiar "120 ft per °C above ISA" rule).
public enum DensityAltitude {
    /// Pressure altitude from field elevation and altimeter setting.
    public static func pressureAltitudeFt(elevationFt: Double, altimeterInHg: Double) -> Double {
        elevationFt + (29.92 - altimeterInHg) * 1000
    }

    /// ISA standard temperature at a pressure altitude (2°C per 1000 ft lapse).
    public static func isaTemperatureC(atPressureAltitudeFt pa: Double) -> Double {
        15.0 - 2.0 * (pa / 1000.0)
    }

    /// Density altitude from elevation, altimeter setting, and OAT.
    public static func densityAltitudeFt(
        elevationFt: Double,
        altimeterInHg: Double,
        temperatureC: Double
    ) -> Double {
        let pa = pressureAltitudeFt(elevationFt: elevationFt, altimeterInHg: altimeterInHg)
        let isa = isaTemperatureC(atPressureAltitudeFt: pa)
        return pa + 120.0 * (temperatureC - isa)
    }
}
