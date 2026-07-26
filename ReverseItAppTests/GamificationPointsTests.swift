import Foundation
import Testing
@testable import ReverseItApp

struct GamificationPointsTests {
    @Test func emptyDayScoresZero() {
        #expect(PointsRules.points(for: PointsRules.DailyActivity()).total == 0)
    }

    @Test func dailyCapsLimitRepeatedLogging() {
        let activity = PointsRules.DailyActivity(
            glucoseCount: 10,       // capped at 6
            mealCount: 6,           // capped at 4
            exerciseCount: 5,       // capped at 3
            postMealCheckCount: 5   // capped at 3
        )
        let breakdown = PointsRules.points(for: activity)
        #expect(breakdown.glucose == 6 * PointsRules.glucoseReading)
        #expect(breakdown.meals == 4 * PointsRules.meal)
        #expect(breakdown.exercise == 3 * PointsRules.exerciseSession)
        #expect(breakdown.postMealChecks == 3 * PointsRules.postMealCheck)
    }

    @Test func goalBonusesAreAllOrNothing() {
        let met = PointsRules.DailyActivity(mealCount: 1, hitExerciseGoal: true, withinCarbGoal: true)
        let metBreakdown = PointsRules.points(for: met)
        #expect(metBreakdown.exerciseGoal == PointsRules.exerciseGoalMet)
        #expect(metBreakdown.carbGoal == PointsRules.carbGoalMet)

        let notMet = PointsRules.DailyActivity(mealCount: 1)
        let notMetBreakdown = PointsRules.points(for: notMet)
        #expect(notMetBreakdown.exerciseGoal == 0)
        #expect(notMetBreakdown.carbGoal == 0)
    }

    @Test func fullDayBonusRequiresAllThreeEntryTypes() {
        let allThree = PointsRules.DailyActivity(glucoseCount: 1, mealCount: 1, exerciseCount: 1)
        #expect(PointsRules.points(for: allThree).fullDayBonus == PointsRules.fullLoggingDay)

        let missingExercise = PointsRules.DailyActivity(glucoseCount: 1, mealCount: 1)
        #expect(PointsRules.points(for: missingExercise).fullDayBonus == 0)
    }

    @Test func totalSumsEveryContribution() {
        // 2 glucose (10) + 1 meal (5) + 1 exercise (10) + 1 post-meal check (10)
        // + exercise goal (15) + carb goal (15) + full-day bonus (10) = 75
        let activity = PointsRules.DailyActivity(
            glucoseCount: 2,
            mealCount: 1,
            exerciseCount: 1,
            postMealCheckCount: 1,
            hitExerciseGoal: true,
            withinCarbGoal: true
        )
        #expect(PointsRules.points(for: activity).total == 75)
    }
}
