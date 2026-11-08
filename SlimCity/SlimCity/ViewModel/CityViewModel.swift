import Foundation
import SlimCityCore

/// Where the live wallet's resources come from. The two modes keep separate
/// wallets so the user can switch freely; only the HealthKit wallet is ever
/// persisted.
public enum ResourceMode: String, CaseIterable, Sendable {
    case healthKit
    case manual
}

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
    ///
    /// Always receives the PERSISTABLE state: the shared city plus the
    /// HealthKit wallet, whichever mode is active.
    public var onStateChanged: ((GameState) -> Void)?

    /// Which wallet `state` currently shows.
    public private(set) var resourceMode: ResourceMode = .healthKit
    /// The wallet of the mode that is NOT active. Never persisted when it is
    /// the manual one.
    private var inactiveWallet: ResourceBundle = ResourceBundle(material: 100, gold: 100, food: 100)

    public init(
        state: GameState = GameState(wallet: ResourceBundle(material: 100, gold: 100, food: 100)),
        catalog: BuildingCatalog = .default
    ) {
        self.state = state
        self.catalog = catalog
    }

    // MARK: Resource modes

    /// The HealthKit wallet, whether or not it is the active one.
    public var healthKitWallet: ResourceBundle {
        resourceMode == .healthKit ? state.wallet : inactiveWallet
    }

    /// The state to save: the shared city with the HealthKit wallet.
    var persistableState: GameState {
        guard resourceMode == .manual else { return state }
        return GameState(columns: state.columns, rows: state.rows, wallet: inactiveWallet, buildings: state.buildings)
    }

    /// Credits resources earned from health data to the HealthKit wallet, even
    /// while manual mode is showing, and persists. A zero bundle is a no-op.
    public func creditHealthKit(_ bundle: ResourceBundle) {
        guard !bundle.isEmpty else { return }
        if resourceMode == .healthKit {
            state.credit(bundle)
        } else {
            inactiveWallet = inactiveWallet + bundle
        }
        onStateChanged?(persistableState)
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
            onStateChanged?(persistableState)
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

    // MARK: Debug intents (DEBUG builds only)
    //
    // These exist purely to exercise the economy/claim loop from the in-app
    // debug menu without walking around. They go through the SAME frozen core
    // APIs the real game uses (`GameState.credit`, `onStateChanged`) and add no
    // new game rules — so debug numbers equal real ones. All of it is compiled
    // out of release builds.
    #if DEBUG

    /// Credits a single resource type by `amount` and persists via the same
    /// `onStateChanged` path a successful placement uses. A non-positive amount
    /// is a no-op (safe to spam from a stepper). Mirrors a daily grant of just
    /// that resource.
    public func debugCredit(_ type: ResourceType, amount: Int) {
        guard amount > 0 else { return }
        state.credit(ResourceBundle([type: amount]))
        onStateChanged?(persistableState)
    }

    /// Credits an arbitrary resource bundle (e.g. the aggregate grant from a
    /// simulated multi-day claim) and persists it. A zero bundle is a no-op.
    public func debugCredit(_ bundle: ResourceBundle) {
        guard !bundle.isEmpty else { return }
        state.credit(bundle)
        onStateChanged?(persistableState)
    }

    /// Switches which wallet is live. The departing mode's wallet is kept in
    /// memory and restored when the user switches back; the city is shared.
    /// The persisted state is always the HealthKit wallet, so switching never
    /// writes the manual wallet to disk.
    public func setResourceMode(_ mode: ResourceMode) {
        guard mode != resourceMode else { return }
        let departing = state.wallet
        state = GameState(columns: state.columns, rows: state.rows, wallet: inactiveWallet, buildings: state.buildings)
        inactiveWallet = departing
        resourceMode = mode
        onStateChanged?(persistableState)
    }

    /// Replaces the live city with a fresh one: default grid, a fresh wallet,
    /// no buildings. Clears any selection/feedback and forwards the new state so
    /// the caller can wipe persisted game state too. DESTRUCTIVE — the UI gates
    /// this behind a confirmation dialog.
    ///
    /// Note: clearing the *ledger* is not expressible through the view-model
    /// (it owns no store); the app layer handles that alongside this call. See
    /// `AppContainer.debugReset()`.
    public func debugReset(
        freshWallet: ResourceBundle = ActivityGrant.startingWallet,
        manualWallet: ResourceBundle = ResourceBundle(material: 100, gold: 100, food: 100)
    ) {
        let columns = state.columns
        let rows = state.rows
        // The HealthKit wallet restarts at one day's worth of each resource;
        // the manual sandbox wallet restarts at its own round numbers.
        let live = resourceMode == .healthKit ? freshWallet : manualWallet
        state = GameState(columns: columns, rows: rows, wallet: live)
        inactiveWallet = resourceMode == .healthKit ? manualWallet : freshWallet
        selectedBuildingID = nil
        lastFeedback = nil
        onStateChanged?(persistableState)
    }

    #endif
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
