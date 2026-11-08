#if DEBUG
import Foundation
import SlimCityCore

/// App-layer debug actions that need the persistence store. DEBUG builds only;
/// pure orchestration over the injected `LedgerStore`, with no new game rules
/// and no new core or persistence APIs.
///
/// (Simulating days lives in `AppContainer.debugSimulate`: it reads yesterday's
/// Activity rings and uses `ActivityGrant`, so it needs no store.)
struct DebugActions: Sendable {
    private let store: any LedgerStore

    init(store: any LedgerStore) {
        self.store = store
    }

    /// Clears persisted game state and the ledger as far as the frozen
    /// persistence API allows.
    ///
    /// Game state: fully reset by saving a fresh `GameState` — `saveGameState`
    /// replaces the single stored city, so no delete API is needed. The fresh
    /// wallet is one day's worth of each resource (`ActivityGrant.startingWallet`).
    ///
    /// Ledger: the frozen `LedgerStore` surface exposes `upsert` + `load` but NO
    /// delete, so rows cannot be physically removed. We neutralize every entry
    /// instead — zero metrics, unclaimed — which clears all claim state and
    /// grant value. A truly empty table would need a new persistence API; per
    /// the TODO we note that gap rather than widen the frozen set.
    ///
    /// - Returns: the fresh state that was persisted.
    @discardableResult
    func resetPersistedState(
        freshWallet: ResourceBundle = ActivityGrant.startingWallet
    ) throws -> GameState {
        let fresh = GameState(wallet: freshWallet)
        try store.saveGameState(fresh)

        // Neutralize the ledger (no delete API — see doc comment).
        for entry in try store.loadLedgerEntries() {
            var cleared = entry
            cleared.metrics = .zero
            cleared.isClaimed = false
            cleared.containsUserEnteredData = false
            try store.upsertLedgerEntry(cleared)
        }
        return fresh
    }
}
#endif
