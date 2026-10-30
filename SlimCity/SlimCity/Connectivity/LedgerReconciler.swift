import Foundation
import SlimCityCore

/// Merges ledger entries arriving from the watch into the phone's ledger
/// WITHOUT double-counting a day.
///
/// `DayKey` is the dedupe key (spec requirement). The rule, kept pure and
/// unit-tested:
///   - A day already present on the phone keeps its `isClaimed` flag — an
///     incoming watch copy of a claimed day can never un-claim it or re-grant
///     it.
///   - For an unclaimed existing day, the incoming metrics REPLACE the stored
///     ones only when they represent more activity (max per metric), so a stale
///     or partial relay never lowers a day's totals.
///   - A day the phone has never seen is added as-is (unclaimed).
///
/// The result is the set of entries to upsert; the caller persists them. No
/// grant is ever computed here — claiming stays with `LedgerService`.
public struct LedgerReconciler: Sendable {
    public init() {}

    /// Produces the merged entry for a single incoming day given the phone's
    /// current entry for that day (if any).
    public func merge(incoming: DailyLedgerEntry, existing: DailyLedgerEntry?) -> DailyLedgerEntry {
        guard let existing else { return incoming }

        // Never touch a claimed day: the grant is already banked.
        if existing.isClaimed { return existing }

        // Take the higher value per metric so a partial relay can't reduce totals.
        let merged = HealthMetrics(
            stepCount: max(existing.metrics.stepCount, incoming.metrics.stepCount),
            activeEnergyKilocalories: max(existing.metrics.activeEnergyKilocalories, incoming.metrics.activeEnergyKilocalories),
            exerciseMinutes: max(existing.metrics.exerciseMinutes, incoming.metrics.exerciseMinutes)
        )
        return DailyLedgerEntry(
            day: existing.day,
            metrics: merged,
            isClaimed: false,
            containsUserEnteredData: existing.containsUserEnteredData || incoming.containsUserEnteredData
        )
    }

    /// Reconciles a batch of incoming entries against the current ledger,
    /// returning only the entries that need to be written back (the merged
    /// form), keyed and deduped by `DayKey`.
    public func reconcile(incoming: [DailyLedgerEntry], into current: [DailyLedgerEntry]) -> [DailyLedgerEntry] {
        var byDay = Dictionary(current.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        var toWrite: [DailyLedgerEntry] = []

        // Dedupe the incoming batch itself by DayKey first (watch could send a
        // day twice), merging duplicates by max.
        var incomingByDay: [DayKey: DailyLedgerEntry] = [:]
        for entry in incoming {
            if let prior = incomingByDay[entry.day] {
                incomingByDay[entry.day] = merge(incoming: entry, existing: prior)
            } else {
                incomingByDay[entry.day] = entry
            }
        }

        for (day, entry) in incomingByDay {
            let merged = merge(incoming: entry, existing: byDay[day])
            if merged != byDay[day] {
                byDay[day] = merged
                toWrite.append(merged)
            }
        }
        return toWrite.sorted { $0.day < $1.day }
    }
}
