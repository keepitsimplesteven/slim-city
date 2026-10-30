/// SlimCityCore
///
/// The platform-agnostic domain core for Slim City.
///
/// This module contains ALL game logic: the resource economy, game/city state,
/// build rules, the building catalog, and the daily health ledger. It has NO
/// dependencies on UIKit, SwiftUI, SceneKit, HealthKit, or SwiftData, so it can
/// be unit-tested in isolation and reused unchanged as the rendering layer
/// migrates (SwiftUI placeholder -> SceneKit isometric) and as persistence and
/// HealthKit adapters are layered on top in the app targets.
///
/// Keep this rule intact: nothing in `SlimCityCore` may import a platform or
/// framework module. Adapters live in the app targets and depend on this core,
/// never the other way around.
public enum SlimCityCore {
    /// Semantic version of the core domain model. Bump when the public API changes
    /// so adapters can assert compatibility.
    public static let version = "0.1.0"
}
