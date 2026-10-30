import Testing
import Foundation
@testable import SlimCityPersistence
import SlimCityCore

/// Exercises the real SwiftData `PersistenceController` against an in-memory
/// `ModelContainer`. If SwiftData's runtime is unavailable under the build
/// sandbox these will fail to run; the pure mapping tests in
/// `SnapshotMappingTests` remain the guaranteed-verifiable layer.
@Suite("PersistenceController round-trip")
@MainActor
struct PersistenceControllerTests {
    private let catalog = BuildingCatalog.default

    @Test("game state saves and reloads equal")
    func gameStateRoundTrip() throws {
        let controller = try PersistenceController(inMemory: true)
        var state = GameState(columns: 7, rows: 7, wallet: ResourceBundle(material: 80, gold: 80, food: 80))
        try state.place(buildingID: "house", at: GridPosition(column: 0, row: 0), using: catalog)
        try state.place(buildingID: "market", at: GridPosition(column: 3, row: 2), using: catalog)

        try controller.saveGameState(state)
        let loaded = try #require(try controller.loadGameState())
        // Compare order-independently: persistence guarantees a canonical
        // building order, which need not match placement order.
        #expect(loaded.columns == state.columns)
        #expect(loaded.rows == state.rows)
        #expect(loaded.wallet == state.wallet)
        #expect(Set(loaded.buildings) == Set(state.buildings))
    }

    @Test("saving twice replaces rather than duplicates the city")
    func saveReplaces() throws {
        let controller = try PersistenceController(inMemory: true)
        try controller.saveGameState(GameState(columns: 5, rows: 5, wallet: ResourceBundle(material: 1)))
        try controller.saveGameState(GameState(columns: 9, rows: 9, wallet: ResourceBundle(gold: 2)))
        let loaded = try #require(try controller.loadGameState())
        #expect(loaded.columns == 9)
        #expect(loaded.wallet == ResourceBundle(gold: 2))
    }

    @Test("ledger entries upsert by day and reload sorted")
    func ledgerUpsert() throws {
        let controller = try PersistenceController(inMemory: true)
        let e1 = DailyLedgerEntry(day: DayKey(year: 2026, month: 3, day: 14),
                                  metrics: HealthMetrics(stepCount: 100))
        let e2 = DailyLedgerEntry(day: DayKey(year: 2026, month: 3, day: 15),
                                  metrics: HealthMetrics(stepCount: 200))
        try controller.upsertLedgerEntry(e2)
        try controller.upsertLedgerEntry(e1)
        // Update e1 (same day) — should not create a duplicate.
        var e1Updated = e1
        e1Updated.isClaimed = true
        try controller.upsertLedgerEntry(e1Updated)

        let loaded = try controller.loadLedgerEntries()
        #expect(loaded.count == 2)
        #expect(loaded[0].day == DayKey(year: 2026, month: 3, day: 14))
        #expect(loaded[0].isClaimed)
        #expect(loaded[1].day == DayKey(year: 2026, month: 3, day: 15))
    }

    @Test("loading with no saved state returns nil")
    func emptyLoad() throws {
        let controller = try PersistenceController(inMemory: true)
        #expect(try controller.loadGameState() == nil)
        #expect(try controller.loadLedgerEntries().isEmpty)
    }
}
