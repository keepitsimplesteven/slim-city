import Testing
import Foundation
@testable import SlimCityCore

@Suite("DayKey")
struct DayKeyTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test("derives year/month/day in the calendar's timezone")
    func derivesComponents() {
        // 2026-03-15 12:00 UTC
        let date = Date(timeIntervalSince1970: 1_773_576_000)
        let key = DayKey(date: date, calendar: utc)
        #expect(key.year == 2026)
        #expect(key.month == 3)
        #expect(key.day == 15)
    }

    @Test("timezone changes which day an instant falls on")
    func timezoneBoundary() {
        // 2026-03-15 02:00 UTC == 2026-03-14 21:00 in UTC-5
        let date = Date(timeIntervalSince1970: 1_773_540_000)
        var eastern = Calendar(identifier: .gregorian)
        eastern.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
        let keyUTC = DayKey(date: date, calendar: utc)
        let keyEast = DayKey(date: date, calendar: eastern)
        #expect(keyUTC.day == 15)
        #expect(keyEast.day == 14) // previous day in the earlier timezone
    }

    @Test("ordering is chronological")
    func ordering() {
        #expect(DayKey(year: 2026, month: 1, day: 5) < DayKey(year: 2026, month: 2, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}

@Suite("LedgerService claiming")
struct LedgerServiceTests {
    // A deterministic service anchored at 2026-03-15 12:00 UTC, UTC calendar.
    private func service(backfill: Int = 7, antiCheat: AntiCheatPolicy = .passthrough) -> LedgerService {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_773_576_000) // 2026-03-15 12:00 UTC
        return LedgerService(
            calendar: utc,
            clock: FixedClock(now),
            economy: Economy(),
            antiCheat: antiCheat,
            backfillDayLimit: backfill
        )
    }

    private func day(_ d: Int) -> DayKey { DayKey(year: 2026, month: 3, day: d) }

    // One "unit day": 100 steps -> 1 material, 10 kcal -> 1 gold, 2 min -> 1 food.
    private func unitEntry(_ d: Int, claimed: Bool = false, userEntered: Bool = false) -> DailyLedgerEntry {
        DailyLedgerEntry(
            day: day(d),
            metrics: HealthMetrics(stepCount: 100, activeEnergyKilocalories: 10, exerciseMinutes: 2),
            isClaimed: claimed,
            containsUserEnteredData: userEntered
        )
    }

    @Test("claims 3 backfilled days into the correct aggregate grant")
    func backfillThreeDays() {
        let svc = service()
        let entries = [unitEntry(13), unitEntry(14), unitEntry(15)]
        let (updated, result) = svc.claim(entries: entries)

        // 3 unit-days -> 3 material, 3 gold, 3 food
        #expect(result.totalGrant == ResourceBundle(material: 3, gold: 3, food: 3))
        #expect(result.claimedDays == [day(13), day(14), day(15)])
        #expect(updated.allSatisfy { $0.isClaimed })
    }

    @Test("already-claimed days are not re-claimed (no double counting)")
    func noDoubleClaim() {
        let svc = service()
        let entries = [unitEntry(14, claimed: true), unitEntry(15)]
        let (updated, result) = svc.claim(entries: entries)
        #expect(result.totalGrant == ResourceBundle(material: 1, gold: 1, food: 1)) // only day 15
        #expect(result.claimedDays == [day(15)])
        #expect(updated.allSatisfy { $0.isClaimed })
    }

    @Test("claiming twice yields nothing the second time")
    func idempotentClaim() {
        let svc = service()
        let (afterFirst, first) = svc.claim(entries: [unitEntry(15)])
        let (_, second) = svc.claim(entries: afterFirst)
        #expect(first.totalGrant == ResourceBundle(material: 1, gold: 1, food: 1))
        #expect(second == .empty)
    }

    @Test("days older than the backfill cap are not claimable")
    func backfillCapExpires() {
        let svc = service(backfill: 3) // claimable: day 13, 14, 15
        let entries = [unitEntry(10), unitEntry(13), unitEntry(15)]
        let (_, result) = svc.claim(entries: entries)
        // day 10 is expired; only 13 and 15 claimed
        #expect(result.claimedDays == [day(13), day(15)])
        #expect(result.totalGrant == ResourceBundle(material: 2, gold: 2, food: 2))
    }

    @Test("future days are not claimable")
    func futureDaysIgnored() {
        let svc = service()
        let entries = [unitEntry(16), unitEntry(15)] // day 16 is tomorrow
        let (_, result) = svc.claim(entries: entries)
        #expect(result.claimedDays == [day(15)])
    }

    @Test("claimableDays lists eligible unclaimed days oldest first")
    func claimableListing() {
        let svc = service(backfill: 3)
        let entries = [unitEntry(10), unitEntry(13, claimed: true), unitEntry(14), unitEntry(15)]
        #expect(svc.claimableDays(in: entries) == [day(14), day(15)])
    }

    @Test("passthrough anti-cheat changes nothing")
    func antiCheatPassthrough() {
        let svc = service()
        let (_, result) = svc.claim(entries: [unitEntry(15, userEntered: true)])
        #expect(result.totalGrant == ResourceBundle(material: 1, gold: 1, food: 1))
    }

    @Test("anti-cheat can discard user-entered days when enabled")
    func antiCheatDiscardUserEntered() {
        let policy = AntiCheatPolicy(shouldDiscardUserEntered: true)
        let svc = service(antiCheat: policy)
        let (updated, result) = svc.claim(entries: [unitEntry(15, userEntered: true)])
        // Day is still marked claimed (consumed) but grants nothing.
        #expect(result.totalGrant == .zero)
        #expect(updated[0].isClaimed)
    }

    @Test("anti-cheat caps absurd daily values when configured")
    func antiCheatCaps() {
        let policy = AntiCheatPolicy(maxStepsPerDay: 50_000)
        let svc = service(antiCheat: policy)
        let entry = DailyLedgerEntry(
            day: day(15),
            metrics: HealthMetrics(stepCount: 1_000_000, activeEnergyKilocalories: 0, exerciseMinutes: 0)
        )
        let (_, result) = svc.claim(entries: [entry])
        #expect(result.totalGrant[.material] == 500) // 50_000 / 100, capped
    }
}
