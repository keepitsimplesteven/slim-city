import Foundation
import simd

/// Pure pan/zoom math for the isometric camera, kept free of SceneKit so it can
/// be unit-tested headlessly.
///
/// The camera looks at `focus` (a point on the X/Z ground plane) from a fixed
/// (+1, +1, +1) direction, so the isometric look never changes: panning moves
/// the focus, zooming changes the orthographic scale. Nothing here rotates.
///
/// `scale` is the orthographic HALF-WIDTH in world units (the camera uses a
/// horizontal projection direction), so a given scale frames the same width on
/// any screen aspect.
struct CameraRig: Equatable {
    /// Ground point the camera aims at (x, z).
    private(set) var focus: SIMD2<Double> = .zero
    /// Orthographic half-width in world units. Smaller = zoomed in.
    private(set) var scale: Double

    let minScale: Double
    let maxScale: Double
    /// How far (per axis) the focus may drift from the grid center.
    let panLimit: Double

    /// Ground-plane unit vector pointing to screen-right for a (+1,+1,+1) camera.
    static let screenRight = SIMD2<Double>(1, -1) / 2.0.squareRoot()
    /// Ground-plane unit vector pointing to screen-up (away from the camera).
    static let screenUp = SIMD2<Double>(-1, -1) / 2.0.squareRoot()
    /// A vertical screen distance covers this many times more ground, because
    /// the ground plane is viewed at a shallow angle (1 / sin(35.26°)).
    static let verticalFactor = 3.0.squareRoot()

    /// - Parameter gridSpan: the larger grid side in world units.
    init(gridSpan: Double) {
        // Fits the whole rotated grid (diagonal ≈ 1.41 × span) with margin.
        let fit = gridSpan * 0.85
        self.scale = fit
        self.maxScale = fit
        self.minScale = max(gridSpan * 0.2, 0.5)
        self.panLimit = gridSpan * 0.5
    }

    /// Pans by a drag delta in points. Content follows the finger, so the
    /// camera moves the opposite way.
    mutating func pan(dx: Double, dy: Double, viewWidth: Double) {
        guard viewWidth > 0 else { return }
        let groundPerPoint = (2 * scale) / viewWidth
        let delta = (-dx * groundPerPoint) * Self.screenRight
            + (dy * groundPerPoint * Self.verticalFactor) * Self.screenUp
        focus += delta
        focus.x = min(max(focus.x, -panLimit), panLimit)
        focus.y = min(max(focus.y, -panLimit), panLimit)
    }

    /// Zooms by a pinch factor (>1 zooms in), clamped to the allowed range.
    mutating func zoom(by pinchScale: Double) {
        guard pinchScale > 0 else { return }
        scale = min(max(scale / pinchScale, minScale), maxScale)
    }
}
