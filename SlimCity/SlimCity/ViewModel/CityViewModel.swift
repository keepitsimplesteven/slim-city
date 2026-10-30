import Foundation
import SlimCityCore

/// The single bridge between the UI and the frozen domain core for the city
/// screen. It holds the current `GameState`, exposes the catalog for the build
/// menu, tracks the selected building, and translates tap/place intents into
/// `GameState.place(...)` calls — surfacing `PlacementError` as user-facing
/// feedback.
///
/// NO GAME RULES LIVE HERE. Affordability, bounds, occupancy, and cost
/// deduction are all enforced by `GameState`; this type only forwards intents
/// and formats the result. Keeping it `@MainActor @Observable` lets SwiftUI
/// drive the HUD/menu directly, while the placement logic stays unit-testable
/// because every method is pure over the injected `catalog` + current `state`.
@MainActor
@Observable
public final class CityViewModel {
    /// The live city. Private(set) so only intents mutate it.
    public private(set) var state: GameState
    /// The building catalog backing the build menu.
    public let catalog: BuildingCatalog
    /// The building type the user has selected to place, if any.
    public private(set) var selectedBuildingID: String?
    /// The most recent placement feedback, for the UI to display and clear.
    public private(set) var lastFeedback: PlacementFeedback?

    /// Optional persistence sink. When set, a successful placement saves state.
    /// Left as a closure so the view-model stays free of any SwiftData import
    /// and remains testable without a persistence stack.
    public var onStateChanged: ((GameState) -> Void)?

    public init(
        state: GameState = GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
        catalog: BuildingCatalog = .default
    ) {
        self.state = state
        self.catalog = catalog
    }

    // MARK: Derived UI data

    /// Wallet totals for the HUD, in a fixed resource order.
    public var walletTotals: [(type: ResourceType, amount: Int)] {
        ResourceType.allCases.map { ($0, state.wallet[$0]) }
    }

    /// Current city score, resolved through the catalog.
    public var score: Int { state.score(using: catalog) }

    /// Building types available in the build menu.
    public var menuBuildings: [BuildingDefinition] { catalog.definitions }

    /// The definition currently selected, if any.
    public var selectedDefinition: BuildingDefinition? {
        selectedBuildingID.flatMap { catalog.definition(for: $0) }
    }

    // MARK: Intents

    /// Selects a building type to place. Selecting the same one again clears it
    /// (toggle), which the menu uses to deselect.
    public func selectBuilding(id: String) {
        if selectedBuildingID == id {
            selectedBuildingID = nil
        } else {
            selectedBuildingID = id
            lastFeedback = nil
        }
    }

    /// Clears the current selection.
    public func clearSelection() {
        selectedBuildingID = nil
    }

    /// Attempts to place the selected building at a grid cell (e.g. from a scene
    /// hit-test). No-op with `.noSelection` feedback if nothing is selected.
    /// On success, forwards the new state to `onStateChanged`.
    @discardableResult
    public func placeSelected(at position: GridPosition) -> PlacementFeedback {
        guard let id = selectedBuildingID else {
            let feedback = PlacementFeedback.noSelection
            lastFeedback = feedback
            return feedback
        }
        return place(buildingID: id, at: position)
    }

    /// Attempts to place a specific building at a cell, surfacing the outcome.
    @discardableResult
    public func place(buildingID: String, at position: GridPosition) -> PlacementFeedback {
        do {
            let placed = try state.place(buildingID: buildingID, at: position, using: catalog)
            let feedback = PlacementFeedback.placed(placed)
            lastFeedback = feedback
            onStateChanged?(state)
            return feedback
        } catch {
            let feedback = PlacementFeedback.rejected(error)
            lastFeedback = feedback
            return feedback
        }
    }

    /// Clears the last feedback (e.g. after the UI has shown it).
    public func clearFeedback() {
        lastFeedback = nil
    }
}

/// The outcome of a placement intent, in UI-ready form.
public enum PlacementFeedback: Equatable, Sendable {
    /// Placed successfully.
    case placed(PlacedBuilding)
    /// Rejected by the domain core with a specific reason.
    case rejected(PlacementError)
    /// No building type was selected.
    case noSelection

    /// A short message suitable for a toast/banner.
    public var message: String {
        switch self {
        case .placed(let b):
            return "Placed \(b.definitionID)."
        case .noSelection:
            return "Select a building first."
        case .rejected(let error):
            switch error {
            case .insufficientResources: return "Not enough resources."
            case .tileOccupied:          return "That tile is occupied."
            case .outOfBounds:           return "That tile is off the grid."
            case .unknownBuilding:       return "Unknown building."
            }
        }
    }

    /// True when the intent changed the city.
    public var didPlace: Bool {
        if case .placed = self { return true }
        return false
    }
}
