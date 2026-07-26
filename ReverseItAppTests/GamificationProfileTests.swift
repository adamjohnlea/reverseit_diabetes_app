import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

@MainActor
struct GamificationProfileTests {
    @Test func totalPointsDerivesFromLoggedEntries() throws {
        let context = try TestSupport.makeInMemoryContext()
        // Default targets: 150 g carbs, 30 min exercise.
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)

        // One full day: two readings (one after-meal), a meal within the carb goal,
        // and 30 minutes of exercise (meets the goal exactly).
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 7), value: 95, readingType: .fasting))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 13), value: 130, readingType: .afterMeal))
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12), carbs: 50, protein: 20, fat: 10, calories: 400, mealType: .lunch))
        context.insert(ExerciseEntry(type: "Walking", startTime: TestSupport.date(hour: 18), duration: 1800, intensity: .moderate))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        // glucose 2×5=10 + post-meal check 1×10=10 + meal 5 + carb goal 15
        // + exercise 10 + exercise goal 15 + full-day bonus 10 = 75
        #expect(try gamification.totalPoints(userProfile: profile, modelContext: context) == 75)
        #expect(try gamification.levelProgress(userProfile: profile, modelContext: context).level == 1)
    }

    @Test func totalPointsIncludesTheCheckpoint() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        let gamification = GamificationProfile(lifetimePointsCheckpoint: 500)
        context.insert(gamification)

        #expect(try gamification.totalPoints(userProfile: profile, modelContext: context) == 500)
    }

    @Test func exerciseGoalBonusRequiresMeetingTheTarget() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175) // 30 min goal
        context.insert(profile)
        // Only 20 minutes — below the goal, so just the session points, no bonus.
        context.insert(ExerciseEntry(type: "Walking", startTime: TestSupport.date(hour: 18), duration: 1200))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        #expect(try gamification.totalPoints(userProfile: profile, modelContext: context) == 10)
    }

    @Test func streakReflectsLoggedDays() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8, dayOffset: -1), value: 100))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 105))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        let streak = try gamification.currentStreak(modelContext: context, today: TestSupport.date(hour: 20))
        #expect(streak.currentStreak == 2)
        #expect(streak.isActiveToday == true)
    }
}
