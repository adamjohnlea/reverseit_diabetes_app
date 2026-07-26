import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

@MainActor
struct GamificationRewardSummaryTests {
    @Test func summaryReportsLevelLatestBadgeAndIncompleteChallenge() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12), carbs: 50, protein: 10, fat: 5, calories: 300, mealType: .lunch))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)
        try gamification.evaluateAchievements(userProfile: profile, modelContext: context, today: TestSupport.date(hour: 20))

        let summary = try gamification.rewardSummary(userProfile: profile, modelContext: context, today: TestSupport.date(hour: 20))
        #expect(summary.level.level == 1)
        #expect(summary.latestBadge != nil)
        // A single day of minimal logging can't complete a weekly challenge yet.
        #expect(summary.topChallenge?.isComplete == false)
    }

    @Test func mostRecentAchievementPrefersTheLatestDate() throws {
        let context = try TestSupport.makeInMemoryContext()
        let gamification = GamificationProfile()
        context.insert(gamification)
        context.insert(EarnedAchievement(achievementID: "first-glucose", earnedDate: TestSupport.date(hour: 8)))
        context.insert(EarnedAchievement(achievementID: "first-meal", earnedDate: TestSupport.date(hour: 12)))
        try context.save()

        let latest = try gamification.mostRecentAchievement(modelContext: context)
        #expect(latest?.id == "first-meal")
    }

    @Test func summaryHasNoBadgeBeforeAnyAreEarned() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        let gamification = GamificationProfile()
        context.insert(gamification)

        let summary = try gamification.rewardSummary(userProfile: profile, modelContext: context, today: TestSupport.date(hour: 20))
        #expect(summary.latestBadge == nil)
        #expect(summary.level.totalPoints == 0)
    }
}
