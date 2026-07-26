import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

@MainActor
struct GamificationCelebrationTests {
    // Celebrations are gated on the baseline pass; see refreshRewards.
    private let today = TestSupport.date(hour: 20)

    @Test func theBaselineRefreshNeverCelebratesExistingProgress() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        // Data that already exists when rewards are switched on.
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        try context.save()
        let gamification = GamificationProfile()
        context.insert(gamification)

        let baseline = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(baseline.celebration == nil)
        #expect(gamification.hasEstablishedBaseline == true)
    }

    @Test func newBadgesAreCelebratedExactlyOnceAfterBaseline() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        let gamification = GamificationProfile()
        context.insert(gamification)

        // Baseline first (no data yet).
        _ = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)

        // Now the user logs their first reading.
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        try context.save()

        let earned = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(earned.celebration?.newBadges.contains { $0.id == "first-glucose" } == true)

        // A further refresh over the same data celebrates nothing.
        let again = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(again.celebration == nil)
    }

    @Test func levelUpIsCelebratedExactlyOnceAfterBaseline() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        // 95 points banked, still level 1 at baseline.
        let gamification = GamificationProfile(lifetimePointsCheckpoint: 95)
        context.insert(gamification)

        let baseline = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(baseline.celebration == nil)
        #expect(gamification.lastSeenLevel == 1)

        // A reading worth 5 points tips the total to 100 == level 2.
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        try context.save()

        let levelUp = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(levelUp.celebration?.newLevel?.level == 2)
        #expect(gamification.lastSeenLevel == 2)

        let again = try gamification.refreshRewards(userProfile: profile, modelContext: context, today: today)
        #expect(again.celebration?.newLevel == nil)
    }

    @Test func earnedAchievementDatesMapsIdentifiers() throws {
        let context = try TestSupport.makeInMemoryContext()
        let gamification = GamificationProfile()
        context.insert(gamification)
        context.insert(EarnedAchievement(achievementID: "first-glucose", earnedDate: TestSupport.date(hour: 8)))
        try context.save()

        let map = try gamification.earnedAchievementDates(modelContext: context)
        #expect(map["first-glucose"] != nil)
        #expect(map["first-meal"] == nil)
    }
}
