import Foundation
import Testing
@testable import ReverseItApp

struct GamificationWeeklyChallengeTests {
    private let today = TestSupport.date(hour: 12)

    @Test func selectionIsDeterministicAndDistinct() {
        let first = WeeklyChallenges.challenges(forWeekContaining: today)
        let second = WeeklyChallenges.challenges(forWeekContaining: today)
        #expect(first.map(\.id) == second.map(\.id))          // stable week to week
        #expect(first.count == WeeklyChallenges.countPerWeek)
        #expect(Set(first.map(\.id)).count == first.count)     // no duplicates within a week
    }

    @Test func selectionRotatesBetweenWeeks() {
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let thisWeek = WeeklyChallenges.challenges(forWeekContaining: today).map(\.id)
        let following = WeeklyChallenges.challenges(forWeekContaining: nextWeek).map(\.id)
        #expect(thisWeek != following)
    }

    @Test func progressMapsEachKindToItsWeekMetric() {
        let week = WeeklyChallenges.WeekActivity(
            mealDays: 3,
            glucoseDays: 2,
            exerciseGoalDays: 4,
            carbGoalDays: 1,
            postMealCheckCount: 5,
            activeDays: 6
        )
        func progress(_ id: String) -> Int? {
            WeeklyChallenges.pool.first { $0.id == id }
                .map { WeeklyChallenges.currentProgress(for: $0, in: week) }
        }
        #expect(progress("meal-days-5") == 3)
        #expect(progress("glucose-days-5") == 2)
        #expect(progress("exercise-goal-4") == 4)
        #expect(progress("carb-goal-5") == 1)
        #expect(progress("post-meal-3") == 5)
        #expect(progress("active-6") == 6)
    }

    @Test func progressReportsCompletionAndFraction() {
        guard let challenge = WeeklyChallenges.pool.first(where: { $0.id == "exercise-goal-4" }) else {
            Issue.record("Expected exercise-goal-4 in the pool")
            return
        }
        let halfway = WeeklyChallenges.progress(for: challenge, in: .init(exerciseGoalDays: 2))
        #expect(halfway.isComplete == false)
        #expect(halfway.fraction == 0.5)

        let done = WeeklyChallenges.progress(for: challenge, in: .init(exerciseGoalDays: 4))
        #expect(done.isComplete == true)
        #expect(done.fraction == 1.0)
    }

    @Test func summarizeCountsDaysAndTotals() {
        let activities: [Date: PointsRules.DailyActivity] = [
            TestSupport.date(hour: 8, dayOffset: 0): .init(glucoseCount: 1, mealCount: 1, hitExerciseGoal: true, withinCarbGoal: true),
            TestSupport.date(hour: 8, dayOffset: 1): .init(mealCount: 2, postMealCheckCount: 2)
        ]
        let week = WeeklyChallenges.summarize(activities)
        #expect(week.mealDays == 2)
        #expect(week.glucoseDays == 1)
        #expect(week.exerciseGoalDays == 1)
        #expect(week.carbGoalDays == 1)
        #expect(week.postMealCheckCount == 2)
        #expect(week.activeDays == 2)
    }
}
