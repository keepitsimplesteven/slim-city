import Foundation
import SlimCityCore

/// Plain, `Codable` transfer types that mirror the pure `SlimCityCore` domain
/// state for persistence.
///
/// WHY A SEPARATE SNAPSHOT LAYER:
/// The SwiftData `@Model` classes (see `PersistenceModels.swift`) cannot be the
/// domain truth — they carry framework machinery and CloudKit-shaped optional
/// fields. The pure core types can't import SwiftData. The snapshot sits between
/// them: it is pure Swift (buildable and testable without SwiftData) and defines
/// exactly how core state serializes. The `@Model` classes convert to/from these
/// snapshots, so the risky mapping logic lives here where it can be unit-tested.
public struct GameSnapshot: Equatable, Codable, Sendable {
    public var columns: Int
    public var rows: Int
    public var wallet: ResourceBundle
    public var buildings: [PlacedBuildingSnapshot]

    public init(columns: Int, rows: Int, wallet: ResourceBundle, buildings: [PlacedBuildingSnapshot]) {
        self.columns = columns
        self.rows = rows
        self.wallet = wallet
        self.buildings = buildings
    }
}

public struct PlacedBuildingSnapshot: Equatable, Codable, Sendable {
    public var definitionID: String
    public var column: Int
    public var row: Int

    public init(definitionID: String, column: Int, row: Int) {
        self.definitionID = definitionID
        self.column = column
        self.row = row
    }
}

public struct LedgerEntrySnapshot: Equatable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var stepCount: Int
    public var activeEnergyKilocalories: Double
    public var exerciseMinutes: Double
    public var isClaimed: Bool
    public var containsUserEnteredData: Bool

    public init(
        year: Int, month: Int, day: Int,
        stepCount: Int, activeEnergyKilocalories: Double, exerciseMinutes: Double,
        isClaimed: Bool, containsUserEnteredData: Bool
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.stepCount = stepCount
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.exerciseMinutes = exerciseMinutes
        self.isClaimed = isClaimed
        self.containsUserEnteredData = containsUserEnteredData
    }
}

// MARK: - Pure core <-> snapshot mapping
//
// This is the correctness-critical seam: round-tripping must preserve state
// exactly. It is pure Swift and fully unit-tested in this package.

public extension GameSnapshot {
    /// Builds a snapshot from pure game state.
    init(_ state: GameState) {
        self.init(
            columns: state.columns,
            rows: state.rows,
            wallet: state.wallet,
            buildings: state.buildings.map {
                PlacedBuildingSnapshot(
                    definitionID: $0.definitionID,
                    column: $0.position.column,
                    row: $0.position.row
                )
            }
        )
    }

    /// Reconstructs pure game state from a snapshot.
    func toGameState() -> GameState {
        GameState(
            columns: columns,
            rows: rows,
            wallet: wallet,
            buildings: buildings.map {
                PlacedBuilding(
                    definitionID: $0.definitionID,
                    position: GridPosition(column: $0.column, row: $0.row)
                )
            }
        )
    }
}

public extension LedgerEntrySnapshot {
    /// Builds a snapshot from a pure ledger entry.
    init(_ entry: DailyLedgerEntry) {
        self.init(
            year: entry.day.year,
            month: entry.day.month,
            day: entry.day.day,
            stepCount: entry.metrics.stepCount,
            activeEnergyKilocalories: entry.metrics.activeEnergyKilocalories,
            exerciseMinutes: entry.metrics.exerciseMinutes,
            isClaimed: entry.isClaimed,
            containsUserEnteredData: entry.containsUserEnteredData
        )
    }

    /// Reconstructs a pure ledger entry from a snapshot.
    func toLedgerEntry() -> DailyLedgerEntry {
        DailyLedgerEntry(
            day: DayKey(year: year, month: month, day: day),
            metrics: HealthMetrics(
                stepCount: stepCount,
                activeEnergyKilocalories: activeEnergyKilocalories,
                exerciseMinutes: exerciseMinutes
            ),
            isClaimed: isClaimed,
            containsUserEnteredData: containsUserEnteredData
        )
    }
}
