import Foundation
import Testing
@testable import ReverseItApp

struct GamificationStreakTests {
    private let calendar = Calendar.current
    /// A fixed reference "today" (noon on the TestSupport reference day).
    private let today = TestSupport.date(hour: 12)

    /// The start-of-day `offset` days from the reference day.
    private func day(_ offset: Int) -> Date {
        let base = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: offset, to: base) ?? base
    }

    @Test func noActivityYieldsNoStreak() {
        let result = StreakCalculator.streak(activeDays: [Date](), today: today, freezesAvailable: 2)
        #expect(result.currentStreak == 0)
        #expect(result.isActiveToday == false)
    }

    @Test func consecutiveDaysCountWithoutFreezes() {
        let result = StreakCalculator.streak(
            activeDays: [day(0), day(-1), day(-2)],
            today: today,
            freezesAvailable: 2
        )
        #expect(result.currentStreak == 3)
        #expect(result.freezesUsed == 0)
        #expect(result.isActiveToday == true)
    }

    @Test func freezeBridgesAMissedDay() {
        // Active today and two days ago; yesterday missed; one freeze bridges it.
        let result = StreakCalculator.streak(
            activeDays: [day(0), day(-2)],
            today: today,
            freezesAvailable: 1
        )
        #expect(result.currentStreak == 2)
        #expect(result.freezesUsed == 1)
    }

    @Test func streakBreaksWhenNoFreezeRemains() {
        let result = StreakCalculator.streak(
            activeDays: [day(0), day(-2)],
            today: today,
            freezesAvailable: 0
        )
        #expect(result.currentStreak == 1)
        #expect(result.freezesUsed == 0)
    }

    @Test func todayIsGraceNotABreak() {
        // Nothing logged today, but yesterday and the day before are active.
        let result = StreakCalculator.streak(
            activeDays: [day(-1), day(-2)],
            today: today,
            freezesAvailable: 0
        )
        #expect(result.currentStreak == 2)
        #expect(result.isActiveToday == false)
    }

    @Test func trailingWeekCountsOnlyTheLastSevenDays() {
        let recent = [day(0), day(-1), day(-2), day(-4), day(-6)]
        #expect(StreakCalculator.activeDaysInTrailingWeek(activeDays: recent, today: today) == 5)
        #expect(StreakCalculator.meetsWeeklyConsistency(activeDays: recent, today: today) == true)

        // day(-7) falls outside the trailing 7-day window and is not counted.
        let withOlder = recent + [day(-7)]
        #expect(StreakCalculator.activeDaysInTrailingWeek(activeDays: withOlder, today: today) == 5)
    }
}
