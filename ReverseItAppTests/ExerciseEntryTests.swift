import Foundation
import Testing
@testable import ReverseItApp

struct ExerciseEntryTests {
    @Test func estimatedCaloriesUsesMETFormula() {
        let entry = ExerciseEntry(type: "Running", duration: 1800, intensity: .moderate)
        // 30 min × 4.0 METs × 3.5 × 70 kg ÷ 200 = 147 kcal
        #expect(abs(entry.estimatedCalories(weightKg: 70) - 147.0) < 0.001)
    }

    @Test func estimatedCaloriesPrefersMeasuredValue() {
        let entry = ExerciseEntry(type: "Running", duration: 1800, caloriesBurned: 250, intensity: .moderate)
        #expect(entry.estimatedCalories(weightKg: 70) == 250)
    }

    @Test func formattedDurationIncludesHoursOnlyWhenNeeded() {
        #expect(ExerciseEntry(type: "Walking", duration: 3900).formattedDuration == "1h 5m")
        #expect(ExerciseEntry(type: "Walking", duration: 1800).formattedDuration == "30m")
    }

    @Test func progressTowardDailyGoalCapsAtOne() {
        let long = ExerciseEntry(type: "Walking", duration: 3600)
        #expect(long.progressTowardDailyGoal(targetMinutes: 30) == 1.0)

        let short = ExerciseEntry(type: "Walking", duration: 900)
        #expect(short.progressTowardDailyGoal(targetMinutes: 30) == 0.5)
    }
}
