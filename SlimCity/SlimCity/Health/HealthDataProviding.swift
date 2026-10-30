import Foundation
import SlimCityCore

/// Authorization outcome for health data access, abstracted so the claim loop
/// and tests don't depend on `HKAuthorizationStatus`.
public enum HealthAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

/// A per-day health sample produced by a provider, carrying the metrics plus
/// the manual-entry flag the anti-cheat hook records (but does not yet act on).
public struct DailyHealthSample: Equatable, Sendable {
    public let day: DayKey
    public let metrics: HealthMetrics
    /// True if any contributing sample was manually entered in Health.
    public let containsUserEnteredData: Bool

    public init(day: DayKey, metrics: HealthMetrics, containsUserEnteredData: Bool = false) {
        self.day = day
        self.metrics = metrics
        self.containsUserEnteredData = containsUserEnteredData
    }

    /// Converts to the frozen-core ledger entry type (unclaimed by construction).
    public func toLedgerEntry() -> DailyLedgerEntry {
        DailyLedgerEntry(
            day: day,
            metrics: metrics,
            isClaimed: false,
            containsUserEnteredData: containsUserEnteredData
        )
    }
}

/// The capability surface the daily claim loop needs from a health source.
///
/// Defined as a protocol so the live `HealthKitService` and a test fake are
/// interchangeable. Everything above this protocol (the claim coordinator,
/// ledger integration) is therefore testable headlessly without the HealthKit
/// runtime.
public protocol HealthDataProviding: Sendable {
    /// Whether this platform can provide health data at all (false on
    /// simulators/devices without HealthKit).
    var isHealthDataAvailable: Bool { get }

    /// Current authorization status for the metrics we read.
    func authorizationStatus() async -> HealthAuthorizationStatus

    /// Requests authorization for step count, active energy, exercise minutes.
    /// Returns the resulting status.
    @discardableResult
    func requestAuthorization() async throws -> HealthAuthorizationStatus

    /// Per-day metric totals between two day keys, inclusive. Days with no data
    /// are returned as `.zero` so the ledger can record them.
    func dailySamples(from start: DayKey, to end: DayKey) async throws -> [DailyHealthSample]

    /// Starts passive background delivery, invoking `onUpdate` with fresh
    /// samples as HealthKit reports changes. A no-op on providers that don't
    /// support observation.
    func startObserving(onUpdate: @escaping @Sendable ([DailyHealthSample]) -> Void) async throws
}

/// Errors surfaced by a health provider.
public enum HealthDataError: Error, Equatable, Sendable {
    case unavailable
    case authorizationDenied
    case queryFailed(String)
}
