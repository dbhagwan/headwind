import Foundation

/// The validity window of a bundled aeronautical dataset, with a status that
/// drives the "your charts are out of date" warnings.
public struct DataCurrency: Codable, Hashable, Sendable {
    public let cycleLabel: String
    public let effectiveDate: Date
    public let expirationDate: Date

    public enum Status: Hashable, Sendable {
        case current(daysRemaining: Int)
        case expiringSoon(daysRemaining: Int)
        case expired(daysAgo: Int)

        public var isUsable: Bool {
            if case .expired = self { return false }
            return true
        }
    }

    public init(cycleLabel: String, effectiveDate: Date, expirationDate: Date) {
        self.cycleLabel = cycleLabel
        self.effectiveDate = effectiveDate
        self.expirationDate = expirationDate
    }

    /// Whole calendar days (UTC) until expiration; negative once expired.
    public func daysRemaining(asOf now: Date) -> Int {
        let cal = AiracCalendar.utcCalendar
        let from = cal.startOfDay(for: now)
        let to = cal.startOfDay(for: expirationDate)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }

    public func status(asOf now: Date, soonThresholdDays: Int = 3) -> Status {
        let days = daysRemaining(asOf: now)
        if days <= 0 { return .expired(daysAgo: -days) }
        if days <= soonThresholdDays { return .expiringSoon(daysRemaining: days) }
        return .current(daysRemaining: days)
    }

    public func isCurrent(asOf now: Date) -> Bool {
        status(asOf: now).isUsable
    }

    // MARK: Codable (ISO yyyy-MM-dd in UTC)

    enum CodingKeys: String, CodingKey {
        case cycleLabel = "cycle"
        case effectiveDate = "effective"
        case expirationDate = "expires"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cycleLabel = try c.decode(String.self, forKey: .cycleLabel)
        effectiveDate = try Self.decodeDate(c, .effectiveDate)
        expirationDate = try Self.decodeDate(c, .expirationDate)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cycleLabel, forKey: .cycleLabel)
        try c.encode(Self.formatter.string(from: effectiveDate), forKey: .effectiveDate)
        try c.encode(Self.formatter.string(from: expirationDate), forKey: .expirationDate)
    }

    private static func decodeDate(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) throws -> Date {
        let raw = try c.decode(String.self, forKey: key)
        guard let date = formatter.date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: c, debugDescription: "Expected yyyy-MM-dd, got \(raw)"
            )
        }
        return date
    }
}
