/// Raw daily HealthKit metric totals, before conversion to resources.
///
/// These are the three metrics the MVP economy is built on. Values are the
/// cumulative total for a single day. `activeEnergyKilocalories` and
/// `exerciseMinutes` are stored as `Double` because HealthKit reports them as
/// continuous quantities; `stepCount` is whole steps.
public struct HealthMetrics: Equatable, Codable, Sendable, Hashable {
    public var stepCount: Int
    public var activeEnergyKilocalories: Double
    public var exerciseMinutes: Double

    public init(
        stepCount: Int = 0,
        activeEnergyKilocalories: Double = 0,
        exerciseMinutes: Double = 0
    ) {
        self.stepCount = max(0, stepCount)
        self.activeEnergyKilocalories = max(0, activeEnergyKilocalories)
        self.exerciseMinutes = max(0, exerciseMinutes)
    }

    public static let zero = HealthMetrics()
}

/// The tunable conversion rates that map raw health metrics to resources.
///
/// Centralizing every rate here is deliberate: Task 11's balancing pass tunes
/// the whole economy by editing this one value. Each rate is "metric units per
/// one resource unit" — e.g. `stepsPerMaterial = 100` means 100 steps earns
/// 1 material. Conversions floor (round down), so partial progress toward the
/// next unit carries no credit within a day.
public struct EconomyRates: Equatable, Codable, Sendable {
    /// Steps required to earn one `.material`.
    public var stepsPerMaterial: Int
    /// Active kilocalories required to earn one `.gold`.
    public var kilocaloriesPerGold: Double
    /// Exercise minutes required to earn one `.food`.
    public var exerciseMinutesPerFood: Double

    public init(
        stepsPerMaterial: Int = 100,
        kilocaloriesPerGold: Double = 10,
        exerciseMinutesPerFood: Double = 2
    ) {
        // Guard against zero/negative divisors that would make the economy
        // degenerate (infinite resources). Fall back to the sensible defaults.
        self.stepsPerMaterial = stepsPerMaterial > 0 ? stepsPerMaterial : 100
        self.kilocaloriesPerGold = kilocaloriesPerGold > 0 ? kilocaloriesPerGold : 10
        self.exerciseMinutesPerFood = exerciseMinutesPerFood > 0 ? exerciseMinutesPerFood : 2
    }

    /// The default balance used by the MVP until Task 11 tunes it.
    public static let `default` = EconomyRates()
}

/// Converts raw daily health metrics into a resource grant using `EconomyRates`.
///
/// Pure and deterministic: the same metrics and rates always produce the same
/// grant. This is the single place metric→resource mapping happens, so both the
/// daily claim loop and any future passive-production system share one source of
/// truth.
public struct Economy: Equatable, Sendable {
    public var rates: EconomyRates

    public init(rates: EconomyRates = .default) {
        self.rates = rates
    }

    /// Converts a day's metrics into the resources they earn.
    ///
    /// Each metric maps to exactly one resource; conversions floor so you only
    /// earn whole resource units. A day of zero activity yields `.zero`.
    public func grant(for metrics: HealthMetrics) -> ResourceBundle {
        let material = metrics.stepCount / rates.stepsPerMaterial
        let gold = Int(metrics.activeEnergyKilocalories / rates.kilocaloriesPerGold)
        let food = Int(metrics.exerciseMinutes / rates.exerciseMinutesPerFood)
        return ResourceBundle(material: material, gold: gold, food: food)
    }
}
