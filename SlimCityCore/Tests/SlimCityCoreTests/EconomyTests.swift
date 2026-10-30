import Testing
@testable import SlimCityCore

@Suite("ResourceBundle")
struct ResourceBundleTests {
    @Test("zero bundle is empty")
    func zeroIsEmpty() {
        #expect(ResourceBundle.zero.isEmpty)
        #expect(ResourceBundle().isEmpty)
    }

    @Test("negative inputs clamp to zero")
    func negativeClamps() {
        let b = ResourceBundle(material: -5, gold: -1, food: 3)
        #expect(b[.material] == 0)
        #expect(b[.gold] == 0)
        #expect(b[.food] == 3)
    }

    @Test("addition is component-wise")
    func addition() {
        let a = ResourceBundle(material: 10, gold: 5, food: 2)
        let b = ResourceBundle(material: 1, gold: 2, food: 3)
        let sum = a + b
        #expect(sum[.material] == 11)
        #expect(sum[.gold] == 7)
        #expect(sum[.food] == 5)
    }

    @Test("subtraction clamps at zero, never negative")
    func subtractionClamps() {
        let a = ResourceBundle(material: 10, gold: 5, food: 2)
        let b = ResourceBundle(material: 3, gold: 99, food: 2)
        let diff = a - b
        #expect(diff[.material] == 7)
        #expect(diff[.gold] == 0) // clamped, not -94
        #expect(diff[.food] == 0)
    }

    @Test("canAfford requires every resource to cover the cost")
    func affordability() {
        let wallet = ResourceBundle(material: 10, gold: 10, food: 10)
        #expect(wallet.canAfford(ResourceBundle(material: 10, gold: 10, food: 10)))
        #expect(wallet.canAfford(ResourceBundle(material: 5, gold: 0, food: 1)))
        #expect(!wallet.canAfford(ResourceBundle(material: 11, gold: 0, food: 0)))
        #expect(wallet.canAfford(.zero))
    }

    @Test("empty bundle can only afford zero")
    func emptyAffordance() {
        #expect(ResourceBundle.zero.canAfford(.zero))
        #expect(!ResourceBundle.zero.canAfford(ResourceBundle(material: 1)))
    }
}

@Suite("Economy conversion")
struct EconomyTests {
    @Test("default rates: representative day converts as expected")
    func representativeDay() {
        // Default rates: 100 steps/material, 10 kcal/gold, 2 min/food.
        let economy = Economy()
        let metrics = HealthMetrics(
            stepCount: 8000,
            activeEnergyKilocalories: 400,
            exerciseMinutes: 30
        )
        let grant = economy.grant(for: metrics)
        #expect(grant[.material] == 80)  // 8000 / 100
        #expect(grant[.gold] == 40)      // 400 / 10
        #expect(grant[.food] == 15)      // 30 / 2
    }

    @Test("zero activity yields zero grant")
    func zeroActivity() {
        #expect(Economy().grant(for: .zero) == .zero)
    }

    @Test("conversions floor, partial progress carries no credit")
    func flooring() {
        let economy = Economy()
        let metrics = HealthMetrics(
            stepCount: 199,                 // < 2 material
            activeEnergyKilocalories: 9.9,  // < 1 gold
            exerciseMinutes: 1.9            // < 1 food
        )
        let grant = economy.grant(for: metrics)
        #expect(grant[.material] == 1)
        #expect(grant[.gold] == 0)
        #expect(grant[.food] == 0)
    }

    @Test("large values convert without overflow")
    func largeValues() {
        let economy = Economy()
        let metrics = HealthMetrics(
            stepCount: 1_000_000,
            activeEnergyKilocalories: 50_000,
            exerciseMinutes: 10_000
        )
        let grant = economy.grant(for: metrics)
        #expect(grant[.material] == 10_000)
        #expect(grant[.gold] == 5_000)
        #expect(grant[.food] == 5_000)
    }

    @Test("custom rates are honored")
    func customRates() {
        let rates = EconomyRates(
            stepsPerMaterial: 1000,
            kilocaloriesPerGold: 100,
            exerciseMinutesPerFood: 10
        )
        let economy = Economy(rates: rates)
        let grant = economy.grant(for: HealthMetrics(
            stepCount: 5000,
            activeEnergyKilocalories: 250,
            exerciseMinutes: 45
        ))
        #expect(grant[.material] == 5)   // 5000 / 1000
        #expect(grant[.gold] == 2)       // 250 / 100
        #expect(grant[.food] == 4)       // 45 / 10
    }

    @Test("degenerate rates fall back to defaults instead of dividing by zero")
    func degenerateRatesGuarded() {
        let rates = EconomyRates(
            stepsPerMaterial: 0,
            kilocaloriesPerGold: -5,
            exerciseMinutesPerFood: 0
        )
        #expect(rates.stepsPerMaterial == 100)
        #expect(rates.kilocaloriesPerGold == 10)
        #expect(rates.exerciseMinutesPerFood == 2)
    }

    @Test("HealthMetrics clamps negatives to zero")
    func metricsClamp() {
        let m = HealthMetrics(stepCount: -10, activeEnergyKilocalories: -1, exerciseMinutes: -3)
        #expect(m == .zero)
    }
}
