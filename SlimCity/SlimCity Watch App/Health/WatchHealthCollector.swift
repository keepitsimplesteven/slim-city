import Foundation
import SlimCityCore
#if canImport(HealthKit)
import HealthKit
#endif

/// Watch-side daily metric collector. Mirrors the phone's query shape (anchored
/// 1-day `HKStatisticsCollectionQuery`) but trimmed to what the watch needs:
/// today's three metrics, to relay to the phone and show on the watch face.
///
/// Compiled only where HealthKit exists.
#if canImport(HealthKit)
public final class WatchHealthCollector: @unchecked Sendable {
    private let store: HKHealthStore
    private let calendar: Calendar
    private let stepType = HKQuantityType(.stepCount)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let exerciseType = HKQuantityType(.appleExerciseTime)

    public init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    @discardableResult
    public func requestAuthorization() async throws -> Bool {
        guard isAvailable else { return false }
        try await store.requestAuthorization(toShare: [], read: [stepType, energyType, exerciseType])
        return store.authorizationStatus(for: stepType) == .sharingAuthorized
    }

    /// Today's metrics as a single day sample.
    public func today() async throws -> WatchHealthPayload.DaySample {
        let now = Date()
        let dayKey = DayKey(date: now, calendar: calendar)
        let steps = try await sum(stepType, unit: .count())
        let energy = try await sum(energyType, unit: .kilocalorie())
        let exercise = try await sum(exerciseType, unit: .minute())
        let metrics = HealthMetrics(
            stepCount: Int(steps),
            activeEnergyKilocalories: energy,
            exerciseMinutes: exercise
        )
        return WatchHealthPayload.DaySample(day: dayKey, metrics: metrics)
    }

    private func sum(_ type: HKQuantityType, unit: HKUnit) async throws -> Double {
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }
}
#endif
