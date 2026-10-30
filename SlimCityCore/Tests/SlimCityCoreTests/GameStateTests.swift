import Testing
@testable import SlimCityCore

@Suite("BuildingCatalog")
struct BuildingCatalogTests {
    @Test("default catalog contains the three MVP buildings")
    func defaultCatalog() {
        let catalog = BuildingCatalog.default
        #expect(catalog.definition(for: "house") != nil)
        #expect(catalog.definition(for: "farm") != nil)
        #expect(catalog.definition(for: "market") != nil)
        #expect(catalog.definition(for: "nonexistent") == nil)
    }

    @Test("definitions carry a model name for the render layer")
    func modelNames() {
        let house = BuildingCatalog.default.definition(for: "house")
        #expect(house?.modelName == "house")
    }

    @Test("production defaults to zero in the MVP")
    func productionIsZero() {
        for def in BuildingCatalog.default.definitions {
            #expect(def.production == .zero)
        }
    }
}

@Suite("GameState placement")
struct GameStatePlacementTests {
    private let catalog = BuildingCatalog.default

    private func fundedState() -> GameState {
        // Enough to place several buildings.
        GameState(columns: 5, rows: 5, wallet: ResourceBundle(material: 200, gold: 200, food: 200))
    }

    @Test("placing a building deducts its exact cost and records it")
    func placeDeductsCost() throws {
        var state = fundedState()
        let house = catalog.definition(for: "house")!
        let before = state.wallet

        try state.place(buildingID: "house", at: GridPosition(column: 1, row: 1), using: catalog)

        #expect(state.buildings.count == 1)
        #expect(state.wallet == before - house.cost)
        #expect(state.building(at: GridPosition(column: 1, row: 1))?.definitionID == "house")
    }

    @Test("placing on an occupied tile is rejected and leaves state unchanged")
    func rejectsOccupied() throws {
        var state = fundedState()
        let pos = GridPosition(column: 2, row: 2)
        try state.place(buildingID: "house", at: pos, using: catalog)
        let snapshot = state

        #expect(throws: PlacementError.tileOccupied) {
            try state.place(buildingID: "farm", at: pos, using: catalog)
        }
        #expect(state == snapshot) // unchanged
    }

    @Test("placing out of bounds is rejected")
    func rejectsOutOfBounds() {
        var state = fundedState()
        #expect(throws: PlacementError.outOfBounds) {
            try state.place(buildingID: "house", at: GridPosition(column: 99, row: 0), using: catalog)
        }
        #expect(throws: PlacementError.outOfBounds) {
            try state.place(buildingID: "house", at: GridPosition(column: -1, row: 0), using: catalog)
        }
    }

    @Test("placing an unaffordable building is rejected and leaves state unchanged")
    func rejectsUnaffordable() {
        var state = GameState(columns: 5, rows: 5, wallet: ResourceBundle(material: 1, gold: 1, food: 1))
        let snapshot = state
        #expect(throws: PlacementError.insufficientResources) {
            try state.place(buildingID: "market", at: GridPosition(column: 0, row: 0), using: catalog)
        }
        #expect(state == snapshot)
    }

    @Test("placing an unknown building id is rejected")
    func rejectsUnknown() {
        var state = fundedState()
        #expect(throws: PlacementError.unknownBuilding) {
            try state.place(buildingID: "castle", at: GridPosition(column: 0, row: 0), using: catalog)
        }
    }

    @Test("full session: credit a grant, place several, verify wallet and score")
    func fullSession() throws {
        var state = GameState(columns: 5, rows: 5)
        // Simulate a claimed daily grant.
        state.credit(ResourceBundle(material: 100, gold: 100, food: 100))

        try state.place(buildingID: "house", at: GridPosition(column: 0, row: 0), using: catalog)
        try state.place(buildingID: "farm", at: GridPosition(column: 1, row: 0), using: catalog)
        try state.place(buildingID: "market", at: GridPosition(column: 2, row: 0), using: catalog)

        // Costs: house(20,10,5) + farm(15,5,0) + market(30,25,10) = (65,40,15)
        #expect(state.wallet == ResourceBundle(material: 35, gold: 60, food: 85))
        // Score: 10 + 8 + 20
        #expect(state.score(using: catalog) == 38)
        #expect(state.buildings.count == 3)
    }

    @Test("score ignores buildings whose id is not in the catalog")
    func scoreIgnoresUnknown() {
        let state = GameState(
            columns: 3, rows: 3,
            buildings: [PlacedBuilding(definitionID: "ghost", position: GridPosition(column: 0, row: 0))]
        )
        #expect(state.score(using: catalog) == 0)
    }
}
