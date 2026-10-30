import Foundation
import SlimCityCore
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Watch-side WatchConnectivity sender. Activates the session and relays a
/// `WatchHealthPayload` of today's collected metrics to the phone. Prefers a
/// live `sendMessage` when reachable, falling back to `transferUserInfo` (queued
/// background delivery) otherwise, so a day's data is never lost when the phone
/// is asleep.
///
/// Transport only; the dedupe happens on the phone via `LedgerReconciler`.
#if canImport(WatchConnectivity)
public final class WatchConnectivityManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let session: WCSession

    public override init() {
        self.session = .default
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    /// Relays a payload to the phone. Returns the transport used, for logging.
    @discardableResult
    public func relay(_ payload: WatchHealthPayload) -> String {
        guard let dict = try? payload.dictionaryRepresentation() else { return "encode-failed" }
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { [weak self] _ in
                self?.session.transferUserInfo(dict)
            }
            return "message"
        } else {
            session.transferUserInfo(dict)
            return "userInfo"
        }
    }

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}
#endif
