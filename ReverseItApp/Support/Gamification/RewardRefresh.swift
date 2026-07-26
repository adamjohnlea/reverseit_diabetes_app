import Foundation
import SwiftData

/// Something worth celebrating after a reward refresh: a level-up, newly-earned
/// badges, or both.
struct Celebration: Identifiable {
    let id = UUID()
    /// Non-nil when the user has reached a new level since it was last seen.
    let newLevel: Levels.LevelProgress?
    /// Achievements unlocked but not yet acknowledged.
    let newBadges: [Achievement]

    /// Whether there is anything to show.
    var hasContent: Bool {
        newLevel != nil || !newBadges.isEmpty
    }
}

/// The outcome of a reward refresh: the up-to-date summary and any celebration.
struct RewardRefresh {
    let summary: RewardSummary
    let celebration: Celebration?
}

extension GamificationProfile {
    /// Runs a full reward refresh: awards new achievements, detects level-ups,
    /// marks everything acknowledged, and returns the fresh summary plus any
    /// celebration to present.
    ///
    /// Because celebrations are gated on the persisted `acknowledged` flag and
    /// `lastSeenLevel`, each level-up and badge is celebrated exactly once, even
    /// across app launches.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read and write.
    ///   - today: The reference "current day".
    func refreshRewards(
        userProfile: UserProfile,
        modelContext: ModelContext,
        today: Date = Date()
    ) throws -> RewardRefresh {
        // Top up the monthly freeze allotment if a new month has started.
        refillFreezesIfNeeded(now: today)

        // Award any newly-satisfied achievements (persists them).
        try evaluateAchievements(userProfile: userProfile, modelContext: modelContext, today: today)

        let summary = try rewardSummary(userProfile: userProfile, modelContext: modelContext, today: today)

        // First run: silently acknowledge whatever already exists so we never
        // celebrate progress the user had before rewards were switched on.
        if !hasEstablishedBaseline {
            let existing = try modelContext.fetch(
                FetchDescriptor<EarnedAchievement>(predicate: #Predicate { $0.acknowledged == false })
            )
            existing.forEach { $0.acknowledged = true }
            lastSeenLevel = summary.level.level
            hasEstablishedBaseline = true
            try modelContext.save()
            return RewardRefresh(summary: summary, celebration: nil)
        }

        // Collect everything earned but not yet celebrated.
        let unacknowledged = try modelContext.fetch(
            FetchDescriptor<EarnedAchievement>(
                predicate: #Predicate { $0.acknowledged == false },
                sortBy: [SortDescriptor(\.earnedDate)]
            )
        )
        let newBadges = unacknowledged.compactMap { earned in
            Achievements.catalog.first { $0.id == earned.achievementID }
        }

        // Detect a level-up against the last level we showed the user.
        var newLevel: Levels.LevelProgress?
        if summary.level.level > lastSeenLevel {
            newLevel = summary.level
        }

        // Acknowledge everything so it isn't celebrated again.
        unacknowledged.forEach { $0.acknowledged = true }
        lastSeenLevel = summary.level.level
        try modelContext.save()

        let celebration = Celebration(newLevel: newLevel, newBadges: newBadges)
        return RewardRefresh(summary: summary, celebration: celebration.hasContent ? celebration : nil)
    }

    /// Every earned achievement, keyed by achievement identifier.
    func earnedAchievementDates(modelContext: ModelContext) throws -> [String: Date] {
        let earned = try modelContext.fetch(FetchDescriptor<EarnedAchievement>())
        return Dictionary(earned.map { ($0.achievementID, $0.earnedDate) }) { first, _ in first }
    }
}
