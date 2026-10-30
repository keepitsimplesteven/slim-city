import Testing
import Foundation
@testable import SlimCityCore

@Suite("BalanceConfig")
struct BalanceConfigTests {

    /// A plausible single active day of activity.
    private let activeDay = HealthMetrics(
        stepCount: 10_000,
        activeEnergyKilocalories: 500,
        exerciseMinutes: 30
    )

    @Test("default config exposes a catalog, economy, and ledger service")
    func defaultWiring() {
        let config = BalanceConfig.default
        #expect(config.catalog.definition(for: "house") != nil)
        #expect(config.economy.rates == config.economyRates)
        #expect(config.makeLedgerService().backfillDayLimit == config.backfillDayLimit)
    }

    @Test("one active day does not fund even the cheapest building many times over")
    func notInstantWin() {
        let grant = BalanceConfig.default.economy.grant(for: activeDay)
        let catalog = BalanceConfig.default.catalog
        // Cheapest building by total resource cost.
        let cheapest = catalog.definitions.min { total($0.cost) < total($1.cost) }!
        // A single day's grant should buy at most a couple of the cheapest
        // building — not a whole city. Guard against a degenerate (instant-win)
        // economy.
        let affordableCount = maxAffordable(grant: grant, cost: cheapest.cost)
        #expect(affordableCount <= 3, "one day funded \(affordableCount) buildings — economy too generous")
        #expect(affordableCount >= 1, "one active day earns nothing — economy too stingy")
    }

    @Test("backfill cap is finite and small, so idle time cannot bank unlimited resources")
    func finiteBackfill() {
        #expect(BalanceConfig.default.backfillDayLimit >= 1)
        #expect(BalanceConfig.default.backfillDayLimit <= 14)
    }

    @Test("rates are all positive (no divide-by-zero / infinite grant)")
    func positiveRates() {
        let r = BalanceConfig.default.economyRates
        #expect(r.stepsPerMaterial > 0)
        #expect(r.kilocaloriesPerGold > 0)
        #expect(r.exerciseMinutesPerFood > 0)
    }

    @Test("zero activity yields zero resources")
    func zeroActivityZeroGrant() {
        let grant = BalanceConfig.default.economy.grant(for: .zero)
        #expect(grant.isEmpty)
    }

    // MARK: Helpers

    private func total(_ bundle: ResourceBundle) -> Int {
        ResourceType.allCases.reduce(0) { $0 + bundle[$1] }
    }

    /// How many copies of `cost` fit in `grant` (the min across non-zero cost
    /// components), i.e. how many of that building one grant can buy.
    private func maxAffordable(grant: ResourceBundle, cost: ResourceBundle) -> Int {
        var count = Int.max
        for type in ResourceType.allCases where cost[type] > 0 {
            count = min(count, grant[type] / cost[type])
        }
        return count == Int.max ? 0 : count
    }
}
