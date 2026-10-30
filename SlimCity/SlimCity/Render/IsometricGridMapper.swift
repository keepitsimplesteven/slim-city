import Foundation
import simd
import SlimCityCore

/// Pure, framework-light mapping between integer `GridPosition`s and continuous
/// world-space coordinates on the ground plane.
///
/// This type is deliberately split out from the live SceneKit scene so the
/// coordinate math can be unit-tested headlessly (no `SCNView`, no renderer).
/// `SceneView`/`BuildingNodeFactory` depend on it; it depends only on
/// `SlimCityCore` + `simd`.
///
/// Convention: the grid lies on SceneKit's X/Z ground plane (Y is up). A cell's
/// world position is its center. `column` runs along +X, `row` runs along +Z,
/// each cell `tileSize` world units wide. The grid is centered on the origin so
/// the camera can frame it symmetrically. "Isometric" is achieved by the
/// camera's orientation (see `SceneView`), NOT by skewing these coordinates —
/// keeping the mapping a plain affine transform makes it exactly invertible and
/// trivial to test.
public struct IsometricGridMapper: Equatable, Sendable {
    /// Number of columns (x) and rows (z) in the grid.
    public let columns: Int
    public let rows: Int
    /// World-space edge length of one square tile.
    public let tileSize: Double

    public init(columns: Int, rows: Int, tileSize: Double = 1.0) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.tileSize = tileSize > 0 ? tileSize : 1.0
    }

    /// Convenience: build a mapper sized to a game state's grid.
    public init(gameState: GameState, tileSize: Double = 1.0) {
        self.init(columns: gameState.columns, rows: gameState.rows, tileSize: tileSize)
    }

    /// Half the world-space extent of the whole grid, used to center it on origin.
    private var originOffset: SIMD2<Double> {
        SIMD2(
            (Double(columns) - 1) * tileSize / 2,
            (Double(rows) - 1) * tileSize / 2
        )
    }

    /// The world-space (x, z) center of a grid cell. Y (height) is caller-owned.
    public func worldCenter(of position: GridPosition) -> SIMD2<Double> {
        SIMD2(
            Double(position.column) * tileSize - originOffset.x,
            Double(position.row) * tileSize - originOffset.y
        )
    }

    /// The grid cell whose center is nearest a world-space (x, z) point, by
    /// rounding. Returns the cell even if it is off-grid; callers that need a
    /// valid cell should filter with `gridPosition(atWorld:)`.
    public func nearestCell(toWorld world: SIMD2<Double>) -> GridPosition {
        let shifted = world + originOffset
        let column = Int((shifted.x / tileSize).rounded())
        let row = Int((shifted.y / tileSize).rounded())
        return GridPosition(column: column, row: row)
    }

    /// The in-bounds grid cell at a world point, or nil if the point rounds to a
    /// cell outside the grid. This is the hit-test entry point the tap handler
    /// uses after converting a SceneKit hit to the ground plane.
    public func gridPosition(atWorld world: SIMD2<Double>) -> GridPosition? {
        let cell = nearestCell(toWorld: world)
        guard cell.column >= 0, cell.column < columns,
              cell.row >= 0, cell.row < rows else { return nil }
        return cell
    }
}
