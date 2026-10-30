import Foundation
import SlimCityCore
#if canImport(HealthKit)
import HealthKit
#endif

/// Live `HealthDataProviding` backed by HealthKit.
///
/// Reads three metrics — step count, active energy, exercise minutes — tallied
/// per LOCAL day via `HKStatisticsCollectionQuery` anchored at local midnight
/// with a 1-day interval, and supports passive updates via an observer query +
/// background delivery. Results are converted to `DailyHealthSample` and are
/// meant to be written into the ledger by `DailyClaimCoordinator` /
/// `PersistenceController.upsertLedgerEntry(_:)`.
///
/// The manual-entry anti-cheat predicate is recorded only: each day's
/// `containsUserEnteredData` is set from `HKMetadataKeyWasUserEntered`, but the
/// policy stays `.passthrough` (OFF) per the spec — the frozen `AntiCheatPolicy`
/// decides whether to act on it later.
///
/// Compiled only where HealthKit exists; the whole type is behind
/// `#if canImport(HealthKit)` so the module still builds on platforms without it.
#if canImport(HealthKit)
public final class HealthKitService: HealthDataProviding, @unchecked Sendable {
    private let store: HKHealthStore
    private let calendar: Calendar

    private let stepType = HKQuantityType(.stepCount)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let exerciseType = HKQuantityType(.appleExerciseTime)

    private var readTypes: Set<HKObjectType> { [stepType, energyType, exerciseType] }

    public init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    public var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public func authorizationStatus() async -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else { return .denied }
        // Read authorization can't be introspected directly; infer from the
        // step type's request status.
        let status = store.authorizationStatus(for: stepType)
        switch status {
        case .sharingAuthorized: return .authorized
        case .sharingDenied:     return .denied
        default:                 return .notDetermined
        }
    }

    @discardableResult
    public func requestAuthorization() async throws -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else { throw HealthDataError.unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        return await authorizationStatus()
    }

    public func dailySamples(from start: DayKey, to end: DayKey) async throws -> [DailyHealthSample] {
        guard isHealthDataAvailable else { throw HealthDataError.unavailable }
        guard let startDate = start.startOfDay(in: calendar) else {
            throw HealthDataError.queryFailed("invalid start day")
        }
        let steps = try await collect(stepType, unit: .count(), from: startDate)
        let energy = try await collect(energyType, unit: .kilocalorie(), from: startDate)
        let exercise = try await collect(exerciseType, unit: .minute(), from: startDate)

        // Merge the three per-day dictionaries into samples across [start, end].
        var samples: [DailyHealthSample] = []
        var cursor = start
        while cursor <= end {
            let metrics = HealthMetrics(
                stepCount: Int(steps[cursor]?.value ?? 0),
                activeEnergyKilocalories: energy[cursor]?.value ?? 0,
                exerciseMinutes: exercise[cursor]?.value ?? 0
            )
            let userEntered =
                (steps[cursor]?.userEntered ?? false) ||
                (energy[cursor]?.userEntered ?? false) ||
                (exercise[cursor]?.userEntered ?? false)
            samples.append(DailyHealthSample(day: cursor, metrics: metrics, containsUserEnteredData: userEntered))
            guard let nextDate = startOfNextDay(after: cursor) else { break }
            cursor = DayKey(date: nextDate, calendar: calendar)
        }
        return samples
    }

    public func startObserving(onUpdate: @escaping @Sendable ([DailyHealthSample]) -> Void) async throws {
        guard isHealthDataAvailable else { throw HealthDataError.unavailable }
        for type in [stepType, energyType, exerciseType] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                guard let self else { completion(); return }
                Task {
                    let today = DayKey(date: Date(), calendar: self.calendar)
                    let weekStartDate = self.startOfDay(daysAgo: 6, from: today)
                    let week = weekStartDate.map { DayKey(date: $0, calendar: self.calendar) } ?? today
                    if let samples = try? await self.dailySamples(from: week, to: today) {
                        onUpdate(samples)
                    }
                    completion()
                }
            }
            store.execute(query)
            try await store.enableBackgroundDelivery(for: type, frequency: .daily)
        }
    }

    // MARK: - Helpers

    private struct DayValue { let value: Double; let userEntered: Bool }

    /// Runs an anchored 1-day `HKStatisticsCollectionQuery` and returns a
    /// per-DayKey sum. The user-entered flag is detected with a separate
    /// predicate so the result carries the anti-cheat hint.
    private func collect(_ type: HKQuantityType, unit: HKUnit, from startDate: Date) async throws -> [DayKey: DayValue] {
        let anchor = calendar.startOfDay(for: startDate)
        var interval = DateComponents(); interval.day = 1

        let sum: [DayKey: Double] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, error in
                if let error { continuation.resume(throwing: HealthDataError.queryFailed(error.localizedDescription)); return }
                var out: [DayKey: Double] = [:]
                results?.enumerateStatistics(from: anchor, to: Date()) { stat, _ in
                    let key = DayKey(date: stat.startDate, calendar: self.calendar)
                    out[key] = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }

        // Second pass: flag days containing any manually-entered sample.
        let entered = try await userEnteredDays(type, from: anchor)
        return sum.reduce(into: [:]) { acc, pair in
            acc[pair.key] = DayValue(value: pair.value, userEntered: entered.contains(pair.key))
        }
    }

    private func userEnteredDays(_ type: HKQuantityType, from anchor: Date) async throws -> Set<DayKey> {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered, operatorType: .equalTo, value: true)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if error != nil { continuation.resume(returning: []); return }
                let days = Set((samples ?? []).map { DayKey(date: $0.startDate, calendar: self.calendar) })
                continuation.resume(returning: days)
            }
            store.execute(query)
        }
    }

    private func startOfNextDay(after key: DayKey) -> Date? {
        guard let date = key.startOfDay(in: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: date)
    }

    private func startOfDay(daysAgo: Int, from key: DayKey) -> Date? {
        guard let date = key.startOfDay(in: calendar) else { return nil }
        return calendar.date(byAdding: .day, value: -daysAgo, to: date)
    }
}
#endif
