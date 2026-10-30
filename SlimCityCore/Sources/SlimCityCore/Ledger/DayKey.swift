import Foundation

/// A calendar day, anchored to a specific start-of-day instant.
///
/// HealthKit data is tallied per local day, but "a day" is timezone-dependent.
/// `DayKey` captures the day as a `year/month/day` triple derived from a
/// specific `Calendar` (which carries the timezone), so the key is stable and
/// comparable regardless of the exact instant it was created from. This is what
/// the ledger uses to dedupe and order days.
public struct DayKey: Equatable, Codable, Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Derives the day key for an instant in the given calendar's timezone.
    public init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
    }

    /// The start-of-day `Date` for this key in the given calendar. Returns nil
    /// only if the components cannot form a valid date in that calendar.
    public func startOfDay(in calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: date)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
