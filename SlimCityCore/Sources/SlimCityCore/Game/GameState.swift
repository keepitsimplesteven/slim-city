/// The reason a build action could not be completed.
///
/// Returned (via `PlacementError`) so the UI layer can show specific feedback
/// without re-deriving the cause. The domain core owns all these rules; the
/// view only reacts.
public enum PlacementError: Error, Equatable, Sendable {
    /// The target cell is outside the grid bounds.
    case outOfBounds
    /// The target cell already has a building.
    case tileOccupied
    /// The wallet can't cover the building's cost.
    case insufficientResources
    /// The building id isn't in the catalog.
    case unknownBuilding
}

/// The full mutable state of a city: grid size, wallet, and placed buildings.
///
/// This is the central domain aggregate. All mutations go through its methods so
/// invariants (non-negative wallet, no overlaps, in-bounds) are enforced in one
/// place. It is a pure value type with no persistence or rendering concerns; the
/// SwiftData layer (Task 5) maps to/from it, and the render layer (Task 6) reads
/// it.
public struct GameState: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public private(set) var wallet: ResourceBundle
    public private(set) var buildings: [PlacedBuilding]

    public init(
        columns: Int = 10,
        rows: Int = 10,
        wallet: ResourceBundle = .zero,
        buildings: [PlacedBuilding] = []
    ) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.wallet = wallet
        self.buildings = buildings
    }

    // MARK: Queries

    /// True when the position lies within the grid.
    public func isInBounds(_ position: GridPosition) -> Bool {
        position.column >= 0 && position.column < columns &&
        position.row >= 0 && position.row < rows
    }

    /// The building occupying a cell, if any.
    public func building(at position: GridPosition) -> PlacedBuilding? {
        buildings.first { $0.position == position }
    }

    /// True when a cell has no building.
    public func isEmpty(at position: GridPosition) -> Bool {
        building(at: position) == nil
    }

    /// The total score of all placed buildings, resolved via the catalog.
    /// Buildings whose id is not in the catalog contribute zero.
    public func score(using catalog: BuildingCatalog) -> Int {
        buildings.reduce(0) { total, placed in
            total + (catalog.definition(for: placed.definitionID)?.score ?? 0)
        }
    }

    // MARK: Mutations

    /// Adds resources to the wallet (e.g. a claimed daily grant).
    public mutating func credit(_ amount: ResourceBundle) {
        wallet = wallet + amount
    }

    /// Attempts to place a building at a position, enforcing all rules:
    /// known building, in bounds, empty tile, affordable. On success the cost is
    /// deducted and the building recorded. On failure the state is unchanged and
    /// a `PlacementError` describing the cause is thrown.
    @discardableResult
    public mutating func place(
        buildingID: String,
        at position: GridPosition,
        using catalog: BuildingCatalog
    ) throws(PlacementError) -> PlacedBuilding {
        guard let definition = catalog.definition(for: buildingID) else {
            throw .unknownBuilding
        }
        guard isInBounds(position) else {
            throw .outOfBounds
        }
        guard isEmpty(at: position) else {
            throw .tileOccupied
        }
        guard wallet.canAfford(definition.cost) else {
            throw .insufficientResources
        }

        wallet = wallet - definition.cost
        let placed = PlacedBuilding(definitionID: buildingID, position: position)
        buildings.append(placed)
        return placed
    }
}
