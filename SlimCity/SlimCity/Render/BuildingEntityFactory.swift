import Foundation
import RealityKit
import SlimCityCore

/// Builds the `Entity` for a building, preferring a real USDZ asset and
/// falling back to primitive geometry when none is bundled.
///
/// THE ASSET SEAM (Task 6 requirement, proven in Task 11): the factory looks up
/// `<modelName>.usdz` in the app bundle. If it exists, it is used as is; if
/// not, a colored box placeholder is returned. Swapping in real art is
/// therefore a pure asset drop — add `house.usdz` to the bundle and the house
/// renders as the model with ZERO code change here. The `modelName` passed in
/// is the `BuildingDefinition.modelName`.
///
/// RealityKit loads USDZ asynchronously, so call `preload(modelNames:)` once
/// (the scene does this while it is being made). After that, `entity(...)`
/// is synchronous and hands out clones of the loaded template.
@MainActor
public final class BuildingEntityFactory {
    /// Bundle searched for `<modelName>.usdz`. Defaults to the main app bundle;
    /// tests can inject a fixture bundle.
    public let bundle: Bundle
    /// Height of the primitive placeholder box, in world units.
    public let placeholderHeight: Float

    private var templates: [String: Entity] = [:]

    public init(bundle: Bundle = .main, placeholderHeight: Float = 0.6) {
        self.bundle = bundle
        self.placeholderHeight = placeholderHeight
    }

    /// True when a USDZ asset exists for the given model name, so the render
    /// path and tests can assert which branch will be taken WITHOUT loading it.
    public func hasModelAsset(named modelName: String) -> Bool {
        bundle.url(forResource: modelName, withExtension: "usdz") != nil
    }

    /// Loads every USDZ that exists for these model names. A file that fails to
    /// load is skipped, so that building degrades to the placeholder box.
    public func preload(modelNames: [String]) async {
        for name in Set(modelNames) where templates[name] == nil {
            guard let url = bundle.url(forResource: name, withExtension: "usdz") else { continue }
            if let loaded = try? await Entity(contentsOf: url) {
                templates[name] = loaded
            }
        }
    }

    /// Builds an entity for a catalog model name: a clone of the loaded USDZ,
    /// otherwise a primitive placeholder. Never returns nil: a missing asset
    /// degrades to a box rather than an empty scene.
    public func entity(forModelName modelName: String) -> Entity {
        if let template = templates[modelName] {
            let container = Entity()
            container.addChild(template.clone(recursive: true))
            container.name = "building:\(modelName)"
            return container
        }
        return primitiveEntity(for: modelName)
    }

    /// Convenience overload that resolves the model name from a definition.
    public func entity(for definition: BuildingDefinition) -> Entity {
        entity(forModelName: definition.modelName)
    }

    /// A simple colored box used until real art is dropped in. Color is derived
    /// deterministically from the name so the three default buildings are
    /// visually distinct without hard-coding a per-building palette.
    private func primitiveEntity(for modelName: String) -> Entity {
        let mesh = MeshResource.generateBox(
            width: 0.8, height: placeholderHeight, depth: 0.8, cornerRadius: 0.05
        )
        let material = SimpleMaterial(
            color: Self.placeholderColor(for: modelName), roughness: 0.8, isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        // Sit the box on the ground plane (its origin is its center).
        entity.position = SIMD3(0, placeholderHeight / 2, 0)
        entity.name = "building:\(modelName):primitive"
        return entity
    }

    /// Stable hue from a model name, so "house"/"farm"/"market" differ.
    static func placeholderColor(for modelName: String) -> PlatformColor {
        let hash = modelName.unicodeScalars.reduce(UInt32(0)) { ($0 &* 31) &+ $1.value }
        let hue = CGFloat(hash % 360) / 360.0
        return PlatformColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1)
    }
}

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#endif
