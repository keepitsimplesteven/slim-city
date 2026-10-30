import SwiftUI
import SceneKit
import simd
import SlimCityCore

/// Builds and owns the SceneKit scene for the isometric city: an orthographic
/// camera at a fixed ~45° angle, basic lighting, a ground grid, and one node per
/// placed building (positioned via `IsometricGridMapper`).
///
/// Rendering only — it reads a `GameState` and draws it. All rules stay in the
/// domain core; placement comes back through `CityViewModel`.
@MainActor
final class CitySceneController {
    let scene = SCNScene()
    let mapper: IsometricGridMapper
    private let factory: BuildingNodeFactory
    private let buildingsRoot = SCNNode()
    let cameraNode = SCNNode()

    init(gameState: GameState, factory: BuildingNodeFactory = BuildingNodeFactory(), tileSize: Double = 1.0) {
        self.mapper = IsometricGridMapper(gameState: gameState, tileSize: tileSize)
        self.factory = factory
        buildingsRoot.name = "buildingsRoot"
        scene.rootNode.addChildNode(buildingsRoot)
        configureCamera(for: gameState)
        configureLighting()
        addGroundGrid(for: gameState)
        rebuild(from: gameState)
    }

    /// Orthographic camera tilted to the classic isometric 3/4 view.
    private func configureCamera(for state: GameState) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        // Scale the ortho frame to fit the whole grid with margin.
        let span = Double(max(state.columns, state.rows)) * mapper.tileSize
        camera.orthographicScale = span * 0.62
        camera.zNear = 0.1
        camera.zFar = span * 10
        cameraNode.camera = camera
        // Position above and offset equally on X/Y/Z — the equal offsets create
        // the classic isometric 3/4 view — then AIM at the grid center with a
        // look-at constraint. (Setting eulerAngles by hand does not guarantee the
        // camera actually points at the grid, which left the scene off-screen.)
        let distance = Float(span)
        cameraNode.position = SCNVector3(distance, distance, distance)

        // The grid is centered on the world origin (see IsometricGridMapper), so
        // aim there.
        let lookAtTarget = SCNNode()
        lookAtTarget.position = SCNVector3Zero
        scene.rootNode.addChildNode(lookAtTarget)
        let lookAt = SCNLookAtConstraint(target: lookAtTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
        cameraNode.name = "isoCamera"
        scene.rootNode.addChildNode(cameraNode)
    }

    private func configureLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 800
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
    }

    /// A thin floor plus grid lines so empty tiles are visible.
    private func addGroundGrid(for state: GameState) {
        let width = CGFloat(Double(state.columns) * mapper.tileSize)
        let depth = CGFloat(Double(state.rows) * mapper.tileSize)
        let floor = SCNNode(geometry: SCNBox(width: width, height: 0.05, length: depth, chamferRadius: 0))
        floor.geometry?.firstMaterial?.diffuse.contents = PlatformColor(white: 0.22, alpha: 1)
        floor.position = SCNVector3(0, -0.025, 0)
        floor.name = "ground"
        scene.rootNode.addChildNode(floor)
    }

    /// Clears and rebuilds all building nodes from the current state.
    func rebuild(from state: GameState) {
        buildingsRoot.childNodes.forEach { $0.removeFromParentNode() }
        let catalog = BuildingCatalog.default
        for placed in state.buildings {
            guard let definition = catalog.definition(for: placed.definitionID) else { continue }
            let node = factory.node(for: definition)
            let world = mapper.worldCenter(of: placed.position)
            node.position = SCNVector3(Float(world.x), Float(node.position.y), Float(world.y))
            buildingsRoot.addChildNode(node)
        }
    }

    /// Converts a hit-test world point to a grid cell, if it lands on the grid.
    func gridPosition(atWorldX x: Float, z: Float) -> GridPosition? {
        mapper.gridPosition(atWorld: SIMD2(Double(x), Double(z)))
    }
}

#if canImport(UIKit)
import UIKit

/// Embeds the city `SCNView` in SwiftUI and routes taps to the view-model.
struct CitySceneView: UIViewRepresentable {
    let viewModel: CityViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let controller = CitySceneController(gameState: viewModel.state)
        context.coordinator.controller = controller
        view.scene = controller.scene
        view.pointOfView = controller.cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.scnView = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.controller?.rebuild(from: viewModel.state)
    }

    @MainActor
    final class Coordinator: NSObject {
        let viewModel: CityViewModel
        var controller: CitySceneController?
        weak var scnView: SCNView?

        init(viewModel: CityViewModel) { self.viewModel = viewModel }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView, let controller else { return }
            let point = gesture.location(in: scnView)
            let hits = scnView.hitTest(point, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            // Prefer the ground hit so we read a grid cell even when tapping near
            // an existing building's base.
            guard let hit = hits.first(where: { $0.node.name == "ground" }) ?? hits.first else { return }
            let world = hit.worldCoordinates
            if let cell = controller.gridPosition(atWorldX: world.x, z: world.z) {
                viewModel.placeSelected(at: cell)
                controller.rebuild(from: viewModel.state)
            }
        }
    }
}
#endif
