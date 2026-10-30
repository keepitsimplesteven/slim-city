/// Anti-cheat policy applied to a day's metrics before they are converted to a
/// grant.
///
/// DELIBERATELY PASS-THROUGH IN THE MVP. Anti-cheat is a known future need, not
/// a launch requirement, so the hook points exist and are wired into the claim
/// path — but the default policy changes nothing. When it matters, tighten
/// `sanitize(_:)` (e.g. cap absurd daily values) and have the HealthKit layer
/// set `DailyLedgerEntry.containsUserEnteredData` using the
/// `HKMetadataKeyWasUserEntered` predicate; `shouldDiscardUserEntered` then
/// decides whether such days are ignored.
public struct AntiCheatPolicy: Equatable, Sendable {
    /// Per-day ceilings. `nil` means no cap (the MVP default).
    public var maxStepsPerDay: Int?
    public var maxActiveEnergyPerDay: Double?
    public var maxExerciseMinutesPerDay: Double?
    /// If true, days containing any manually-entered sample are zeroed out.
    public var shouldDiscardUserEntered: Bool

    public init(
        maxStepsPerDay: Int? = nil,
        maxActiveEnergyPerDay: Double? = nil,
        maxExerciseMinutesPerDay: Double? = nil,
        shouldDiscardUserEntered: Bool = false
    ) {
        self.maxStepsPerDay = maxStepsPerDay
        self.maxActiveEnergyPerDay = maxActiveEnergyPerDay
        self.maxExerciseMinutesPerDay = maxExerciseMinutesPerDay
        self.shouldDiscardUserEntered = shouldDiscardUserEntered
    }

    /// The MVP policy: no caps, trust everything. A true no-op.
    public static let passthrough = AntiCheatPolicy()

    /// Applies the policy to an entry's metrics, returning sanitized metrics.
    /// With `.passthrough` this returns the input unchanged.
    public func sanitize(_ entry: DailyLedgerEntry) -> HealthMetrics {
        if shouldDiscardUserEntered && entry.containsUserEnteredData {
            return .zero
        }
        var m = entry.metrics
        if let cap = maxStepsPerDay { m.stepCount = min(m.stepCount, cap) }
        if let cap = maxActiveEnergyPerDay { m.activeEnergyKilocalories = min(m.activeEnergyKilocalories, cap) }
        if let cap = maxExerciseMinutesPerDay { m.exerciseMinutes = min(m.exerciseMinutes, cap) }
        return m
    }
}
