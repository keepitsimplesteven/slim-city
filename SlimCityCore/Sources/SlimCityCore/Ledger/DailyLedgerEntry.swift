import Foundation

/// One day's recorded health metrics and claim status.
///
/// The ledger is the authoritative per-day record that sits between HealthKit
/// (which writes raw metrics) and the economy (which converts claimed days into
/// resource grants). Keeping a per-day ledger — rather than only "today" — is
/// what enables backfilling days the user didn't open the app, and gives
/// anti-cheat a place to live later.
public struct DailyLedgerEntry: Equatable, Codable, Sendable, Hashable {
    /// The local calendar day this entry represents.
    public let day: DayKey
    /// Raw metric totals for the day (post anti-cheat filtering, once enabled).
    public var metrics: HealthMetrics
    /// Whether this day's grant has already been credited to the wallet.
    /// Prevents double-claiming.
    public var isClaimed: Bool
    /// Hook for anti-cheat: true if any sample for the day was manually entered
    /// in Health. Recorded now, acted on later. Pass-through (always false)
    /// until HealthKit integration sets it. See `AntiCheat`.
    public var containsUserEnteredData: Bool

    public init(
        day: DayKey,
        metrics: HealthMetrics = .zero,
        isClaimed: Bool = false,
        containsUserEnteredData: Bool = false
    ) {
        self.day = day
        self.metrics = metrics
        self.isClaimed = isClaimed
        self.containsUserEnteredData = containsUserEnteredData
    }
}
