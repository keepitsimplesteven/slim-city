/// The kinds of resources a city accumulates and spends.
///
/// Each resource is earned from a distinct HealthKit metric (see `Economy`):
///   - `.material` from step count
///   - `.gold` from active energy burned
///   - `.food` from exercise minutes
///
/// The raw values are intentionally stable strings so they can be used as
/// persistence keys (SwiftData / future CloudKit records) without a separate
/// mapping table.
public enum ResourceType: String, CaseIterable, Codable, Sendable, Hashable {
    /// Building material, earned from steps.
    case material
    /// Currency, earned from active energy burned.
    case gold
    /// Food / population capacity, earned from exercise minutes.
    case food
}
