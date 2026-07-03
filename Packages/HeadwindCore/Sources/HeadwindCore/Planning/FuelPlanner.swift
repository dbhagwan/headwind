import Foundation

/// Trip fuel vs. what's in the tanks, with the regulatory-style reserve.
public struct FuelCheck: Hashable, Sendable {
    public let tripFuelGal: Double
    public let reserveGal: Double
    public let onboardGal: Double
    /// Onboard minus (trip + reserve); negative means you can't legally go.
    public let marginGal: Double
    /// Still-air endurance of the fuel on board at cruise burn, minutes.
    public let enduranceMinutes: Double

    public var totalRequiredGal: Double { tripFuelGal + reserveGal }
    public var isSufficient: Bool { marginGal >= 0 }
}

public enum FuelPlanner {
    /// - Parameters:
    ///   - tripFuelGal: computed route fuel (from the leg calculator)
    ///   - fuelBurnGPH: cruise burn used to convert the reserve time
    ///   - onboardGal: usable fuel at takeoff
    ///   - reserveMinutes: e.g. 30 (VFR day), 45 (VFR night/IFR)
    public static func check(
        tripFuelGal: Double,
        fuelBurnGPH: Double,
        onboardGal: Double,
        reserveMinutes: Double
    ) -> FuelCheck {
        let reserve = fuelBurnGPH * reserveMinutes / 60
        let endurance = fuelBurnGPH > 0 ? onboardGal / fuelBurnGPH * 60 : 0
        return FuelCheck(
            tripFuelGal: tripFuelGal,
            reserveGal: reserve,
            onboardGal: onboardGal,
            marginGal: onboardGal - tripFuelGal - reserve,
            enduranceMinutes: endurance
        )
    }
}
