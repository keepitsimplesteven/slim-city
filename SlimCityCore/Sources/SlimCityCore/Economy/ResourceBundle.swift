/// An immutable, non-negative quantity of each resource type.
///
/// `ResourceBundle` is the core value type for the economy. It is used for
/// wallet balances, building costs, and daily grants. All arithmetic returns a
/// new bundle (value semantics) and quantities are clamped at zero so a wallet
/// can never go negative.
///
/// Amounts are integers: resources are whole units, which keeps the economy
/// deterministic and avoids floating-point drift in save files.
public struct ResourceBundle: Equatable, Codable, Sendable, Hashable {
    private var amounts: [ResourceType: Int]

    /// An empty bundle (zero of every resource).
    public static let zero = ResourceBundle()

    /// Creates a bundle. Missing resource types default to zero; any negative
    /// input is clamped to zero.
    public init(_ amounts: [ResourceType: Int] = [:]) {
        var cleaned: [ResourceType: Int] = [:]
        for type in ResourceType.allCases {
            cleaned[type] = max(0, amounts[type] ?? 0)
        }
        self.amounts = cleaned
    }

    /// Convenience initializer for the three MVP resources.
    public init(material: Int = 0, gold: Int = 0, food: Int = 0) {
        self.init([.material: material, .gold: gold, .food: food])
    }

    /// The quantity of a single resource type (always >= 0).
    public subscript(_ type: ResourceType) -> Int {
        amounts[type] ?? 0
    }

    /// True when every resource is zero.
    public var isEmpty: Bool {
        ResourceType.allCases.allSatisfy { self[$0] == 0 }
    }

    /// Returns a new bundle with `other` added component-wise.
    public func adding(_ other: ResourceBundle) -> ResourceBundle {
        var result: [ResourceType: Int] = [:]
        for type in ResourceType.allCases {
            result[type] = self[type] + other[type]
        }
        return ResourceBundle(result)
    }

    /// Returns a new bundle with `other` subtracted component-wise, clamped at
    /// zero. Use `canAfford(_:)` first if you need to know whether the full
    /// amount was available.
    public func subtracting(_ other: ResourceBundle) -> ResourceBundle {
        var result: [ResourceType: Int] = [:]
        for type in ResourceType.allCases {
            result[type] = self[type] - other[type]
        }
        // ResourceBundle.init clamps negatives to zero.
        return ResourceBundle(result)
    }

    /// True when this bundle has at least as much of every resource as `cost`.
    public func canAfford(_ cost: ResourceBundle) -> Bool {
        ResourceType.allCases.allSatisfy { self[$0] >= cost[$0] }
    }

    // MARK: Operators

    public static func + (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        lhs.adding(rhs)
    }

    public static func - (lhs: ResourceBundle, rhs: ResourceBundle) -> ResourceBundle {
        lhs.subtracting(rhs)
    }
}
