import Testing
import Foundation
@testable import SlimCityPersistence
import SlimCityCore

@Suite("GameSnapshot mapping")
struct GameSnapshotMappingTests {
    private let catalog = BuildingCatalog.default

    private func sampleState() -> GameState {
        var state = GameState(columns: 8, rows: 6, wallet: ResourceBundle(material: 100, gold: 50, food: 25))
        try! state.place(buildingID: "house", at: GridPosition(column: 1, row: 1), using: catalog)
        try! state.place(buildingID: "farm", at: GridPosition(column: 2, row: 3), using: catalog)
        return state
    }

    @Test("game state round-trips through a snapshot unchanged")
    func gameStateRoundTrip() {
        let original = sampleState()
        let restored = GameSnapshot(original).toGameState()
        #expect(restored == original)
    }

    @Test("snapshot preserves grid size, wallet, and building positions")
    func preservesFields() {
        let snapshot = GameSnapshot(sampleState())
        #expect(snapshot.columns == 8)
        #expect(snapshot.rows == 6)
        // sampleState starts at (100,50,25) then places house(20,10,5) +
        // farm(15,5,0), leaving (65,35,20).
        #expect(snapshot.wallet == ResourceBundle(material: 65, gold: 35, food: 20))
        #expect(snapshot.buildings.count == 2)
        let house = snapshot.buildings.first { $0.definitionID == "house" }
        #expect(house?.column == 1 && house?.row == 1)
    }

    @Test("empty game state round-trips")
    func emptyRoundTrip() {
        let original = GameState(columns: 10, rows: 10)
        let restored = GameSnapshot(original).toGameState()
        #expect(restored == original)
        #expect(restored.buildings.isEmpty)
        #expect(restored.wallet == .zero)
    }

    @Test("snapshot is Codable (JSON round-trip)")
    func codableRoundTrip() throws {
        let snapshot = GameSnapshot(sampleState())
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GameSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }
}

@Suite("LedgerEntrySnapshot mapping")
struct LedgerSnapshotMappingTests {
    private func sampleEntry() -> DailyLedgerEntry {
        DailyLedgerEntry(
            day: DayKey(year: 2026, month: 3, day: 15),
            metrics: HealthMetrics(stepCount: 8000, activeEnergyKilocalories: 400.5, exerciseMinutes: 30),
            isClaimed: true,
            containsUserEnteredData: true
        )
    }

    @Test("ledger entry round-trips through a snapshot unchanged")
    func roundTrip() {
        let original = sampleEntry()
        let restored = LedgerEntrySnapshot(original).toLedgerEntry()
        #expect(restored == original)
    }

    @Test("snapshot preserves day key, metrics, and flags")
    func preservesFields() {
        let snapshot = LedgerEntrySnapshot(sampleEntry())
        #expect(snapshot.year == 2026 && snapshot.month == 3 && snapshot.day == 15)
        #expect(snapshot.stepCount == 8000)
        #expect(snapshot.activeEnergyKilocalories == 400.5)
        #expect(snapshot.exerciseMinutes == 30)
        #expect(snapshot.isClaimed)
        #expect(snapshot.containsUserEnteredData)
    }

    @Test("ledger snapshot is Codable (JSON round-trip)")
    func codableRoundTrip() throws {
        let snapshot = LedgerEntrySnapshot(sampleEntry())
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(LedgerEntrySnapshot.self, from: data)
        #expect(decoded == snapshot)
    }
}
