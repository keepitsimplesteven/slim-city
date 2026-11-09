import Foundation
import SlimCityCore
#if canImport(HealthKit)
import HealthKit
#endif

/// Live `ActivitySummaryProviding` backed by HealthKit's activity summaries
/// (the Move / Exercise / Stand rings). The watch writes these to Health and
/// they sync to the phone, so the phone reads them directly.
///
/// Compiled only where HealthKit exists.
#if canImport(HealthKit)
public final class ActivitySummaryService: ActivitySummaryProviding, @unchecked Sendable {
    private let store: HKHealthStore
    private let calendar: Calendar

    public init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    @discardableResult
    public func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.activitySummaryType()])
        return true
    }

    public func summaries(from start: DayKey, to end: DayKey) async throws -> [ActivitySummary] {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthDataError.unavailable }

        func components(_ key: DayKey) -> DateComponents {
            var c = DateComponents()
            c.calendar = self.calendar
            c.year = key.year
            c.month = key.month
            c.day = key.day
            return c
        }
        let predicate = HKQuery.predicate(
            forActivitySummariesBetweenStart: components(start),
            end: components(end)
        )
        let cal = self.calendar

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthDataError.queryFailed(error.localizedDescription))
                    return
                }
                let mapped = (results ?? []).compactMap { summary -> ActivitySummary? in
                    var parts = summary.dateComponents(for: cal)
                    parts.calendar = cal
                    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
                    return ActivitySummary(
                        day: DayKey(year: year, month: month, day: day),
                        moveKilocalories: summary.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                        moveGoalKilocalories: summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
                        exerciseMinutes: summary.appleExerciseTime.doubleValue(for: .minute()),
                        standHours: Int(summary.appleStandHours.doubleValue(for: .count()))
                    )
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }
}
#endif

/// Fallback for platforms without HealthKit: reports unavailable, no data.
public struct UnavailableActivitySummaryProvider: ActivitySummaryProviding {
    public init() {}
    public func requestAuthorization() async throws -> Bool { false }
    public func summaries(from start: DayKey, to end: DayKey) async throws -> [ActivitySummary] { [] }
}
