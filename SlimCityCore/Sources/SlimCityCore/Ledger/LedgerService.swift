import Foundation

/// Provides "now" to the ledger so day-boundary logic is testable.
///
/// Production uses `SystemClock`; tests inject a fixed instant to exercise
/// timezone and backfill behavior deterministically.
public protocol Clock: Sendable {
    var now: Date { get }
}

/// A clock backed by the real system time.
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// A clock fixed at a specific instant, for tests.
public struct FixedClock: Clock {
    public let now: Date
    public init(_ now: Date) { self.now = now }
}

/// The result of claiming unclaimed ledger days.
public struct ClaimResult: Equatable, Sendable {
    /// The combined grant to credit to the wallet.
    public let totalGrant: ResourceBundle
    /// The day keys that were claimed in this operation.
    public let claimedDays: [DayKey]

    public static let empty = ClaimResult(totalGrant: .zero, claimedDays: [])
}

/// Pure logic over a set of `DailyLedgerEntry` values: deciding which days are
/// claimable (respecting a backfill cap), applying anti-cheat, and converting
/// claimed days into a single resource grant.
///
/// The service holds no state of its own — it operates on an entries array
/// passed in and returns the mutated entries plus a `ClaimResult`. Persistence
/// (Task 5) owns storing the entries; this service owns the rules.
public struct LedgerService: Sendable {
    public var calendar: Calendar
    public var clock: Clock
    public var economy: Economy
    public var antiCheat: AntiCheatPolicy
    /// How many days back (including today) are eligible to claim. Days older
    /// than this are never claimable, so leaving the app closed for a long time
    /// can't bank unlimited resources.
    public var backfillDayLimit: Int

    public init(
        calendar: Calendar = .current,
        clock: Clock = SystemClock(),
        economy: Economy = Economy(),
        antiCheat: AntiCheatPolicy = .passthrough,
        backfillDayLimit: Int = 7
    ) {
        self.calendar = calendar
        self.clock = clock
        self.economy = economy
        self.antiCheat = antiCheat
        self.backfillDayLimit = max(1, backfillDayLimit)
    }

    /// Today's day key, per this service's calendar/clock.
    public func today() -> DayKey {
        DayKey(date: clock.now, calendar: calendar)
    }

    /// The oldest day that is still eligible to claim (inclusive).
    /// Days before this are expired. Returns `today` if the cap math fails.
    public func earliestClaimableDay() -> DayKey {
        let start = calendar.startOfDay(for: clock.now)
        let earliest = calendar.date(byAdding: .day, value: -(backfillDayLimit - 1), to: start) ?? start
        return DayKey(date: earliest, calendar: calendar)
    }

    /// True when a day is within the claimable window (not in the future, not
    /// older than the backfill cap).
    public func isWithinClaimWindow(_ day: DayKey) -> Bool {
        day >= earliestClaimableDay() && day <= today()
    }

    /// Computes the grant for a set of entries and marks the claimed ones.
    ///
    /// Only entries that are unclaimed AND within the claim window are claimed.
    /// Anti-cheat is applied per day before conversion. Returns the updated
    /// entries (with `isClaimed` flipped) and a `ClaimResult`.
    public func claim(
        entries: [DailyLedgerEntry]
    ) -> (entries: [DailyLedgerEntry], result: ClaimResult) {
        var updated = entries
        var total = ResourceBundle.zero
        var claimedDays: [DayKey] = []

        for index in updated.indices {
            let entry = updated[index]
            guard !entry.isClaimed, isWithinClaimWindow(entry.day) else { continue }

            let sanitized = antiCheat.sanitize(entry)
            total = total + economy.grant(for: sanitized)
            updated[index].isClaimed = true
            claimedDays.append(entry.day)
        }

        claimedDays.sort()
        return (updated, ClaimResult(totalGrant: total, claimedDays: claimedDays))
    }

    /// Unclaimed days currently eligible to claim, oldest first. Useful for the
    /// UI to show "you have N days to collect".
    public func claimableDays(in entries: [DailyLedgerEntry]) -> [DayKey] {
        entries
            .filter { !$0.isClaimed && isWithinClaimWindow($0.day) }
            .map(\.day)
            .sorted()
    }
}
