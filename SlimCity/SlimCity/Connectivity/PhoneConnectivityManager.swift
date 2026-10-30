import Foundation
import SlimCityCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Phone-side WatchConnectivity receiver. Listens for `WatchHealthPayload`s from
/// the watch, reconciles them into the ledger via `LedgerReconciler` (dedupe by
/// `DayKey`, no double-count), and persists through the injected `LedgerStore`.
///
/// Transport only: all merge rules live in `LedgerReconciler`, all claim rules
/// in the frozen core. Compiled only where WatchConnectivity exists.
#if canImport(WatchConnectivity)
public final class PhoneConnectivityManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let store: any LedgerStore
    private let reconciler = LedgerReconciler()
    private let session: WCSession

    /// Called on the main actor after a successful reconcile, with the days
    /// written, so the UI can refresh its claimable count.
    public var onLedgerUpdated: (@Sendable ([DayKey]) -> Void)?

    public init?(store: any LedgerStore, session: WCSession = .default) {
        guard WCSession.isSupported() else { return nil }
        self.store = store
        self.session = session
        super.init()
        session.delegate = self
        session.activate()
    }

    /// Applies an already-decoded payload to the ledger. Factored out so it is
    /// exercisable without a live session.
    public func apply(_ payload: WatchHealthPayload) {
        let incoming = payload.days.map { $0.toLedgerEntry() }
        guard let current = try? store.loadLedgerEntries() else { return }
        let toWrite = reconciler.reconcile(incoming: incoming, into: current)
        for entry in toWrite { try? store.upsertLedgerEntry(entry) }
        onLedgerUpdated?(toWrite.map(\.day))
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let payload = try? WatchHealthPayload.from(dictionary: message) { apply(payload) }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let payload = try? WatchHealthPayload.from(dictionary: userInfo) { apply(payload) }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let payload = try? WatchHealthPayload.from(dictionary: applicationContext) { apply(payload) }
    }
}
#endif
