import Foundation
import SlimCityCore

/// The wire payload relayed between the watch and the phone over
/// WatchConnectivity (or a shared App Group store).
///
/// It is a plain `Codable` value carrying one or more days of collected health
/// metrics plus the resource totals to display. Keeping it a pure type (no
/// `WCSession` import) means the encode/decode and the reconciliation logic are
/// unit-testable headlessly; the transport layer only moves the encoded bytes.
///
/// `DayKey` is the dedupe key: the phone merges incoming days into its ledger
/// and MUST NOT double-count a day that arrived from both watch and phone.
public struct WatchHealthPayload: Equatable, Codable, Sendable {
    /// Schema version so an older peer can reject an incompatible payload.
    public let version: Int
    /// The per-day samples the watch observed.
    public let days: [DaySample]
    /// Resource totals to mirror on the watch face (optional, phone -> watch).
    public let walletMaterial: Int
    public let walletGold: Int
    public let walletFood: Int

    public static let currentVersion = 1

    public init(days: [DaySample], wallet: ResourceBundle = .zero, version: Int = WatchHealthPayload.currentVersion) {
        self.version = version
        self.days = days
        self.walletMaterial = wallet[.material]
        self.walletGold = wallet[.gold]
        self.walletFood = wallet[.food]
    }

    public var wallet: ResourceBundle {
        ResourceBundle(material: walletMaterial, gold: walletGold, food: walletFood)
    }

    /// One day of metrics on the wire.
    public struct DaySample: Equatable, Codable, Sendable {
        public let year: Int
        public let month: Int
        public let day: Int
        public let stepCount: Int
        public let activeEnergyKilocalories: Double
        public let exerciseMinutes: Double
        public let containsUserEnteredData: Bool

        public init(day: DayKey, metrics: HealthMetrics, containsUserEnteredData: Bool = false) {
            self.year = day.year
            self.month = day.month
            self.day = day.day
            self.stepCount = metrics.stepCount
            self.activeEnergyKilocalories = metrics.activeEnergyKilocalories
            self.exerciseMinutes = metrics.exerciseMinutes
            self.containsUserEnteredData = containsUserEnteredData
        }

        public var dayKey: DayKey { DayKey(year: year, month: month, day: day) }
        public var metrics: HealthMetrics {
            HealthMetrics(stepCount: stepCount, activeEnergyKilocalories: activeEnergyKilocalories, exerciseMinutes: exerciseMinutes)
        }
        public func toLedgerEntry() -> DailyLedgerEntry {
            DailyLedgerEntry(day: dayKey, metrics: metrics, isClaimed: false, containsUserEnteredData: containsUserEnteredData)
        }
    }

    // MARK: Codec

    /// Encodes the payload to JSON bytes for the WatchConnectivity transport.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Decodes a payload from JSON bytes, rejecting an incompatible version.
    public static func decoded(from data: Data) throws -> WatchHealthPayload {
        let payload = try JSONDecoder().decode(WatchHealthPayload.self, from: data)
        guard payload.version == currentVersion else {
            throw WatchPayloadError.versionMismatch(payload.version)
        }
        return payload
    }

    /// Encodes to the `[String: Any]` dictionary WatchConnectivity transfers use.
    public func dictionaryRepresentation() throws -> [String: Any] {
        let data = try encoded()
        return ["payload": data]
    }

    /// Decodes from a WatchConnectivity transfer dictionary.
    public static func from(dictionary: [String: Any]) throws -> WatchHealthPayload {
        guard let data = dictionary["payload"] as? Data else {
            throw WatchPayloadError.missingPayload
        }
        return try decoded(from: data)
    }
}

public enum WatchPayloadError: Error, Equatable, Sendable {
    case versionMismatch(Int)
    case missingPayload
}
