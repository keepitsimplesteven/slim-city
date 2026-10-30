/// The set of building types available to place.
///
/// The catalog is the single source of truth for building definitions. Game
/// state stores only catalog ids; costs, scores, and render keys are resolved
/// here. All tunable values live in building definitions so Task 11's balancing
/// pass edits data, not logic.
public struct BuildingCatalog: Equatable, Sendable {
    public private(set) var definitions: [BuildingDefinition]

    public init(definitions: [BuildingDefinition]) {
        self.definitions = definitions
    }

    /// Looks up a definition by id. Returns nil if the id is unknown.
    public func definition(for id: String) -> BuildingDefinition? {
        definitions.first { $0.id == id }
    }

    /// The default MVP catalog: three placeholder building types, one keyed to
    /// each resource's "theme". Costs/scores are first-pass values for Task 11
    /// to tune. `modelName` values are the USDZ keys the render layer will look
    /// up (primitive fallback until real art is dropped in).
    public static let `default` = BuildingCatalog(definitions: [
        BuildingDefinition(
            id: "house",
            displayName: "House",
            cost: ResourceBundle(material: 20, gold: 10, food: 5),
            score: 10,
            modelName: "house"
        ),
        BuildingDefinition(
            id: "farm",
            displayName: "Farm",
            cost: ResourceBundle(material: 15, gold: 5, food: 0),
            score: 8,
            modelName: "farm"
        ),
        BuildingDefinition(
            id: "market",
            displayName: "Market",
            cost: ResourceBundle(material: 30, gold: 25, food: 10),
            score: 20,
            modelName: "market"
        )
    ])
}
