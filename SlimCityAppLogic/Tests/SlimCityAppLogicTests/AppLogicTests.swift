import Testing
import Foundation
import simd
@testable import SlimCityAppLogic
import SlimCityCore

// MARK: - Stream 1: grid↔world round trip + view-model intents

@Suite("IsometricGridMapper")
struct IsometricGridMapperTests {
    @Test("every cell round-trips grid -> world -> grid")
    func roundTrip() {
        let mapper = IsometricGridMapper(columns: 10, rows: 8, tileSize: 1.5)
        for col in 0..<10 {
            for row in 0..<8 {
                let pos = GridPosition(column: col, row: row)
                let world = mapper.worldCenter(of: pos)
                let back = mapper.gridPosition(atWorld: world)
                #expect(back == pos, "round trip failed for \(pos)")
            }
        }
    }

    @Test("points off the grid map to nil")
    func offGridIsNil() {
        let mapper = IsometricGridMapper(columns: 4, rows: 4, tileSize: 1)
        // Far outside the centered grid.
        #expect(mapper.gridPosition(atWorld: SIMD2(100, 100)) == nil)
        #expect(mapper.gridPosition(atWorld: SIMD2(-100, 0)) == nil)
    }

    @Test("grid is centered on the origin")
    func centered() {
        let mapper = IsometricGridMapper(columns: 3, rows: 3, tileSize: 2)
        let center = mapper.worldCenter(of: GridPosition(column: 1, row: 1))
        #expect(abs(center.x) < 1e-9)
        #expect(abs(center.y) < 1e-9)
    }

    @Test("nearest cell snaps a point near a center to that cell")
    func nearestSnaps() {
        let mapper = IsometricGridMapper(columns: 5, rows: 5, tileSize: 1)
        let target = GridPosition(column: 3, row: 2)
        let world = mapper.worldCenter(of: target)
        let jittered = world + SIMD2(0.2, -0.15)
        #expect(mapper.nearestCell(toWorld: jittered) == target)
    }
}

@Suite("CityViewModel intents")
@MainActor
struct CityViewModelTests {
    private func vm() -> CityViewModel {
        CityViewModel(
            state: GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
            catalog: .default
        )
    }

    @Test("selecting a building sets the selection; selecting again toggles off")
    func selectToggle() {
        let model = vm()
        model.selectBuilding(id: "house")
        #expect(model.selectedBuildingID == "house")
        model.selectBuilding(id: "house")
        #expect(model.selectedBuildingID == nil)
    }

    @Test("placing the selected building succeeds and decrements the wallet")
    func placeSuccess() {
        let model = vm()
        model.selectBuilding(id: "house") // cost material 20 gold 10 food 5
        let feedback = model.placeSelected(at: GridPosition(column: 0, row: 0))
        #expect(feedback.didPlace)
        #expect(model.state.wallet[.material] == 80)
        #expect(model.state.wallet[.gold] == 90)
        #expect(model.state.wallet[.food] == 95)
        #expect(model.state.buildings.count == 1)
    }

    @Test("placement on an occupied tile surfaces .tileOccupied")
    func occupied() {
        let model = vm()
        model.selectBuilding(id: "farm")
        _ = model.placeSelected(at: GridPosition(column: 1, row: 1))
        let second = model.place(buildingID: "farm", at: GridPosition(column: 1, row: 1))
        #expect(second == .rejected(.tileOccupied))
    }

    @Test("placement the wallet can't afford surfaces .insufficientResources")
    func broke() {
        let model = CityViewModel(state: GameState(wallet: .zero), catalog: .default)
        let feedback = model.place(buildingID: "market", at: GridPosition(column: 0, row: 0))
        #expect(feedback == .rejected(.insufficientResources))
        #expect(model.state.buildings.isEmpty)
    }

    @Test("placing with nothing selected reports .noSelection")
    func noSelection() {
        let model = vm()
        #expect(model.placeSelected(at: GridPosition(column: 0, row: 0)) == .noSelection)
    }

    @Test("onStateChanged fires only on a successful placement")
    func stateChangedCallback() {
        let model = vm()
        var calls = 0
        model.onStateChanged = { _ in calls += 1 }
        model.place(buildingID: "nope", at: GridPosition(column: 0, row: 0)) // unknown
        #expect(calls == 0)
        model.place(buildingID: "house", at: GridPosition(column: 0, row: 0))
        #expect(calls == 1)
    }
}

// MARK: - Stream 2: claim coordinator integration (ledger + economy + store)

/// A fake health provider yielding injected samples.
struct FakeHealthProvider: HealthDataProviding {
    let samples: [DailyHealthSample]
    var available = true
    var authorized = true
    var isHealthDataAvailable: Bool { available }
    func authorizationStatus() async -> HealthAuthorizationStatus { authorized ? .authorized : .denied }
    func requestAuthorization() async throws -> HealthAuthorizationStatus {
        if !available { throw HealthDataError.unavailable }
        return authorized ? .authorized : .denied
    }
    func dailySamples(from start: DayKey, to end: DayKey) async throws -> [DailyHealthSample] {
        guard available else { throw HealthDataError.unavailable }
        guard authorized else { throw HealthDataError.authorizationDenied }
        return samples.filter { $0.day >= start && $0.day <= end }
    }
    func startObserving(onUpdate: @escaping @Sendable ([DailyHealthSample]) -> Void) async throws {}
}

/// In-memory ledger + state store for the coordinator.
final class MemoryStore: LedgerStore, @unchecked Sendable {
    private var entries: [DayKey: DailyLedgerEntry] = [:]
    private var state: GameState?
    init(state: GameState? = nil) { self.state = state }
    func loadLedgerEntries() throws -> [DailyLedgerEntry] { entries.values.sorted { $0.day < $1.day } }
    func upsertLedgerEntry(_ entry: DailyLedgerEntry) throws { entries[entry.day] = entry }
    func saveGameState(_ s: GameState) throws { state = s }
    func loadGameState() throws -> GameState? { state }
}

@Suite("DailyClaimCoordinator")
struct DailyClaimCoordinatorTests {
    // Use a fixed clock so "today" and the claim window are deterministic.
    private func ledgerService() -> LedgerService {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        return LedgerService(calendar: cal, clock: FixedClock(now), backfillDayLimit: 7)
    }

    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 6, day: d) }

    private func sample(_ d: Int, steps: Int, kcal: Double, mins: Double) -> DailyHealthSample {
        DailyHealthSample(day: day(d), metrics: HealthMetrics(stepCount: steps, activeEnergyKilocalories: kcal, exerciseMinutes: mins))
    }

    @Test("multi-day ingest then collect credits the aggregate grant and marks days claimed")
    func multiDayClaim() async throws {
        let provider = FakeHealthProvider(samples: [
            sample(8, steps: 1000, kcal: 100, mins: 20),
            sample(9, steps: 2000, kcal: 50, mins: 10),
            sample(10, steps: 500, kcal: 0, mins: 0)
        ])
        let store = MemoryStore(state: GameState(wallet: .zero))
        let coord = DailyClaimCoordinator(provider: provider, store: store, ledgerService: ledgerService())

        let claimable = try await coord.ingestLatest()
        #expect(claimable == 3)

        let outcome = try coord.collect()
        #expect(outcome.claimedDays.count == 3)
        // Default economy: 100 steps/material, 10 kcal/gold, 2 min/food.
        // material = (1000+2000+500)/100 summed per-day = 10+20+5 = 35
        // gold = 100/10 + 50/10 + 0 = 10+5 = 15 ; food = 20/2+10/2 = 10+5 = 15
        #expect(outcome.grant == ResourceBundle(material: 35, gold: 15, food: 15))
        #expect(outcome.newWallet == ResourceBundle(material: 35, gold: 15, food: 15))

        // A second collect yields nothing (no double-claim).
        let again = try coord.collect()
        #expect(again.claimedDays.isEmpty)
        #expect(again.grant == .zero)
    }

    @Test("re-ingesting after a claim never un-claims or re-grants a day")
    func reIngestPreservesClaimed() async throws {
        let provider = FakeHealthProvider(samples: [sample(10, steps: 1000, kcal: 0, mins: 0)])
        let store = MemoryStore(state: GameState(wallet: .zero))
        let coord = DailyClaimCoordinator(provider: provider, store: store, ledgerService: ledgerService())
        _ = try await coord.ingestLatest()
        _ = try coord.collect()
        // Ingest again with the same provider.
        let claimable = try await coord.ingestLatest()
        #expect(claimable == 0) // nothing new to claim
    }

    @Test("auth-denied / unavailable provider yields no claimable days, no crash")
    func unavailableProvider() async throws {
        let provider = FakeHealthProvider(samples: [], available: false, authorized: false)
        let store = MemoryStore(state: GameState(wallet: .zero))
        let coord = DailyClaimCoordinator(provider: provider, store: store, ledgerService: ledgerService())
        await #expect(throws: HealthDataError.self) { _ = try await provider.requestAuthorization() }
        // Coordinator surfaces the provider error from ingest.
        await #expect(throws: Error.self) { _ = try await coord.ingestLatest() }
    }
}

// MARK: - Stream 3: payload codec + ledger reconciliation (dedupe by DayKey)

@Suite("WatchHealthPayload codec")
struct WatchHealthPayloadTests {
    private func sample(_ d: Int) -> WatchHealthPayload.DaySample {
        WatchHealthPayload.DaySample(day: DayKey(year: 2026, month: 6, day: d), metrics: HealthMetrics(stepCount: d * 100, activeEnergyKilocalories: Double(d), exerciseMinutes: Double(d)))
    }

    @Test("payload survives a JSON encode/decode round trip")
    func jsonRoundTrip() throws {
        let payload = WatchHealthPayload(days: [sample(1), sample(2)], wallet: ResourceBundle(material: 5, gold: 6, food: 7))
        let data = try payload.encoded()
        let back = try WatchHealthPayload.decoded(from: data)
        #expect(back == payload)
        #expect(back.wallet == ResourceBundle(material: 5, gold: 6, food: 7))
    }

    @Test("dictionary representation round-trips through the WatchConnectivity shape")
    func dictRoundTrip() throws {
        let payload = WatchHealthPayload(days: [sample(3)])
        let dict = try payload.dictionaryRepresentation()
        let back = try WatchHealthPayload.from(dictionary: dict)
        #expect(back == payload)
    }

    @Test("a version mismatch is rejected")
    func versionMismatch() throws {
        let payload = WatchHealthPayload(days: [sample(1)], version: 999)
        let data = try payload.encoded()
        #expect(throws: WatchPayloadError.self) { _ = try WatchHealthPayload.decoded(from: data) }
    }

    @Test("a missing payload key is rejected")
    func missingKey() {
        #expect(throws: WatchPayloadError.self) { _ = try WatchHealthPayload.from(dictionary: [:]) }
    }
}

@Suite("LedgerReconciler dedupe")
struct LedgerReconcilerTests {
    private let reconciler = LedgerReconciler()
    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 6, day: d) }
    private func entry(_ d: Int, steps: Int, claimed: Bool = false) -> DailyLedgerEntry {
        DailyLedgerEntry(day: day(d), metrics: HealthMetrics(stepCount: steps), isClaimed: claimed)
    }

    @Test("the same day from watch and phone does not double-count")
    func noDoubleCount() {
        let phone = [entry(10, steps: 1000)]
        let fromWatch = [entry(10, steps: 1000)]
        let toWrite = reconciler.reconcile(incoming: fromWatch, into: phone)
        // Identical day with identical metrics: nothing to write, no duplicate.
        #expect(toWrite.isEmpty)
    }

    @Test("a claimed day is never overwritten or un-claimed by an incoming copy")
    func claimedIsImmutable() {
        let phone = [entry(10, steps: 1000, claimed: true)]
        let fromWatch = [entry(10, steps: 9999, claimed: false)]
        let merged = reconciler.merge(incoming: fromWatch[0], existing: phone[0])
        #expect(merged.isClaimed)
        #expect(merged.metrics.stepCount == 1000)
    }

    @Test("an unclaimed day takes the higher metric values (no lowering by a stale relay)")
    func takesMax() {
        let phone = [entry(10, steps: 1000)]
        let fromWatch = [entry(10, steps: 2500)]
        let toWrite = reconciler.reconcile(incoming: fromWatch, into: phone)
        #expect(toWrite.count == 1)
        #expect(toWrite[0].metrics.stepCount == 2500)
    }

    @Test("a never-seen day is added as-is")
    func addsNewDay() {
        let toWrite = reconciler.reconcile(incoming: [entry(11, steps: 300)], into: [entry(10, steps: 100)])
        #expect(toWrite.count == 1)
        #expect(toWrite[0].day == day(11))
    }

    @Test("duplicate incoming days are merged by max before writing")
    func dedupesIncomingBatch() {
        let toWrite = reconciler.reconcile(incoming: [entry(10, steps: 100), entry(10, steps: 800)], into: [])
        #expect(toWrite.count == 1)
        #expect(toWrite[0].metrics.stepCount == 800)
    }
}
