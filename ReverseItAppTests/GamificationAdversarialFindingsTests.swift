import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

/// Tests demonstrating the four findings that survived the adversarial-critic
/// review of the gamification layer. Each test pins down a concrete invariant
/// before any fix is applied.
///
/// - The `resetAllData` findings (#2, #3) assert the *desired* behaviour and so
///   currently FAIL — that failure is the demonstration that the bug is real.
/// - The points and sort findings (#1, #4) are characterization tests that
///   assert the *current* behaviour and PASS: #1 is a product/design decision
///   (should lowering a goal erase already-earned points?), and #4's disorder is
///   implementation-defined and can't be asserted as a reliable failure.
@MainActor
struct GamificationAdversarialFindingsTests {

    // MARK: - #2 EarnedAchievement survives resetAllData (clear bug — fails today)

    @Test func earnedAchievementsAreClearedByResetAllData() async throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12), carbs: 50, protein: 10, fat: 5, calories: 300, mealType: .lunch))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)
        let earned = try gamification.evaluateAchievements(userProfile: profile, modelContext: context, today: TestSupport.date(hour: 20))
        #expect(!earned.isEmpty)
        #expect(try context.fetch(FetchDescriptor<EarnedAchievement>()).isEmpty == false)

        try await context.resetAllData()

        // A full data reset should leave no earned achievements behind.
        // FAILS today: resetAllData() omits EarnedAchievement, so these persist.
        #expect(try context.fetch(FetchDescriptor<EarnedAchievement>()).isEmpty)
    }

    // MARK: - #3 GamificationProfile survives resetAllData (clear bug — fails today)

    @Test func gamificationProfileIsClearedByResetAllData() async throws {
        let context = try TestSupport.makeInMemoryContext()
        context.insert(UserProfile(name: "Test", age: 40, weight: 80, height: 175))
        context.insert(GamificationProfile(streakFreezesRemaining: 0, lastSeenLevel: 5))
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<GamificationProfile>()).count == 1)

        try await context.resetAllData()

        // A full data reset should not leave stale gamification state behind.
        // FAILS today: resetAllData() omits GamificationProfile.
        #expect(try context.fetch(FetchDescriptor<GamificationProfile>()).isEmpty)
    }

    // MARK: - #1 Goal changes are dated, so past days keep the goal they were
    //          logged under (fixed via GoalPeriod).

    @Test func pastDaysKeepTheCarbGoalTheyWereLoggedUnder() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(
            name: "Test", age: 40, weight: 80, height: 175,
            targetDailyCarbs: 150, targetDailyExerciseMinutes: 30
        )
        context.insert(profile)

        // Day 0, logged under the 150-carb goal: 1 glucose, 1 meal (100g, within
        // goal), and 30 min of exercise (meets the goal).
        context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8), value: 100, readingType: .fasting))
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12), carbs: 100, protein: 10, fat: 5, calories: 500, mealType: .lunch))
        context.insert(ExerciseEntry(type: ExerciseType.walking.rawValue, startTime: TestSupport.date(hour: 18), duration: 1800))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        let before = try gamification.totalPoints(userProfile: profile, modelContext: context)
        #expect(before == 60) // 5 glucose + 5 meal + 10 exercise + 15 carbGoal + 15 exerciseGoal + 10 fullDay

        // Three days later the user lowers their carb goal to 90 — recorded the
        // way Settings records it — and keeps the profile's current target in sync.
        try GoalPeriod.recordChange(
            previousCarbs: 150, previousExerciseMinutes: 30,
            newCarbs: 90, newExerciseMinutes: 30,
            on: TestSupport.date(hour: 0, dayOffset: 3), modelContext: context
        )
        profile.targetDailyCarbs = 90
        try context.save()

        // Day 0 is still judged against the 150 goal it was earned under, so the
        // lifetime total is unchanged.
        let after = try gamification.totalPoints(userProfile: profile, modelContext: context)
        #expect(after == 60)
    }

    @Test func daysLoggedAfterAGoalChangeUseTheNewGoal() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(
            name: "Test", age: 40, weight: 80, height: 175,
            targetDailyCarbs: 150, targetDailyExerciseMinutes: 30
        )
        context.insert(profile)

        // Lower the carb goal to 90, effective day 3.
        try GoalPeriod.recordChange(
            previousCarbs: 150, previousExerciseMinutes: 30,
            newCarbs: 90, newExerciseMinutes: 30,
            on: TestSupport.date(hour: 0, dayOffset: 3), modelContext: context
        )
        profile.targetDailyCarbs = 90

        // Day 5 (after the change) logs 100g carbs — now over the 90 goal.
        context.insert(FoodEntry(name: "Lunch", timestamp: TestSupport.date(hour: 12, dayOffset: 5), carbs: 100, protein: 10, fat: 5, calories: 500, mealType: .lunch))
        try context.save()

        let gamification = GamificationProfile()
        context.insert(gamification)

        let activities = try gamification.dailyActivities(userProfile: profile, modelContext: context)
        let day5 = Calendar.current.startOfDay(for: TestSupport.date(hour: 12, dayOffset: 5))
        #expect(activities[day5]?.withinCarbGoal == false)
    }

    // MARK: - #4 mostRecentAchievement breaks tied dates deterministically
    //          (fixed via a secondary sort on achievementID).

    @Test func mostRecentAchievementBreaksTiedDatesDeterministically() throws {
        let context = try TestSupport.makeInMemoryContext()
        let gamification = GamificationProfile()
        context.insert(gamification)

        // evaluateAchievements() stamps every badge unlocked in one call with the
        // same earnedDate, so ties are the normal case rather than an edge case.
        // Insert meal-first on purpose to prove the winner doesn't depend on order.
        let sameDate = TestSupport.date(hour: 20)
        for id in ["first-meal", "first-glucose"] {
            context.insert(EarnedAchievement(achievementID: id, earnedDate: sameDate))
        }
        try context.save()

        // The secondary sort on achievementID makes "first-glucose" the stable
        // winner (it sorts before "first-meal"), identical across repeated calls.
        let first = try gamification.mostRecentAchievement(modelContext: context)
        let second = try gamification.mostRecentAchievement(modelContext: context)
        #expect(first?.id == "first-glucose")
        #expect(first?.id == second?.id)
    }
}
