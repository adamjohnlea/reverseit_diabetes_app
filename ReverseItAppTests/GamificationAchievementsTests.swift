import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

struct GamificationAchievementsTests {
    @Test func catalogIdentifiersAreUnique() {
        let ids = Achievements.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func firstLogAchievementsUnlockImmediately() {
        var metrics = Achievements.Metrics()
        metrics.glucoseLogCount = 1
        metrics.mealLogCount = 1

        let earned = Achievements.newlyEarned(metrics: metrics, earnedIDs: [])
        let ids = Set(earned.map(\.id))
        #expect(ids.contains("first-glucose"))
        #expect(ids.contains("first-meal"))
        #expect(ids.contains("first-exercise") == false)
    }

    @Test func alreadyEarnedAchievementsAreNotReturned() {
        var metrics = Achievements.Metrics()
        metrics.glucoseLogCount = 1
        let firstPass = Achievements.newlyEarned(metrics: metrics, earnedIDs: [])
        #expect(firstPass.contains { $0.id == "first-glucose" })

        let secondPass = Achievements.newlyEarned(metrics: metrics, earnedIDs: Set(firstPass.map(\.id)))
        #expect(secondPass.contains { $0.id == "first-glucose" } == false)
    }

    @Test func thresholdAchievementsRequireTheThreshold() {
        var metrics = Achievements.Metrics()
        metrics.currentStreak = 6
        #expect(Achievements.newlyEarned(metrics: metrics, earnedIDs: []).contains { $0.id == "streak-7" } == false)

        metrics.currentStreak = 7
        #expect(Achievements.newlyEarned(metrics: metrics, earnedIDs: []).contains { $0.id == "streak-7" })
    }
}

@MainActor
struct GamificationAchievementIntegrationTests {
    @Test func evaluatingUnlocksAndPersistsAchievementsOnce() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12), carbs: 50, protein: 10, fat: 5, calories: 300, mealType: .lunch))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        let earned = try gamification.evaluateAchievements(
            userProfile: profile,
            modelContext: context,
            today: TestSupport.date(hour: 20)
        )
        let ids = Set(earned.map(\.id))
        #expect(ids.contains("first-glucose"))
        #expect(ids.contains("first-meal"))

        // A second evaluation with the same data earns nothing new.
        let again = try gamification.evaluateAchievements(
            userProfile: profile,
            modelContext: context,
            today: TestSupport.date(hour: 20)
        )
        #expect(again.isEmpty)

        let stored = try context.fetch(FetchDescriptor<EarnedAchievement>())
        #expect(stored.contains { $0.achievementID == "first-glucose" })
        #expect(stored.filter { $0.achievementID == "first-glucose" }.count == 1)
    }

    @Test func weeklyChallengeProgressIsReturnedForThisWeek() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        let gamification = GamificationProfile()
        context.insert(gamification)

        context.insert(FoodEntry(name: "Meal", timestamp: TestSupport.date(hour: 12), carbs: 40, protein: 10, fat: 5, calories: 250, mealType: .lunch))
        try context.save()

        let progress = try gamification.weeklyChallengeProgress(
            userProfile: profile,
            modelContext: context,
            date: TestSupport.date(hour: 20)
        )
        #expect(progress.count == WeeklyChallenges.countPerWeek)
    }
}
