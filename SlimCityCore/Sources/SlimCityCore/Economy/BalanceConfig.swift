import Foundation

/// The single source of truth for every tunable number in the game.
///
/// TASK 11 — CENTRALIZED BALANCE. Before this, tunables were scattered: economy
/// conversion rates in `EconomyRates`, building costs/scores in the catalog's
/// `default`, and the ledger backfill cap as a `LedgerService` init default.
/// `BalanceConfig` gathers them in one value so a balancing pass edits data in
/// one place. It is ADDITIVE: the existing `EconomyRates.default`,
/// `BuildingCatalog.default`, and `LedgerService` defaults are unchanged, so no
/// public API breaks. Call sites opt in by constructing their types from
/// `BalanceConfig.default`.
///
/// DESIGN NOTE — avoiding a degenerate economy:
/// An economy is "degenerate" if a player can reach an effectively unbounded
/// city (instant win) from a plausible day of activity. Two levers prevent it:
///   1. Conversion rates: a realistic active day (~10k steps, ~500 kcal,
///      ~30 exercise min) must yield only a modest resource trickle relative to
///      building costs — enough for steady progress, not a city in a day.
///   2. Backfill cap: days older than `backfillDayLimit` expire, so leaving the
///      app closed can't bank unlimited resources.
/// `BalanceConfigTests` asserts both properties hold for `.default`.
public struct BalanceConfig: Equatable, Sendable {
    /// Metric→resource conversion rates.
    public var economyRates: EconomyRates
    /// The building definitions (ids, costs, scores, model names).
    public var buildings: [BuildingDefinition]
    /// How many days back (incl. today) remain claimable.
    public var backfillDayLimit: Int

    public init(
        economyRates: EconomyRates,
        buildings: [BuildingDefinition],
        backfillDayLimit: Int
    ) {
        self.economyRates = economyRates
        self.buildings = buildings
        self.backfillDayLimit = max(1, backfillDayLimit)
    }

    /// The tuned MVP balance. Rates and costs are set so one active day funds
    /// steady placement without an instant win (see `BalanceConfigTests`).
    public static let `default` = BalanceConfig(
        economyRates: EconomyRates(
            stepsPerMaterial: 200,      // ~10k steps -> 50 material
            kilocaloriesPerGold: 18,    // ~500 kcal  -> ~27 gold
            exerciseMinutesPerFood: 3   // ~30 min    -> 10 food
        ),
        buildings: BuildingCatalog.default.definitions,
        backfillDayLimit: 7
    )

    /// A catalog built from this config's building list.
    public var catalog: BuildingCatalog {
        BuildingCatalog(definitions: buildings)
    }

    /// An economy built from this config's rates.
    public var economy: Economy {
        Economy(rates: economyRates)
    }

    /// A `LedgerService` wired to this config (default clock/calendar).
    public func makeLedgerService(
        calendar: Calendar = .current,
        clock: Clock = SystemClock(),
        antiCheat: AntiCheatPolicy = .passthrough
    ) -> LedgerService {
        LedgerService(
            calendar: calendar,
            clock: clock,
            economy: economy,
            antiCheat: antiCheat,
            backfillDayLimit: backfillDayLimit
        )
    }
}
