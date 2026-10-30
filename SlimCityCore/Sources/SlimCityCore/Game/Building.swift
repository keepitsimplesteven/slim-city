/// A building type that can be placed in the city.
///
/// Buildings are defined once in the `BuildingCatalog` and referenced by `id`.
/// A placed building (`PlacedBuilding`) stores only the catalog `id` plus its
/// grid location, so game state stays compact and the catalog remains the single
/// source of truth for cost/score/visuals.
///
/// `modelName` is the key the render layer (SceneKit, Task 6) uses to look up a
/// node: it loads a USDZ asset with this name if one exists, otherwise falls
/// back to primitive geometry. Keeping it here means adding real art later is a
/// pure asset drop with no code change.
public struct BuildingDefinition: Equatable, Codable, Sendable, Hashable, Identifiable {
    /// Stable identifier, used as the persistence key and catalog lookup key.
    public let id: String
    /// Human-readable name for menus.
    public let displayName: String
    /// Resource cost to place one of these.
    public let cost: ResourceBundle
    /// Score contributed to the city while placed.
    public let score: Int
    /// Render asset key (USDZ filename stem); primitive fallback if absent.
    public let modelName: String
    /// Passive per-tick production. Unused in the MVP (always `.zero`), but
    /// present so an idle/production system can be added later with no schema
    /// change. See the "Deferred" note in the plan.
    public let production: ResourceBundle

    public init(
        id: String,
        displayName: String,
        cost: ResourceBundle,
        score: Int,
        modelName: String,
        production: ResourceBundle = .zero
    ) {
        self.id = id
        self.displayName = displayName
        self.cost = cost
        self.score = max(0, score)
        self.modelName = modelName
        self.production = production
    }
}

/// An instance of a building placed on the grid.
///
/// Stores only the catalog id and location; everything else is looked up from
/// the catalog. This keeps persisted game state small and avoids duplicating
/// (and desyncing) cost/score data.
public struct PlacedBuilding: Equatable, Codable, Sendable, Hashable {
    public let definitionID: String
    public let position: GridPosition

    public init(definitionID: String, position: GridPosition) {
        self.definitionID = definitionID
        self.position = position
    }
}
