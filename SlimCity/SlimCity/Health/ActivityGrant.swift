import Foundation
import SlimCityCore

/// One day of Apple Activity ring data (the numbers the watch collects and
/// syncs to the phone's Health store).
public struct ActivitySummary: Equatable, Sendable {
    public let day: DayKey
    /// Active energy burned (the Move ring), in kilocalories.
    public let moveKilocalories: Double
    /// The user's Move goal for that day, in kilocalories. 0 means unknown.
    public let moveGoalKilocalories: Double
    /// Exercise ring minutes.
    public let exerciseMinutes: Double
    /// Stand ring hours.
    public let standHours: Int

    public init(
        day: DayKey,
        moveKilocalories: Double = 0,
        moveGoalKilocalories: Double = 0,
        exerciseMinutes: Double = 0,
        standHours: Int = 0
    ) {
        self.day = day
        self.moveKilocalories = max(0, moveKilocalories)
        self.moveGoalKilocalories = max(0, moveGoalKilocalories)
        self.exerciseMinutes = max(0, exerciseMinutes)
        self.standHours = max(0, standHours)
    }
}

/// HealthKit-mode economy: how much of each resource a day of ring activity is
/// worth. Pure and deterministic.
///
///   gold     = % of Move goal reached  -> up to 100 per day
///   food     = 1 per exercise minute   -> up to 30 per day
///   material = 1 per stand hour        -> up to 12 per day
public enum ActivityGrant {
    public static let maxGoldPerDay = 100
    public static let maxFoodPerDay = 30
    public static let maxMaterialPerDay = 12

    /// The total resources a day's activity has earned so far (not a delta).
    public static func target(for summary: ActivitySummary) -> ResourceBundle {
        let movePercent: Double = summary.moveGoalKilocalories > 0
            ? min(1, summary.moveKilocalories / summary.moveGoalKilocalories)
            : 0
        let gold = Int((movePercent * Double(maxGoldPerDay)).rounded(.down))
        let food = min(maxFoodPerDay, Int(summary.exerciseMinutes.rounded(.down)))
        let material = min(maxMaterialPerDay, summary.standHours)
        return ResourceBundle(material: material, gold: gold, food: food)
    }
}

/// Where per-day ring summaries come from. The live implementation reads
/// HealthKit; tests use a fake.
public protocol ActivitySummaryProviding: Sendable {
    /// Requests read access. Returns false when Health data is unavailable.
    @discardableResult
    func requestAuthorization() async throws -> Bool
    /// Summaries for each day in `[start, end]` that has one.
    func summaries(from start: DayKey, to end: DayKey) async throws -> [ActivitySummary]
}

/// Remembers how much has already been granted per day, so a day's resources
/// are credited once even though its ring totals grow through the day.
public protocol GrantRecordStore: Sendable {
    func granted(on day: DayKey) -> ResourceBundle
    func setGranted(_ bundle: ResourceBundle, on day: DayKey)
    func clear()
}

/// Thread-safe in-memory store, for tests and previews.
public final class InMemoryGrantRecordStore: GrantRecordStore, @unchecked Sendable {
    private let lock = NSLock()
    private var records: [DayKey: ResourceBundle] = [:]
    public init() {}
    public func granted(on day: DayKey) -> ResourceBundle {
        lock.lock(); defer { lock.unlock() }
        return records[day] ?? .zero
    }
    public func setGranted(_ bundle: ResourceBundle, on day: DayKey) {
        lock.lock(); defer { lock.unlock() }
        records[day] = bundle
    }
    public func clear() {
        lock.lock(); defer { lock.unlock() }
        records = [:]
    }
}

/// Persists grant records in `UserDefaults` as JSON. This is the HealthKit
/// side's only extra persistence; it avoids touching the frozen persistence API.
public final class UserDefaultsGrantRecordStore: GrantRecordStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = "healthkit.grantRecords.v1") {
        self.defaults = defaults
        self.key = key
    }

    private func dayString(_ day: DayKey) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    private func load() -> [String: ResourceBundle] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: ResourceBundle].self, from: data)
        else { return [:] }
        return decoded
    }

    public func granted(on day: DayKey) -> ResourceBundle {
        lock.lock(); defer { lock.unlock() }
        return load()[dayString(day)] ?? .zero
    }

    public func setGranted(_ bundle: ResourceBundle, on day: DayKey) {
        lock.lock(); defer { lock.unlock() }
        var all = load()
        all[dayString(day)] = bundle
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }
}

/// Turns ring summaries into wallet credits, once per earned unit.
///
/// For each day in the window, the credit is `target - alreadyGranted`
/// (floored at zero per resource). Re-running with the same data credits
/// nothing, and a day that grows later credits only the growth.
public struct HealthKitResourceSync: Sendable {
    private let provider: any ActivitySummaryProviding
    private let records: any GrantRecordStore
    private let windowDays: Int

    public init(provider: any ActivitySummaryProviding, records: any GrantRecordStore, windowDays: Int = 7) {
        self.provider = provider
        self.records = records
        self.windowDays = max(1, windowDays)
    }

    /// Reads the recent window and calls `credit` with the new resources, then
    /// records them as granted. Returns what was credited.
    @discardableResult
    public func sync(
        today: DayKey,
        calendar: Calendar = .current,
        credit: (ResourceBundle) -> Void
    ) async throws -> ResourceBundle {
        guard let todayDate = today.startOfDay(in: calendar),
              let startDate = calendar.date(byAdding: .day, value: -(windowDays - 1), to: todayDate)
        else { return .zero }
        let start = DayKey(date: startDate, calendar: calendar)

        let summaries = try await provider.summaries(from: start, to: today)
        var total = ResourceBundle.zero
        var newRecords: [(DayKey, ResourceBundle)] = []

        for summary in summaries where summary.day >= start && summary.day <= today {
            let target = ActivityGrant.target(for: summary)
            let done = records.granted(on: summary.day)
            let delta = ResourceBundle(
                material: max(0, target[.material] - done[.material]),
                gold: max(0, target[.gold] - done[.gold]),
                food: max(0, target[.food] - done[.food])
            )
            guard !delta.isEmpty else { continue }
            total = total + delta
            newRecords.append((summary.day, done + delta))
        }

        guard !total.isEmpty else { return .zero }
        credit(total)
        for (day, bundle) in newRecords { records.setGranted(bundle, on: day) }
        return total
    }
}
