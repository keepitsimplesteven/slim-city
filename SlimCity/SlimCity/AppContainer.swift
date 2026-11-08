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
    /// HealthKit-mode resource pipeline: Activity ring data -> HealthKit wallet.
    private let healthKitSync: HealthKitResourceSync
    private let activityProvider: any ActivitySummaryProviding
    private let grantRecords: any GrantRecordStore
    #if canImport(WatchConnectivity)
    private var phoneConnectivity: PhoneConnectivityManager?
    #endif

    /// Claimable-day count surfaced to the UI after a foreground sync.
    var claimableDays: Int = 0
    var lastClaim: ClaimOutcome?
    /// Human-readable result of the last HealthKit sync, for the debug menu.
    var healthKitStatus: String = "Not synced yet."

    init() {
        let controller = try? PersistenceController()
        self.persistence = controller

        // Load saved state or start with a seeded wallet so a fresh install is
        // playable before any health data is claimed.
        let loaded = (try? controller?.loadGameState()) ?? nil
        let initialState = loaded ?? GameState(wallet: ActivityGrant.startingWallet)
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

        #if canImport(HealthKit)
        let activity: any ActivitySummaryProviding = ActivitySummaryService()
        #else
        let activity: any ActivitySummaryProviding = UnavailableActivitySummaryProvider()
        #endif
        let records = UserDefaultsGrantRecordStore()
        self.activityProvider = activity
        self.grantRecords = records
        self.healthKitSync = HealthKitResourceSync(provider: activity, records: records)

        // Persist on every successful placement. The VM hands over the
        // persistable state (city + HealthKit wallet), never the manual wallet.
        vm.onStateChanged = { [weak self] state in
            try? self?.store?.saveGameState(state)
        }
        #if DEBUG
        restoreResourceMode()
        #endif
    }

    /// Called on launch/foreground: ingest latest health data and surface the
    /// claimable count. Collecting is a user action (see `collect`).
    func onForeground() async {
        if let coordinator {
            do {
                claimableDays = try await coordinator.ingestLatest()
            } catch {
                claimableDays = 0
            }
        }
        await syncHealthKit()
    }

    /// Reads today's Activity rings (the watch's Move / Exercise / Stand data
    /// synced into Health) and credits the HealthKit wallet with whatever has
    /// been earned since the last sync. Safe to call repeatedly: grants are
    /// tracked per day, so nothing is credited twice.
    @discardableResult
    func syncHealthKit() async -> ResourceBundle? {
        do {
            guard try await activityProvider.requestAuthorization() else {
                healthKitStatus = "Health data is unavailable on this device."
                return nil
            }
            let today = DayKey(date: Date(), calendar: .current)
            let granted = try await healthKitSync.sync(today: today) { [cityViewModel] bundle in
                cityViewModel.creditHealthKit(bundle)
            }
            healthKitStatus = granted.isEmpty
                ? "Synced. Nothing new to credit."
                : "Credited ⛏\(granted[.material]) 💰\(granted[.gold]) 🍃\(granted[.food])."
            return granted
        } catch {
            healthKitStatus = "Sync failed: \(error.localizedDescription)"
            return nil
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

    /// Which wallet is live. Restored from the last choice on launch.
    var debugResourceMode: ResourceMode { cityViewModel.resourceMode }

    /// Switches between the HealthKit and Manual wallets and remembers the
    /// choice. Only the HealthKit wallet is persisted to the database.
    func debugSetResourceMode(_ mode: ResourceMode) {
        cityViewModel.setResourceMode(mode)
        UserDefaults.standard.set(mode.rawValue, forKey: Self.resourceModeKey)
    }

    private static let resourceModeKey = "debug.resourceMode"

    /// Re-applies the remembered mode at launch (the VM starts in HealthKit).
    private func restoreResourceMode() {
        if let raw = UserDefaults.standard.string(forKey: Self.resourceModeKey),
           let mode = ResourceMode(rawValue: raw) {
            cityViewModel.setResourceMode(mode)
        }
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
        // Forget per-day grants and the baseline, then sync like a fresh
        // install: past days are skipped, today's rings accumulate on top of
        // the starting wallet.
        grantRecords.clear()
        Task { await syncHealthKit() }
        // Clear stale claim HUD state so it doesn't advertise phantom days.
        claimableDays = 0
        lastClaim = nil
    }

    /// Simulates `days` days of activity as "yesterday's rings × days" and
    /// credits the live wallet. Returns the grant, or nil if Health data can't
    /// be read. Yesterday with no ring data earns nothing.
    @discardableResult
    func debugSimulate(days: Int) async -> ResourceBundle? {
        do {
            guard try await activityProvider.requestAuthorization() else { return nil }
            let calendar = Calendar.current
            guard let date = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) else {
                return nil
            }
            let yesterday = DayKey(date: date, calendar: calendar)
            let summary = try await activityProvider.summaries(from: yesterday, to: yesterday)
                .first { $0.day == yesterday }
            let grant = ActivityGrant.simulatedGrant(for: summary, days: days)
            cityViewModel.debugCredit(grant)
            return grant
        } catch {
            return nil
        }
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
