import Foundation
import SlimCityCore

/// A minimal persistence surface the claim loop needs, so the coordinator can
/// be tested with an in-memory fake instead of the real SwiftData controller.
/// `PersistenceController` conforms via an adapter in the app target.
public protocol LedgerStore: Sendable {
    func loadLedgerEntries() throws -> [DailyLedgerEntry]
    func upsertLedgerEntry(_ entry: DailyLedgerEntry) throws
    func saveGameState(_ state: GameState) throws
    func loadGameState() throws -> GameState?
}

/// What a sync/claim pass produced, for the UI to show.
public struct ClaimOutcome: Equatable, Sendable {
    public let claimableDayCount: Int
    public let grant: ResourceBundle
    public let claimedDays: [DayKey]
    public let newWallet: ResourceBundle

    public static let none = ClaimOutcome(claimableDayCount: 0, grant: .zero, claimedDays: [], newWallet: .zero)
}

/// Drives the daily claim loop: ingest fresh health samples into the ledger,
/// surface how many days are claimable, and (on a collect action) convert those
/// days to a grant, credit the city wallet, and persist both ledger and state.
///
/// All rules are borrowed from the frozen core: `LedgerService` decides the
/// claim window and grant; `GameState.credit` applies it. This coordinator only
/// sequences the steps and talks to the store. It is pure over its injected
/// dependencies, so the multi-day claim integration test can drive it with the
/// in-memory `PersistenceController` and a fake provider.
public struct DailyClaimCoordinator: Sendable {
    private let provider: any HealthDataProviding
    private let store: any LedgerStore
    private let ledgerService: LedgerService

    public init(
        provider: any HealthDataProviding,
        store: any LedgerStore,
        ledgerService: LedgerService = LedgerService()
    ) {
        self.provider = provider
        self.store = store
        self.ledgerService = ledgerService
    }

    /// Ingests health samples for the current claim window into the ledger
    /// WITHOUT claiming. Days already marked claimed keep their claimed flag so
    /// re-ingesting can never un-claim or double-count a day. Returns the number
    /// of currently claimable days.
    @discardableResult
    public func ingestLatest() async throws -> Int {
        let today = ledgerService.today()
        let earliest = ledgerService.earliestClaimableDay()
        let samples = try await provider.dailySamples(from: earliest, to: today)

        let existing = try store.loadLedgerEntries()
        let claimedDays = Set(existing.filter(\.isClaimed).map(\.day))

        for sample in samples {
            // Preserve a day's claimed status; only refresh metrics.
            var entry = sample.toLedgerEntry()
            if claimedDays.contains(sample.day) {
                entry.isClaimed = true
            }
            try store.upsertLedgerEntry(entry)
        }
        return try claimableDayCount()
    }

    /// The count of unclaimed, in-window days currently in the ledger.
    public func claimableDayCount() throws -> Int {
        let entries = try store.loadLedgerEntries()
        return ledgerService.claimableDays(in: entries).count
    }

    /// Claims all eligible days: computes the grant, flips claimed flags,
    /// credits the wallet, persists ledger + game state. Safe to call when
    /// nothing is claimable (returns `.none` and writes nothing new).
    @discardableResult
    public func collect() throws -> ClaimOutcome {
        let entries = try store.loadLedgerEntries()
        let claimableBefore = ledgerService.claimableDays(in: entries).count
        let (updated, result) = ledgerService.claim(entries: entries)

        guard !result.claimedDays.isEmpty else {
            let wallet = (try store.loadGameState())?.wallet ?? .zero
            return ClaimOutcome(claimableDayCount: 0, grant: .zero, claimedDays: [], newWallet: wallet)
        }

        // Persist flipped ledger flags.
        for entry in updated where result.claimedDays.contains(entry.day) {
            try store.upsertLedgerEntry(entry)
        }

        // Credit the wallet and persist game state.
        var state = (try store.loadGameState()) ?? GameState()
        state.credit(result.totalGrant)
        try store.saveGameState(state)

        return ClaimOutcome(
            claimableDayCount: claimableBefore,
            grant: result.totalGrant,
            claimedDays: result.claimedDays,
            newWallet: state.wallet
        )
    }
}
