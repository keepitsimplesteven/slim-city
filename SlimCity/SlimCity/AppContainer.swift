import Foundation
import SwiftUI
import SlimCityCore
import SlimCityPersistence

/// Assembles and owns the iOS app's object graph: persistence, the city
/// view-model, the daily claim coordinator, and the phone-side connectivity
/// receiver. Kept out of the SwiftUI views so wiring stays in one place and the
/// views stay pure.
@MainActor
@Observable
final class AppContainer {
    let cityViewModel: CityViewModel
    private let persistence: PersistenceController?
    private let store: (any LedgerStore)?
    private let coordinator: DailyClaimCoordinator?
    #if canImport(WatchConnectivity)
    private var phoneConnectivity: PhoneConnectivityManager?
    #endif

    /// Claimable-day count surfaced to the UI after a foreground sync.
    var claimableDays: Int = 0
    var lastClaim: ClaimOutcome?

    init() {
        let controller = try? PersistenceController()
        self.persistence = controller

        // Load saved state or start with a seeded wallet so a fresh install is
        // playable before any health data is claimed.
        let loaded = (try? controller?.loadGameState()) ?? nil
        let initialState = loaded ?? GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100))
        let vm = CityViewModel(state: initialState, catalog: .default)
        self.cityViewModel = vm

        if let controller {
            let adapter = PersistenceLedgerStore(controller: controller)
            self.store = adapter
            #if canImport(HealthKit)
            self.coordinator = DailyClaimCoordinator(provider: HealthKitService(), store: adapter)
            #else
            self.coordinator = DailyClaimCoordinator(provider: UnavailableHealthProvider(), store: adapter)
            #endif
            #if canImport(WatchConnectivity)
            self.phoneConnectivity = PhoneConnectivityManager(store: adapter)
            #endif
        } else {
            self.store = nil
            self.coordinator = nil
        }

        // Persist on every successful placement.
        vm.onStateChanged = { [weak self] state in
            try? self?.store?.saveGameState(state)
        }
    }

    /// Called on launch/foreground: ingest latest health data and surface the
    /// claimable count. Collecting is a user action (see `collect`).
    func onForeground() async {
        guard let coordinator else { return }
        do {
            claimableDays = try await coordinator.ingestLatest()
        } catch {
            claimableDays = 0
        }
    }

    /// Collects all claimable days, credits the wallet, and refreshes the VM.
    func collect() {
        guard let coordinator else { return }
        if let outcome = try? coordinator.collect() {
            lastClaim = outcome
            claimableDays = 0
            // Reload persisted state into the view-model's wallet.
            if let refreshed = try? store?.loadGameState() {
                cityViewModel.onStateChanged?(refreshed)
            }
        }
    }

    // MARK: - Debug actions (DEBUG builds only)
    #if DEBUG

    /// Whether the debug menu has a persistence store to act on. When false
    /// (persistence failed to initialize), Reset/Simulate can't touch disk; the
    /// view-model-only `debugCredit` still works in memory.
    var debugHasStore: Bool { store != nil }

    private var debugActions: DebugActions? {
        store.map { DebugActions(store: $0) }
    }

    /// Credits a single resource straight into the live wallet (and disk, via
    /// the VM's persist hook). Pure in-memory mutation through the frozen core.
    func debugCredit(_ type: ResourceType, amount: Int) {
        cityViewModel.debugCredit(type, amount: amount)
    }

    /// Wipes the city back to a fresh start: fresh in-memory `GameState`, fresh
    /// persisted state, neutralized ledger, and reset claim HUD state. The
    /// ledger cannot be physically emptied with the frozen persistence API
    /// (no delete) — `DebugActions.resetPersistedState` zeroes the rows instead.
    func debugReset() {
        // Reset persisted state + ledger first (best-effort if a store exists).
        _ = try? debugActions?.resetPersistedState()
        // Then swap the live view-model to a fresh city.
        cityViewModel.debugReset()
        // Clear stale claim HUD state so it doesn't advertise phantom days.
        claimableDays = 0
        lastClaim = nil
    }

    /// Simulates `days` of activity through the real claim path and refreshes
    /// the VM wallet from the persisted result. Returns the aggregate grant (or
    /// nil if there's no store / no source history).
    @discardableResult
    func debugSimulate(days: Int, source: DebugActions.MetricsSource) -> ResourceBundle? {
        guard let debugActions else { return nil }
        guard let grant = try? debugActions.simulateDays(days, source: source) else { return nil }
        if let refreshed = try? store?.loadGameState() {
            cityViewModel.onStateChanged?(refreshed)
        }
        // Simulating consumes claimable days; refresh the count honestly.
        claimableDays = (try? coordinator?.claimableDayCount()) ?? 0
        return grant
    }

    #endif
}

/// Adapts `PersistenceController` (all `@MainActor`) to the plain `LedgerStore`
/// protocol the claim coordinator depends on. Because `AppContainer` and the
/// coordinator's call sites are `@MainActor`, hopping is safe here.
@MainActor
final class PersistenceLedgerStore: LedgerStore {
    private let controller: PersistenceController
    init(controller: PersistenceController) { self.controller = controller }

    nonisolated func loadLedgerEntries() throws -> [DailyLedgerEntry] {
        try MainActor.assumeIsolated { try controller.loadLedgerEntries() }
    }
    nonisolated func upsertLedgerEntry(_ entry: DailyLedgerEntry) throws {
        try MainActor.assumeIsolated { try controller.upsertLedgerEntry(entry) }
    }
    nonisolated func saveGameState(_ state: GameState) throws {
        try MainActor.assumeIsolated { try controller.saveGameState(state) }
    }
    nonisolated func loadGameState() throws -> GameState? {
        try MainActor.assumeIsolated { try controller.loadGameState() }
    }
}

/// Fallback provider for platforms/simulators without HealthKit: reports
/// unavailable and yields no samples, so the claim loop degrades gracefully.
struct UnavailableHealthProvider: HealthDataProviding {
    var isHealthDataAvailable: Bool { false }
    func authorizationStatus() async -> HealthAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> HealthAuthorizationStatus { .denied }
    func dailySamples(from start: DayKey, to end: DayKey) async throws -> [DailyHealthSample] { [] }
    func startObserving(onUpdate: @escaping @Sendable ([DailyHealthSample]) -> Void) async throws {}
}
