import Foundation
import SwiftData

/// A compact snapshot of the user's gamification state, for summary surfaces
/// such as the Dashboard reward card.
struct RewardSummary {
    let level: Levels.LevelProgress
    let streak: StreakCalculator.StreakResult
    let freezesRemaining: Int
    /// The most useful challenge to surface: the first still-incomplete one, or
    /// the first challenge when every one is complete.
    let topChallenge: WeeklyChallengeProgress?
    /// The most recently earned achievement, if any.
    let latestBadge: Achievement?
}

extension GamificationProfile {
    /// Builds a `RewardSummary` for compact summary UI.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    ///   - today: The reference "current day".
    func rewardSummary(
        userProfile: UserProfile,
        modelContext: ModelContext,
        today: Date = Date()
    ) throws -> RewardSummary {
        let level = try levelProgress(userProfile: userProfile, modelContext: modelContext)
        let streak = try currentStreak(modelContext: modelContext, today: today)
        let challenges = try weeklyChallengeProgress(userProfile: userProfile, modelContext: modelContext, date: today)
        let topChallenge = challenges.first { !$0.isComplete } ?? challenges.first
        let latestBadge = try mostRecentAchievement(modelContext: modelContext)

        return RewardSummary(
            level: level,
            streak: streak,
            freezesRemaining: streakFreezesRemaining,
            topChallenge: topChallenge,
            latestBadge: latestBadge
        )
    }

    /// The most recently earned achievement, resolved to its catalog entry.
    ///
    /// Badges unlocked together in a single refresh share an `earnedDate`, so a
    /// secondary sort on `achievementID` keeps the chosen "latest" stable across
    /// calls and app launches rather than implementation-defined.
    func mostRecentAchievement(modelContext: ModelContext) throws -> Achievement? {
        var descriptor = FetchDescriptor<EarnedAchievement>(
            sortBy: [
                SortDescriptor(\.earnedDate, order: .reverse),
                SortDescriptor(\.achievementID)
            ]
        )
        descriptor.fetchLimit = 1
        guard let earned = try modelContext.fetch(descriptor).first else { return nil }
        return Achievements.catalog.first { $0.id == earned.achievementID }
    }
}
