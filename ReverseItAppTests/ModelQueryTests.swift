import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

@MainActor
struct ModelQueryTests {
    @Test func totalCarbsForDayRespectsDayBoundaries() throws {
        let context = try TestSupport.makeInMemoryContext()
        let day = TestSupport.date(hour: 12)

        context.insert(makeFood(carbs: 10, timestamp: TestSupport.date(hour: 8)))
        context.insert(makeFood(carbs: 20, timestamp: TestSupport.date(hour: 20)))
        context.insert(makeFood(carbs: 99, timestamp: TestSupport.date(hour: 8, dayOffset: -1)))
        try context.save()

        #expect(try FoodEntry.totalCarbsForDay(day, modelContext: context) == 30)
    }

    @Test func totalDurationForDayRespectsDayBoundaries() throws {
        let context = try TestSupport.makeInMemoryContext()
        let day = TestSupport.date(hour: 12)

        context.insert(ExerciseEntry(type: "Walking", startTime: TestSupport.date(hour: 7), duration: 600))
        context.insert(ExerciseEntry(type: "Running", startTime: TestSupport.date(hour: 18), duration: 1200))
        context.insert(ExerciseEntry(type: "Cycling", startTime: TestSupport.date(hour: 7, dayOffset: 1), duration: 9999))
        try context.save()

        #expect(try ExerciseEntry.totalDurationForDay(day, modelContext: context) == 1800)
    }

    @Test func totalCaloriesForDayMixesMeasuredAndEstimated() throws {
        let context = try TestSupport.makeInMemoryContext()
        let day = TestSupport.date(hour: 12)

        // Measured: 200 kcal. Estimated: 30 min moderate at 70 kg = 147 kcal.
        context.insert(ExerciseEntry(type: "Rowing", startTime: TestSupport.date(hour: 7), duration: 1200, caloriesBurned: 200))
        context.insert(ExerciseEntry(type: "Running", startTime: TestSupport.date(hour: 18), duration: 1800, intensity: .moderate))
        try context.save()

        let total = try ExerciseEntry.totalCaloriesForDay(day, weightKg: 70, modelContext: context)
        #expect(abs(total - 347.0) < 0.001)
    }

    @Test func fetchLatestReadingsLimitsAndSortsDescending() throws {
        let context = try TestSupport.makeInMemoryContext()

        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 12), value: 110))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 16), value: 120))
        try context.save()

        let latest = try GlucoseReading.fetchLatestReadings(2, modelContext: context)
        #expect(latest.count == 2)
        #expect(latest.map(\.value) == [120, 110])
    }

    @Test func averageForPeriodOnlyIncludesReadingsInWindow() throws {
        let context = try TestSupport.makeInMemoryContext()

        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 9), value: 100))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 11), value: 140))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 9, dayOffset: -2), value: 999))
        try context.save()

        let average = try GlucoseReading.averageForPeriod(
            start: TestSupport.date(hour: 0),
            end: TestSupport.date(hour: 23),
            modelContext: context
        )
        #expect(average == 120)
    }

    @Test func averageForPeriodIsNilWithoutReadings() throws {
        let context = try TestSupport.makeInMemoryContext()
        let average = try GlucoseReading.averageForPeriod(
            start: TestSupport.date(hour: 0),
            end: TestSupport.date(hour: 23),
            modelContext: context
        )
        #expect(average == nil)
    }

    private func makeFood(carbs: Double, timestamp: Date) -> FoodEntry {
        FoodEntry(
            name: "Meal",
            timestamp: timestamp,
            carbs: carbs,
            protein: 0,
            fat: 0,
            calories: carbs * FoodEntry.Energy.caloriesPerGramOfCarbs,
            mealType: .lunch
        )
    }
}
