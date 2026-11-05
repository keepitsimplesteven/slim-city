#if DEBUG
import Foundation
import SlimCityCore

/// App-layer debug actions that the in-app debug menu drives. They sit above
/// the frozen core and reuse the SAME claim path the live game uses, so the
/// resources a simulated day grants equal the resources a real day would.
///
/// Scope: DEBUG builds only, pure orchestration over the injected `LedgerStore`
/// and the frozen economy/ledger APIs. No new game rules, no new core or
/// persistence APIs. The ledger-path simulation deliberately pushes synthetic
/// `DailyLedgerEntry` rows through the real `LedgerService.claim` so it also
/// exercises dedupe and the backfill-day cap.
///
/// Economy source of truth: `BalanceConfig.default`. That is the tuned MVP
/// balance the live claim loop resolves its rates and backfill cap from, so
/// debug numbers match production numbers (see the TODO "open questions").
struct DebugActions: Sendable {
    /// Where simulated days get their metrics from.
    enum MetricsSource: Equatable, Sendable {
        /// Reuse the most recent known day's metrics (last ledger entry).
        case previousDay
        /// Mean of the last 7 known days' metrics.
        case rollingSevenDayAverage
    }

    private let store: any LedgerStore
    private let config: BalanceConfig

    init(store: any LedgerStore, config: BalanceConfig = .default) {
        self.store = store
        self.config = config
    }

    // MARK: Reset

    /// Clears persisted game state and the ledger as far as the frozen
    /// persistence API allows.
    ///
    /// Game state: fully reset by saving a fresh `GameState` — `saveGameState`
    /// replaces the single stored city, so no delete API is needed.
    ///
    /// Ledger: the frozen `LedgerStore` surface exposes `upsert` + `load` but NO
    /// delete, so rows cannot be physically removed. We neutralize every entry
    /// instead — zero metrics, unclaimed — which clears all claim state and
    /// grant value. A truly empty table would need a new persistence API; per
    /// the TODO we note that gap rather than widen the frozen set.
    ///
    /// - Returns: the fresh state that was persisted, so the caller can push it
    ///   into the view-model.
    @discardableResult
    func resetPersistedState(
        freshWallet: ResourceBundle = ResourceBundle(material: 100, gold: 100, food: 100)
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

    // MARK: Simulate days

    /// The metrics a simulated day should use, resolved from the known ledger
    /// history per `source`. Returns `nil` when there is no history to base a
    /// simulation on (the UI can then disable "Simulate" or fall back).
    func simulationMetrics(for source: MetricsSource) throws -> HealthMetrics? {
        let known = try store.loadLedgerEntries()
            .filter { $0.metrics != .zero }
            .sorted { $0.day < $1.day }
        guard !known.isEmpty else { return nil }

        switch source {
        case .previousDay:
            return known.last?.metrics
        case .rollingSevenDayAverage:
            let window = known.suffix(7)
            let count = window.count
            guard count > 0 else { return nil }
            let totalSteps = window.reduce(0) { $0 + $1.metrics.stepCount }
            let totalKcal = window.reduce(0.0) { $0 + $1.metrics.activeEnergyKilocalories }
            let totalMins = window.reduce(0.0) { $0 + $1.metrics.exerciseMinutes }
            return HealthMetrics(
                stepCount: totalSteps / count,
                activeEnergyKilocalories: totalKcal / Double(count),
                exerciseMinutes: totalMins / Double(count)
            )
        }
    }

    /// Simulates `days` of activity through the REAL claim path: it writes
    /// synthetic unclaimed ledger rows for the most recent `days` days (bounded
    /// by the backfill cap, so this honestly reflects what the live loop would
    /// grant) and then runs `LedgerService.claim`, crediting the wallet exactly
    /// as a real collect would.
    ///
    /// Respecting the backfill cap is intentional (the TODO's "more honest"
    /// option): a simulation that out-ran the cap would report grants the real
    /// loop could never deliver.
    ///
    /// - Returns: the aggregate grant credited, or `.zero` when there is no
    ///   source history or `days <= 0`.
    @discardableResult
    func simulateDays(
        _ days: Int,
        source: MetricsSource,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> ResourceBundle {
        guard days > 0, let metrics = try simulationMetrics(for: source) else { return .zero }

        let service = config.makeLedgerService(calendar: calendar, clock: FixedClock(now))
        let cap = config.backfillDayLimit

        // The claim window is [earliest ... today]; only days inside it can be
        // claimed, so simulating more than the cap can't fabricate extra grants.
        let effectiveDays = min(days, cap)
        let startOfToday = calendar.startOfDay(for: now)

        var existing = Dictionary(
            uniqueKeysWithValues: try store.loadLedgerEntries().map { ($0.day, $0) }
        )

        // Fill the most recent `effectiveDays` days with synthetic metrics,
        // leaving them unclaimed so the real claim path grants them.
        for offset in 0..<effectiveDays {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            let key = DayKey(date: date, calendar: calendar)
            var entry = existing[key] ?? DailyLedgerEntry(day: key)
            // Don't touch a day that was already genuinely claimed.
            guard !entry.isClaimed else { continue }
            entry.metrics = metrics
            entry.isClaimed = false
            existing[key] = entry
            try store.upsertLedgerEntry(entry)
        }

        // Run the real claim over the full ledger and persist the result.
        let entries = try store.loadLedgerEntries()
        let (updated, result) = service.claim(entries: entries)
        guard !result.claimedDays.isEmpty else { return .zero }

        let claimed = Set(result.claimedDays)
        for entry in updated where claimed.contains(entry.day) {
            try store.upsertLedgerEntry(entry)
        }

        var state = (try store.loadGameState()) ?? GameState()
        state.credit(result.totalGrant)
        try store.saveGameState(state)
        return result.totalGrant
    }
}
#endif
