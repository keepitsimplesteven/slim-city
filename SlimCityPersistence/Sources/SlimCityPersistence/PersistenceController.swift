import Foundation
import SwiftData
import SlimCityCore

/// Owns the SwiftData `ModelContainer` and exposes save/load of game state and
/// the ledger in terms of pure `SlimCityCore` types.
///
/// The app (and watch) talk to this repository; they never touch `@Model`
/// classes directly. Internally it converts stored models <-> snapshots <->
/// pure core types, so the domain layer stays persistence-agnostic.
@available(iOS 17, watchOS 10, macOS 14, *)
public final class PersistenceController {
    public let container: ModelContainer

    /// Creates a controller.
    /// - Parameter inMemory: when true, nothing is written to disk (used for
    ///   tests and previews).
    ///
    /// CLOUDKIT SYNC — SINGLE FLIP POINT:
    /// To enable sync later, add the CloudKit entitlement to the app targets and
    /// set `cloudKitDatabase: .automatic` (or `.private("iCloud.<container>")`)
    /// on the `ModelConfiguration` below. No model changes are required because
    /// the `@Model` classes are already CloudKit-shaped. Keep it `.none` for the
    /// MVP.
    public init(inMemory: Bool = false) throws {
        let schema = Schema([
            StoredCity.self,
            StoredBuilding.self,
            StoredLedgerEntry.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none // <- flip to .automatic to enable sync
        )
        self.container = try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    private var context: ModelContext { container.mainContext }

    // MARK: - Game state

    /// Saves game state, replacing any existing city (the MVP has a single city).
    @MainActor
    public func saveGameState(_ state: GameState) throws {
        let snapshot = GameSnapshot(state)
        let existing = try context.fetch(FetchDescriptor<StoredCity>())
        let city: StoredCity
        if let first = existing.first {
            city = first
            // Clear old buildings so the cascade delete rule removes them.
            city.buildings = []
        } else {
            city = StoredCity()
            context.insert(city)
        }
        city.apply(snapshot)
        try context.save()
    }

    /// Loads the saved game state, or nil if none has been saved yet.
    ///
    /// Buildings are returned in a canonical order (by row, then column).
    /// SwiftData does not guarantee the fetch order of a to-many relationship,
    /// so sorting here makes load deterministic — important because
    /// `GameState`'s equality is order-sensitive on `buildings`, and the render
    /// layer benefits from a stable draw order.
    @MainActor
    public func loadGameState() throws -> GameState? {
        let cities = try context.fetch(FetchDescriptor<StoredCity>())
        guard let snapshot = cities.first?.snapshot() else { return nil }
        let ordered = snapshot.buildings.sorted {
            ($0.row, $0.column) < ($1.row, $1.column)
        }
        var canonical = snapshot
        canonical.buildings = ordered
        return canonical.toGameState()
    }

    // MARK: - Ledger

    /// Inserts or updates a ledger entry, keyed by its calendar day.
    @MainActor
    public func upsertLedgerEntry(_ entry: DailyLedgerEntry) throws {
        let snapshot = LedgerEntrySnapshot(entry)
        let y = snapshot.year, m = snapshot.month, d = snapshot.day
        let descriptor = FetchDescriptor<StoredLedgerEntry>(
            predicate: #Predicate { $0.year == y && $0.month == m && $0.day == d }
        )
        let existing = try context.fetch(descriptor)
        let model = existing.first ?? {
            let new = StoredLedgerEntry()
            context.insert(new)
            return new
        }()
        model.apply(snapshot)
        try context.save()
    }

    /// Loads all ledger entries as pure core types, oldest first.
    @MainActor
    public func loadLedgerEntries() throws -> [DailyLedgerEntry] {
        let models = try context.fetch(FetchDescriptor<StoredLedgerEntry>())
        return models
            .map { $0.snapshot().toLedgerEntry() }
            .sorted { $0.day < $1.day }
    }
}
