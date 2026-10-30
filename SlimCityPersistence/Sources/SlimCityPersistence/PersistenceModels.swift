import Foundation
import SwiftData
import SlimCityCore

// MARK: - SwiftData models (CloudKit-shaped)
//
// CLOUDKIT COMPATIBILITY RULES (followed here so enabling sync later is a flip,
// not a rewrite):
//   1. Every stored property has a default value or is optional.
//   2. No `@Attribute(.unique)` — CloudKit has no unique constraints.
//   3. Relationships are optional (and get an inverse).
// Sync is OFF in the MVP; see `PersistenceController` for the single place it
// flips on. These classes hold NO game rules — they convert to/from the pure
// `GameSnapshot`/`LedgerEntrySnapshot` transfer types, which own the mapping.

@Model
public final class StoredCity {
    // Defaulted scalars satisfy rule #1.
    public var columns: Int = 10
    public var rows: Int = 10
    public var walletMaterial: Int = 0
    public var walletGold: Int = 0
    public var walletFood: Int = 0

    // Optional relationship with inverse satisfies rules #1 and #3.
    @Relationship(deleteRule: .cascade, inverse: \StoredBuilding.city)
    public var buildings: [StoredBuilding]? = []

    public init() {}

    /// Rebuilds this stored city from a pure snapshot (replacing contents).
    public func apply(_ snapshot: GameSnapshot) {
        columns = snapshot.columns
        rows = snapshot.rows
        walletMaterial = snapshot.wallet[.material]
        walletGold = snapshot.wallet[.gold]
        walletFood = snapshot.wallet[.food]
        buildings = snapshot.buildings.map {
            StoredBuilding(definitionID: $0.definitionID, column: $0.column, row: $0.row)
        }
    }

    /// Produces a pure snapshot of this stored city.
    public func snapshot() -> GameSnapshot {
        GameSnapshot(
            columns: columns,
            rows: rows,
            wallet: ResourceBundle(material: walletMaterial, gold: walletGold, food: walletFood),
            buildings: (buildings ?? []).map {
                PlacedBuildingSnapshot(definitionID: $0.definitionID, column: $0.column, row: $0.row)
            }
        )
    }
}

@Model
public final class StoredBuilding {
    public var definitionID: String = ""
    public var column: Int = 0
    public var row: Int = 0
    // Optional inverse relationship (rule #3).
    public var city: StoredCity?

    public init(definitionID: String = "", column: Int = 0, row: Int = 0) {
        self.definitionID = definitionID
        self.column = column
        self.row = row
    }
}

@Model
public final class StoredLedgerEntry {
    public var year: Int = 0
    public var month: Int = 0
    public var day: Int = 0
    public var stepCount: Int = 0
    public var activeEnergyKilocalories: Double = 0
    public var exerciseMinutes: Double = 0
    public var isClaimed: Bool = false
    public var containsUserEnteredData: Bool = false

    public init() {}

    public func apply(_ snapshot: LedgerEntrySnapshot) {
        year = snapshot.year
        month = snapshot.month
        day = snapshot.day
        stepCount = snapshot.stepCount
        activeEnergyKilocalories = snapshot.activeEnergyKilocalories
        exerciseMinutes = snapshot.exerciseMinutes
        isClaimed = snapshot.isClaimed
        containsUserEnteredData = snapshot.containsUserEnteredData
    }

    public func snapshot() -> LedgerEntrySnapshot {
        LedgerEntrySnapshot(
            year: year, month: month, day: day,
            stepCount: stepCount,
            activeEnergyKilocalories: activeEnergyKilocalories,
            exerciseMinutes: exerciseMinutes,
            isClaimed: isClaimed,
            containsUserEnteredData: containsUserEnteredData
        )
    }
}
