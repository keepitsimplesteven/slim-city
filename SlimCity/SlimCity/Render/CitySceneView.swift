import SwiftUI
import RealityKit
import simd
import SlimCityCore

/// Builds and owns the RealityKit scene for the isometric city: an orthographic
/// camera at a fixed ~45° angle, basic lighting, a ground grid, and one entity
/// per placed building (positioned via `IsometricGridMapper`).
///
/// Rendering only — it reads a `GameState` and draws it. All rules stay in the
/// domain core; placement comes back through `CityViewModel`.
@MainActor
final class CitySceneController {
    /// Everything the scene draws hangs off this entity.
    let root = Entity()
    let mapper: IsometricGridMapper
    private let factory: BuildingEntityFactory
    private let buildingsRoot = Entity()
    private let cameraEntity = Entity()
    private var cameraOffset = SIMD3<Float>.zero
    private var rig = CameraRig(gridSpan: 10)
    private let span: Double

    /// RealityKit's `OrthographicCameraComponent.scale` per unit of `CameraRig.scale`
    /// (the rig's value is the half-width of the view in world units).
    private static let cameraScaleFactor: Float = 1

    /// Pans the view by a drag delta in points (content follows the finger).
    func pan(dx: Double, dy: Double, viewWidth: Double) {
        rig.pan(dx: dx, dy: dy, viewWidth: viewWidth)
        applyRig()
    }

    /// Zooms by a pinch factor (>1 zooms in).
    func zoom(by pinchScale: Double) {
        rig.zoom(by: pinchScale)
        applyRig()
    }

    /// The grid cell under a screen point, if it lands on the grid. The tap is
    /// turned into a ground point by the camera math, not by a renderer hit test.
    func gridPosition(atScreen point: CGPoint, viewSize: CGSize) -> GridPosition? {
        let ground = rig.groundPoint(
            screenX: Double(point.x), screenY: Double(point.y),
            viewWidth: Double(viewSize.width), viewHeight: Double(viewSize.height)
        )
        return mapper.gridPosition(atWorld: ground)
    }

    /// Aims the camera at the focus from the fixed isometric offset, and sets zoom.
    private func applyRig() {
        let focus = SIMD3<Float>(Float(rig.focus.x), 0, Float(rig.focus.y))
        cameraEntity.look(at: focus, from: focus + cameraOffset, relativeTo: nil)
        cameraEntity.components[OrthographicCameraComponent.self]?.scale =
            Float(rig.scale) * Self.cameraScaleFactor
    }

    // The factory defaults to nil, not `BuildingEntityFactory()`: default-argument
    // values run in a nonisolated context, and the factory is main-actor.
    init(gameState: GameState, factory: BuildingEntityFactory? = nil, tileSize: Double = 1.0) {
        self.mapper = IsometricGridMapper(gameState: gameState, tileSize: tileSize)
        self.factory = factory ?? BuildingEntityFactory()
        self.span = Double(max(gameState.columns, gameState.rows)) * tileSize
        buildingsRoot.name = "buildingsRoot"
        root.addChild(buildingsRoot)
        configureCamera()
        configureLighting()
        addGroundGrid(for: gameState)
        rebuild(from: gameState)
    }

    /// Loads building models. Call once, before the first `rebuild`, so the
    /// USDZ houses show instead of the placeholder boxes.
    func preload() async {
        await factory.preload(modelNames: BuildingCatalog.default.definitions.map(\.modelName))
    }

    /// Orthographic camera tilted to the classic isometric 3/4 view.
    private func configureCamera() {
        // Horizontal projection: the scale is the half-WIDTH, so the whole board
        // fits a portrait phone screen (vertical fit cut it off).
        rig = CameraRig(gridSpan: span)
        var camera = OrthographicCameraComponent()
        camera.scaleDirection = .horizontal
        camera.near = 0.1
        camera.far = Float(span * 10)
        cameraEntity.components.set(camera)
        // Offset equally on X/Y/Z — the equal offsets create the classic
        // isometric 3/4 view — then AIM at the focus with a look-at. Panning moves
        // the focus and camera together, so the angle never changes.
        let distance = Float(span)
        cameraOffset = SIMD3(distance, distance, distance)
        cameraEntity.name = "isoCamera"
        root.addChild(cameraEntity)
        applyRig()
    }

    private func configureLighting() {
        // RealityKit's virtual camera supplies soft ambient light of its own;
        // this adds the sun, matching the old SceneKit direction.
        let sun = DirectionalLight()
        sun.light.intensity = 2500
        sun.orientation = simd_quatf(angle: Float.pi / 5, axis: [0, 1, 0])
            * simd_quatf(angle: -Float.pi / 3, axis: [1, 0, 0])
        root.addChild(sun)
    }

    /// A thin floor plus grid lines so empty tiles are visible.
    private func addGroundGrid(for state: GameState) {
        let width = Float(Double(state.columns) * mapper.tileSize)
        let depth = Float(Double(state.rows) * mapper.tileSize)
        // The floor shows through the gaps between tiles, so it acts as the
        // grid outline: the tile color tinted slightly toward white.
        let floorMaterial = SimpleMaterial(color: PlatformColor(white: 0.38, alpha: 1), roughness: 1, isMetallic: false)
        let floor = ModelEntity(
            mesh: .generateBox(width: width, height: 0.05, depth: depth),
            materials: [floorMaterial]
        )
        floor.position = SIMD3(0, -0.025, 0)
        floor.name = "ground"
        root.addChild(floor)

        // One slightly inset tile per cell in the original ground color.
        let inset = Float(mapper.tileSize) * 0.94
        let tileMaterial = SimpleMaterial(color: PlatformColor(white: 0.22, alpha: 1), roughness: 1, isMetallic: false)
        let tileMesh = MeshResource.generateBox(width: inset, height: 0.01, depth: inset)
        let tilesRoot = Entity()
        tilesRoot.name = "groundTiles"
        for column in 0..<state.columns {
            for row in 0..<state.rows {
                let center = mapper.worldCenter(of: GridPosition(column: column, row: row))
                let tile = ModelEntity(mesh: tileMesh, materials: [tileMaterial])
                tile.name = "ground"
                tile.position = SIMD3(Float(center.x), 0.005, Float(center.y))
                tilesRoot.addChild(tile)
            }
        }
        root.addChild(tilesRoot)
    }

    /// Clears and rebuilds all building entities from the current state.
    func rebuild(from state: GameState) {
        buildingsRoot.children.removeAll()
        let catalog = BuildingCatalog.default
        for placed in state.buildings {
            guard let definition = catalog.definition(for: placed.definitionID) else { continue }
            let entity = factory.entity(for: definition)
            let world = mapper.worldCenter(of: placed.position)
            entity.position = SIMD3(Float(world.x), entity.position.y, Float(world.y))
            buildingsRoot.addChild(entity)
        }
    }
}

#if canImport(UIKit)
/// Embeds the city `RealityView` in SwiftUI and routes taps to the view-model.
struct CitySceneView: View {
    let viewModel: CityViewModel

    @State private var controller: CitySceneController?
    @State private var lastDrag = CGSize.zero
    @State private var lastMagnification = 1.0

    var body: some View {
        // Read the state here so SwiftUI re-runs `update` when it changes.
        let state = viewModel.state
        GeometryReader { geometry in
            RealityView { content in
                let controller = CitySceneController(gameState: viewModel.state)
                await controller.preload()
                controller.rebuild(from: viewModel.state)
                content.camera = .virtual
                content.add(controller.root)
                self.controller = controller
            } update: { _ in
                controller?.rebuild(from: state)
            }
            .realityViewCameraControls(.none)
            .gesture(
                SpatialTapGesture().onEnded { tap in
                    guard let controller,
                          let cell = controller.gridPosition(atScreen: tap.location, viewSize: geometry.size)
                    else { return }
                    viewModel.placeSelected(at: cell)
                }
            )
            // Pan (one finger drag) and pinch-zoom. A tap still places; a drag
            // past the minimum distance becomes a pan instead.
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { drag in
                    let step = CGSize(
                        width: drag.translation.width - lastDrag.width,
                        height: drag.translation.height - lastDrag.height
                    )
                    lastDrag = drag.translation
                    controller?.pan(dx: step.width, dy: step.height, viewWidth: geometry.size.width)
                }
                .onEnded { _ in lastDrag = .zero }
            )
            .simultaneousGesture(
                MagnifyGesture().onChanged { pinch in
                    controller?.zoom(by: pinch.magnification / lastMagnification)
                    lastMagnification = pinch.magnification
                }
                .onEnded { _ in lastMagnification = 1 }
            )
        }
    }
}
#endif
