/// A cell coordinate on the city grid.
///
/// `column` is the x-axis, `row` is the y-axis, both zero-based from the
/// top-left/origin corner. The render layer (Task 6) maps this to isometric
/// world coordinates; the domain core treats it as a plain integer grid and has
/// no knowledge of how it is drawn.
public struct GridPosition: Equatable, Codable, Sendable, Hashable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}
