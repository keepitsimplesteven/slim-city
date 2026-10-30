import Foundation
import SceneKit
import SlimCityCore

/// Builds the `SCNNode` for a building, preferring a real USDZ asset and
/// falling back to primitive geometry when none is bundled.
///
/// THE ASSET SEAM (Task 6 requirement, proven in Task 11): the factory looks up
/// `<modelName>.usdz` in the app bundle. If it exists, it is loaded and used as
/// is; if not, a colored `SCNBox` placeholder is returned. Swapping in real art
/// is therefore a pure asset drop — add `house.usdz` to the bundle and the
/// house renders as the model with ZERO code change here. The `catalogName`
/// passed in is the `BuildingDefinition.modelName`.
public struct BuildingNodeFactory {
    /// Bundle searched for `<modelName>.usdz`. Defaults to the main app bundle;
    /// tests can inject a fixture bundle.
    public let bundle: Bundle
    /// Height of the primitive placeholder box, in world units.
    public let placeholderHeight: CGFloat

    public init(bundle: Bundle = .main, placeholderHeight: CGFloat = 0.6) {
        self.bundle = bundle
        self.placeholderHeight = placeholderHeight
    }

    /// Returns true when a USDZ asset exists for the given model name, so the
    /// render path and tests can assert which branch will be taken WITHOUT
    /// constructing a node (keeps this checkable off the main thread).
    public func hasModelAsset(named modelName: String) -> Bool {
        bundle.url(forResource: modelName, withExtension: "usdz") != nil
    }

    /// Builds a node for a catalog model name. Loads the USDZ if present,
    /// otherwise returns a primitive placeholder. Never returns nil: a missing
    /// asset degrades to a box rather than an empty scene.
    public func node(forModelName modelName: String) -> SCNNode {
        if let url = bundle.url(forResource: modelName, withExtension: "usdz"),
           let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) {
            let container = SCNNode()
            for child in scene.rootNode.childNodes {
                container.addChildNode(child)
            }
            container.name = "building:\(modelName)"
            return container
        }
        return primitiveNode(for: modelName)
    }

    /// Convenience overload that resolves the model name from a definition.
    public func node(for definition: BuildingDefinition) -> SCNNode {
        node(forModelName: definition.modelName)
    }

    /// A simple colored box used until real art is dropped in. Color is derived
    /// deterministically from the name so the three default buildings are
    /// visually distinct without hard-coding a per-building palette.
    private func primitiveNode(for modelName: String) -> SCNNode {
        let box = SCNBox(width: 0.8, height: placeholderHeight, length: 0.8, chamferRadius: 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = Self.placeholderColor(for: modelName)
        box.firstMaterial = material

        let node = SCNNode(geometry: box)
        // Sit the box on the ground plane (its origin is its center).
        node.position = SCNVector3(0, Float(placeholderHeight) / 2, 0)
        node.name = "building:\(modelName):primitive"
        return node
    }

    /// Stable hue from a model name, so "house"/"farm"/"market" differ.
    static func placeholderColor(for modelName: String) -> PlatformColor {
        let hash = modelName.unicodeScalars.reduce(UInt32(0)) { ($0 &* 31) &+ $0.value }
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
