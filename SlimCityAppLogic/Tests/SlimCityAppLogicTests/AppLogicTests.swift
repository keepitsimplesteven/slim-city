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

// MARK: - Stream 4: debug menu intents (DEBUG builds only)

#if DEBUG
@Suite("CityViewModel debug intents")
@MainActor
struct CityViewModelDebugTests {
    private func vm() -> CityViewModel {
        CityViewModel(
            state: GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
            catalog: .default
        )
    }

    @Test("debugCredit adds a single resource and persists via onStateChanged")
    func creditSingle() {
        let model = vm()
        var saves = 0
        model.onStateChanged = { _ in saves += 1 }
        model.debugCredit(.gold, amount: 50)
        #expect(model.state.wallet[.gold] == 150)
        #expect(model.state.wallet[.material] == 100) // untouched
        #expect(saves == 1)
    }

    @Test("debugCredit ignores non-positive amounts")
    func creditNonPositive() {
        let model = vm()
        var saves = 0
        model.onStateChanged = { _ in saves += 1 }
        model.debugCredit(.gold, amount: 0)
        model.debugCredit(.gold, amount: -5)
        #expect(model.state.wallet[.gold] == 100)
        #expect(saves == 0)
    }

    @Test("debugCredit(bundle:) adds all three resources at once")
    func creditBundle() {
        let model = vm()
        model.debugCredit(ResourceBundle(material: 5, gold: 6, food: 7))
        #expect(model.state.wallet == ResourceBundle(material: 105, gold: 106, food: 107))
    }

    @Test("debugReset swaps in a fresh city, keeps grid size, clears selection + buildings")
    func reset() {
        let model = vm()
        model.selectBuilding(id: "house")
        model.placeSelected(at: GridPosition(column: 0, row: 0))
        #expect(model.state.buildings.count == 1)
        let cols = model.state.columns, rows = model.state.rows

        var saves = 0
        model.onStateChanged = { _ in saves += 1 }
        model.debugReset()
        #expect(model.state.buildings.isEmpty)
        #expect(model.selectedBuildingID == nil)
        #expect(model.state.wallet == ActivityGrant.startingWallet)
        #expect(model.state.columns == cols && model.state.rows == rows)
        #expect(saves == 1)
    }
}

@Suite("DebugActions")
@MainActor
struct DebugActionsTests {
    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 6, day: d) }

    private func entry(_ d: Int, steps: Int, kcal: Double = 0, mins: Double = 0, claimed: Bool = false) -> DailyLedgerEntry {
        DailyLedgerEntry(day: day(d), metrics: HealthMetrics(stepCount: steps, activeEnergyKilocalories: kcal, exerciseMinutes: mins), isClaimed: claimed)
    }

    @Test("resetPersistedState saves a fresh state and zeroes every ledger row")
    func resetClears() throws {
        let store = MemoryStore(state: GameState(wallet: ResourceBundle(material: 999, gold: 999, food: 999)))
        try store.upsertLedgerEntry(entry(8, steps: 1000, claimed: true))
        try store.upsertLedgerEntry(entry(9, steps: 2000))
        let actions = DebugActions(store: store)

        let fresh = try actions.resetPersistedState()
        #expect(fresh.wallet == ActivityGrant.startingWallet)
        #expect(try store.loadGameState()?.wallet == ActivityGrant.startingWallet)

        let rows = try store.loadLedgerEntries()
        // Rows remain (no delete API) but are neutralized.
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.metrics == .zero && !$0.isClaimed && !$0.containsUserEnteredData })
    }
}
#endif

// MARK: - Stream 5: camera pan/zoom math

@Suite("CameraRig")
struct CameraRigTests {
    @Test("starts centered and fully zoomed out")
    func initial() {
        let rig = CameraRig(gridSpan: 10)
        #expect(rig.focus == .zero)
        #expect(rig.scale == rig.maxScale)
    }

    @Test("zoom in shrinks scale and clamps at the minimum")
    func zoomClamps() {
        var rig = CameraRig(gridSpan: 10)
        rig.zoom(by: 2)
        #expect(rig.scale == rig.maxScale / 2)
        rig.zoom(by: 1000)
        #expect(rig.scale == rig.minScale)
    }

    @Test("zoom out never exceeds the fit-the-board scale")
    func zoomOutClamps() {
        var rig = CameraRig(gridSpan: 10)
        rig.zoom(by: 0.1)
        #expect(rig.scale == rig.maxScale)
    }

    @Test("dragging right moves the camera left along screen-right")
    func dragRight() {
        var rig = CameraRig(gridSpan: 10)
        rig.pan(dx: 50, dy: 0, viewWidth: 400)
        // Camera moves opposite the finger: along -screenRight (x down, z up).
        #expect(rig.focus.x < 0)
        #expect(rig.focus.y > 0)
        #expect(abs(rig.focus.x + rig.focus.y) < 1e-9)
    }

    @Test("dragging down moves the camera toward screen-up")
    func dragDown() {
        var rig = CameraRig(gridSpan: 10)
        rig.pan(dx: 0, dy: 50, viewWidth: 400)
        // screenUp is (-1,-1): both axes decrease.
        #expect(rig.focus.x < 0)
        #expect(rig.focus.y < 0)
    }

    @Test("pan is clamped to the grid bounds")
    func panClamps() {
        var rig = CameraRig(gridSpan: 10)
        rig.pan(dx: 100_000, dy: 100_000, viewWidth: 400)
        #expect(abs(rig.focus.x) <= rig.panLimit)
        #expect(abs(rig.focus.y) <= rig.panLimit)
    }

    @Test("zoomed in pans slower per point than zoomed out")
    func panScalesWithZoom() {
        var far = CameraRig(gridSpan: 10)
        var near = CameraRig(gridSpan: 10)
        near.zoom(by: 4)
        far.pan(dx: 20, dy: 0, viewWidth: 400)
        near.pan(dx: 20, dy: 0, viewWidth: 400)
        #expect(simd_length(near.focus) < simd_length(far.focus))
    }
}

// MARK: - HealthKit vs Manual resource modes

private struct FakeActivityProvider: ActivitySummaryProviding {
    var summaries: [ActivitySummary]
    func requestAuthorization() async throws -> Bool { true }
    func summaries(from start: DayKey, to end: DayKey) async throws -> [ActivitySummary] { summaries }
}

@Suite("ActivityGrant")
struct ActivityGrantTests {
    private let day = DayKey(year: 2026, month: 11, day: 7)

    @Test("move ring maps to gold by percent of goal, capped at 100")
    func moveToGold() {
        func gold(_ kcal: Double) -> Int {
            ActivityGrant.target(for: ActivitySummary(day: day, moveKilocalories: kcal, moveGoalKilocalories: 500))[.gold]
        }
        #expect(gold(0) == 0)
        #expect(gold(250) == 50)
        #expect(gold(500) == 100)
        #expect(gold(1500) == 100)
    }

    @Test("no move goal grants no gold")
    func noGoal() {
        let s = ActivitySummary(day: day, moveKilocalories: 400, moveGoalKilocalories: 0)
        #expect(ActivityGrant.target(for: s)[.gold] == 0)
    }

    @Test("exercise minutes map to food 1:1, capped at 30")
    func exerciseToFood() {
        #expect(ActivityGrant.target(for: ActivitySummary(day: day, exerciseMinutes: 12.9))[.food] == 12)
        #expect(ActivityGrant.target(for: ActivitySummary(day: day, exerciseMinutes: 90))[.food] == 30)
    }

    @Test("stand hours map to material 1:1, capped at 12")
    func standToMaterial() {
        #expect(ActivityGrant.target(for: ActivitySummary(day: day, standHours: 7))[.material] == 7)
        #expect(ActivityGrant.target(for: ActivitySummary(day: day, standHours: 20))[.material] == 12)
    }
}

@Suite("HealthKitResourceSync")
struct HealthKitResourceSyncTests {
    private let today = DayKey(year: 2026, month: 11, day: 7)

    @Test("credits once, then only growth")
    func incremental() async throws {
        let records = InMemoryGrantRecordStore()
        var credited = ResourceBundle.zero

        let first = ActivitySummary(day: today, moveKilocalories: 250, moveGoalKilocalories: 500, exerciseMinutes: 10, standHours: 4)
        var sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: [first]), records: records)
        try await sync.sync(today: today) { credited = credited + $0 }
        #expect(credited == ResourceBundle(material: 4, gold: 50, food: 10))

        // Same data again: nothing new.
        var again = ResourceBundle.zero
        try await sync.sync(today: today) { again = again + $0 }
        #expect(again.isEmpty)

        // The day grows: only the difference is credited.
        let grown = ActivitySummary(day: today, moveKilocalories: 500, moveGoalKilocalories: 500, exerciseMinutes: 25, standHours: 6)
        sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: [grown]), records: records)
        var delta = ResourceBundle.zero
        try await sync.sync(today: today) { delta = delta + $0 }
        #expect(delta == ResourceBundle(material: 2, gold: 50, food: 15))
        #expect(records.granted(on: today) == ResourceBundle(material: 6, gold: 100, food: 25))
    }

    @Test("clearing records re-credits the day")
    func clearRecords() async throws {
        let records = InMemoryGrantRecordStore()
        let s = ActivitySummary(day: today, exerciseMinutes: 5)
        let sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: [s]), records: records)
        try await sync.sync(today: today) { _ in }
        records.clear()
        var credited = ResourceBundle.zero
        try await sync.sync(today: today) { credited = $0 }
        #expect(credited == ResourceBundle(food: 5))
    }

    @Test("days outside the window are ignored")
    func windowBounds() async throws {
        let old = ActivitySummary(day: DayKey(year: 2026, month: 10, day: 1), exerciseMinutes: 30)
        let sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: [old]), records: InMemoryGrantRecordStore())
        var credited = ResourceBundle.zero
        try await sync.sync(today: today) { credited = $0 }
        #expect(credited.isEmpty)
    }
}

@MainActor
@Suite("CityViewModel resource modes")
struct ResourceModeTests {
    private func makeVM() -> (CityViewModel, () -> [GameState]) {
        let vm = CityViewModel(state: GameState(wallet: ResourceBundle(material: 10, gold: 20, food: 30)))
        var saved: [GameState] = []
        vm.onStateChanged = { saved.append($0) }
        return (vm, { saved })
    }

    @Test("wallets are separate and survive switching")
    func separateWallets() {
        let (vm, _) = makeVM()
        vm.setResourceMode(.manual)
        vm.debugCredit(.gold, amount: 500)
        #expect(vm.state.wallet[.gold] == 600)   // manual started at 100
        vm.setResourceMode(.healthKit)
        #expect(vm.state.wallet == ResourceBundle(material: 10, gold: 20, food: 30))
        vm.setResourceMode(.manual)
        #expect(vm.state.wallet[.gold] == 600)
    }

    @Test("only the HealthKit wallet is ever persisted")
    func persistsOnlyHealthKit() {
        let (vm, saved) = makeVM()
        vm.setResourceMode(.manual)
        vm.debugCredit(.material, amount: 999)
        let last = saved().last
        #expect(last?.wallet == ResourceBundle(material: 10, gold: 20, food: 30))
    }

    @Test("health credits land in the HealthKit wallet even in manual mode")
    func creditWhileManual() {
        let (vm, saved) = makeVM()
        vm.setResourceMode(.manual)
        let manualBefore = vm.state.wallet
        vm.creditHealthKit(ResourceBundle(food: 5))
        #expect(vm.state.wallet == manualBefore)
        #expect(saved().last?.wallet[.food] == 35)
        vm.setResourceMode(.healthKit)
        #expect(vm.state.wallet[.food] == 35)
    }

    @Test("placing in manual mode spends the manual wallet only")
    func placeInManual() {
        let (vm, saved) = makeVM()
        vm.setResourceMode(.manual)   // manual wallet = 100/100/100
        let cost = vm.catalog.definition(for: "house")!.cost
        let result = vm.place(buildingID: "house", at: GridPosition(column: 0, row: 0))
        #expect(result.didPlace)
        #expect(vm.state.wallet == ResourceBundle(material: 100, gold: 100, food: 100) - cost)
        #expect(saved().last?.wallet == ResourceBundle(material: 10, gold: 20, food: 30))
    }
}

// MARK: - Stream 6: onboarding wallet, first-sync baseline, simulate yesterday

@Suite("Onboarding + simulate")
struct OnboardingTests {
    private let today = DayKey(year: 2026, month: 11, day: 7)
    private let yesterday = DayKey(year: 2026, month: 11, day: 6)

    @Test("starting wallet is one full day of each resource")
    func startingWallet() {
        #expect(ActivityGrant.startingWallet == ResourceBundle(material: 12, gold: 100, food: 30))
    }

    @Test("first sync skips past days and pays only today")
    func firstSyncBaseline() async throws {
        let records = InMemoryGrantRecordStore()
        let past = ActivitySummary(day: yesterday, moveKilocalories: 500, moveGoalKilocalories: 500, exerciseMinutes: 30, standHours: 12)
        let now = ActivitySummary(day: today, moveKilocalories: 100, moveGoalKilocalories: 500, exerciseMinutes: 6, standHours: 2)
        let sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: [past, now]), records: records)

        var credited = ResourceBundle.zero
        try await sync.sync(today: today) { credited = credited + $0 }
        #expect(credited == ResourceBundle(material: 2, gold: 20, food: 6))
        #expect(records.hasBaseline)

        // Later syncs still ignore the already-recorded past day.
        var again = ResourceBundle.zero
        try await sync.sync(today: today) { again = again + $0 }
        #expect(again.isEmpty)
    }

    @Test("clearing records resets the baseline")
    func clearResetsBaseline() async throws {
        let records = InMemoryGrantRecordStore()
        let sync = HealthKitResourceSync(provider: FakeActivityProvider(summaries: []), records: records)
        try await sync.sync(today: today) { _ in }
        #expect(records.hasBaseline)
        records.clear()
        #expect(!records.hasBaseline)
    }

    @Test("simulated grant is yesterday's earnings times the day count")
    func simulatedGrant() {
        let y = ActivitySummary(day: yesterday, moveKilocalories: 250, moveGoalKilocalories: 500, exerciseMinutes: 10, standHours: 4)
        #expect(ActivityGrant.simulatedGrant(for: y, days: 3) == ResourceBundle(material: 12, gold: 150, food: 30))
    }

    @Test("simulated grant is empty without ring data or days")
    func simulatedEmpty() {
        let y = ActivitySummary(day: yesterday, moveKilocalories: 250, moveGoalKilocalories: 500)
        #expect(ActivityGrant.simulatedGrant(for: nil, days: 3).isEmpty)
        #expect(ActivityGrant.simulatedGrant(for: y, days: 0).isEmpty)
    }

#if DEBUG
    @MainActor
    @Test("debug reset restores the starting wallet in HealthKit mode and keeps manual at 100s")
    func resetWallets() {
        let vm = CityViewModel(state: GameState(wallet: ResourceBundle(material: 1, gold: 2, food: 3)))
        vm.debugReset()
        #expect(vm.state.wallet == ActivityGrant.startingWallet)
        vm.setResourceMode(.manual)
        #expect(vm.state.wallet == ResourceBundle(material: 100, gold: 100, food: 100))
        vm.setResourceMode(.healthKit)
        #expect(vm.state.wallet == ActivityGrant.startingWallet)
    }
#endif
}
