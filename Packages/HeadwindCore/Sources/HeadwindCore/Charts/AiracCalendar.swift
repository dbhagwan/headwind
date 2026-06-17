import Foundation

/// The 28-day AIRAC grid that the FAA's NASR and d-TPP cycles ride on.
///
/// Pure date arithmetic anchored to a known cycle, so the app can answer
/// "which cycle is current today?" and "is my bundled data stale?" entirely
/// offline. Cycle labels follow the `YYNN` convention (e.g. `2606` = the 6th
/// cycle effective in 2026), where `NN` counts grid dates from the first one
/// of that calendar year — robust to the occasional 14-cycle year.
public enum AiracCalendar {
    public static let periodDays = 28

    /// Anchor: d-TPP/AIRAC cycle 2606 became effective 2026-06-11 (UTC).
    public static let anchor = makeUTC(year: 2026, month: 6, day: 11)

    static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    static func makeUTC(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return utcCalendar.date(from: c)!
    }

    /// Effective date of the cycle active at `date` (the grid date on/before it).
    public static func effectiveDate(onOrBefore date: Date) -> Date {
        let cal = utcCalendar
        let day0 = cal.startOfDay(for: anchor)
        let dayN = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: day0, to: dayN).day ?? 0
        let steps = floorDiv(days, periodDays)
        return cal.date(byAdding: .day, value: steps * periodDays, to: day0)!
    }

    /// The first grid date strictly after `date`.
    public static func nextEffectiveDate(after date: Date) -> Date {
        utcCalendar.date(
            byAdding: .day, value: periodDays,
            to: effectiveDate(onOrBefore: date)
        )!
    }

    /// The `YYNN` cycle label for the cycle active at `date`.
    public static func cycleLabel(for date: Date) -> String {
        let cal = utcCalendar
        let eff = effectiveDate(onOrBefore: date)
        let year = cal.component(.year, from: eff)

        // Walk back to the first grid date in the same calendar year.
        var first = eff
        while true {
            let prev = cal.date(byAdding: .day, value: -periodDays, to: first)!
            if cal.component(.year, from: prev) != year { break }
            first = prev
        }
        let daysFromFirst = cal.dateComponents([.day], from: first, to: eff).day ?? 0
        let n = daysFromFirst / periodDays + 1
        return String(format: "%02d%02d", year % 100, n)
    }

    /// Currency for the cycle active at `date`, derived purely from the grid.
    public static func currency(for date: Date) -> DataCurrency {
        let eff = effectiveDate(onOrBefore: date)
        return DataCurrency(
            cycleLabel: cycleLabel(for: date),
            effectiveDate: eff,
            expirationDate: nextEffectiveDate(after: eff)
        )
    }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b, r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
    }
}
