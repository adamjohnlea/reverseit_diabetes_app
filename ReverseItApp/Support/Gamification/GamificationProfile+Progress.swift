import Foundation
import SwiftData

extension GamificationProfile {
    // MARK: - Weekly challenges

    /// Per-day activity for the calendar week containing `date`.
    func weekActivities(
        userProfile: UserProfile,
        modelContext: ModelContext,
        weekContaining date: Date,
        calendar: Calendar = .current
    ) throws -> [Date: PointsRules.DailyActivity] {
        let all = try dailyActivities(userProfile: userProfile, modelContext: modelContext)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [:] }
        return all.filter { $0.key >= week.start && $0.key < week.end }
    }

    /// This week's challenges, each paired with the user's current progress.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    ///   - date: A date within the week of interest.
    func weeklyChallengeProgress(
        userProfile: UserProfile,
        modelContext: ModelContext,
        date: Date = Date()
    ) throws -> [WeeklyChallengeProgress] {
        let activities = try weekActivities(
            userProfile: userProfile,
            modelContext: modelContext,
            weekContaining: date
        )
        let summary = WeeklyChallenges.summarize(activities)
        return WeeklyChallenges.challenges(forWeekContaining: date).map {
            WeeklyChallenges.progress(for: $0, in: summary)
        }
    }

    // MARK: - Time-in-range trend

    /// Whether the in-range percentage over the last 30 days improved on the
    /// previous 30 days. Requires a minimum sample in each window to avoid noise,
    /// and returns `false` when there isn't enough data to judge.
    func timeInRangeImproved(
        userProfile: UserProfile,
        modelContext: ModelContext,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Bool {
        guard let recentStart = calendar.date(byAdding: .day, value: -30, to: date),
              let priorStart = calendar.date(byAdding: .day, value: -60, to: date) else {
            return false
        }
        guard let recent = try inRangePercentage(userProfile: userProfile, modelContext: modelContext, from: recentStart, to: date),
              let prior = try inRangePercentage(userProfile: userProfile, modelContext: modelContext, from: priorStart, to: recentStart) else {
            return false
        }
        return recent > prior
    }

    /// A gentle time-in-range trend: improving, holding steady, or still
    /// building up data. Deliberately never reports a decline as a failure — a
    /// lower recent value is surfaced as `steady`, and the clinical detail lives
    /// in the glucose charts, not here.
    func timeInRangeTrend(
        userProfile: UserProfile,
        modelContext: ModelContext,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> TimeInRangeTrend {
        guard let recentStart = calendar.date(byAdding: .day, value: -30, to: date),
              let priorStart = calendar.date(byAdding: .day, value: -60, to: date) else {
            return .building
        }
        guard let recent = try inRangePercentage(userProfile: userProfile, modelContext: modelContext, from: recentStart, to: date) else {
            return .building
        }
        guard let prior = try inRangePercentage(userProfile: userProfile, modelContext: modelContext, from: priorStart, to: recentStart) else {
            return .steady(recent: recent)
        }
        // A one-point margin keeps day-to-day noise from flip-flopping the label.
        if recent > prior + 1 {
            return .improving(recent: recent, previous: prior)
        }
        return .steady(recent: recent)
    }

    /// The percentage of readings in `[start, end)` within the user's target
    /// range, or `nil` when there are too few readings to be meaningful.
    private func inRangePercentage(
        userProfile: UserProfile,
        modelContext: ModelContext,
        from start: Date,
        to end: Date,
        minimumReadings: Int = 5
    ) throws -> Double? {
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp >= start && reading.timestamp < end
            }
        )
        let readings = try modelContext.fetch(descriptor)
        guard readings.count >= minimumReadings else { return nil }

        let min = userProfile.targetGlucoseMin
        let max = userProfile.targetGlucoseMax
        let inRange = readings.filter { $0.value >= min && $0.value <= max }.count
        return Double(inRange) / Double(readings.count) * 100
    }

    // MARK: - Achievements

    /// Gathers every metric the achievement catalog needs to be evaluated.
    func achievementMetrics(
        userProfile: UserProfile,
        modelContext: ModelContext,
        today: Date = Date()
    ) throws -> Achievements.Metrics {
        let activities = try dailyActivities(userProfile: userProfile, modelContext: modelContext)

        var metrics = Achievements.Metrics()
        metrics.glucoseLogCount = activities.values.reduce(0) { $0 + $1.glucoseCount }
        metrics.mealLogCount = activities.values.reduce(0) { $0 + $1.mealCount }
        metrics.exerciseLogCount = activities.values.reduce(0) { $0 + $1.exerciseCount }
        metrics.totalLogCount = metrics.glucoseLogCount + metrics.mealLogCount + metrics.exerciseLogCount
        metrics.postMealCheckCount = activities.values.reduce(0) { $0 + $1.postMealCheckCount }
        metrics.exerciseGoalDayCount = activities.values.filter { $0.hitExerciseGoal }.count
        metrics.carbGoalDayCount = activities.values.filter { $0.withinCarbGoal }.count
        metrics.currentStreak = try currentStreak(modelContext: modelContext, today: today).currentStreak
        metrics.metWeeklyConsistency = StreakCalculator.meetsWeeklyConsistency(
            activeDays: Set(activities.keys),
            today: today
        )

        let challenges = try weeklyChallengeProgress(userProfile: userProfile, modelContext: modelContext, date: today)
        metrics.allWeeklyChallengesComplete = !challenges.isEmpty && challenges.allSatisfy { $0.isComplete }
        metrics.timeInRangeImproved = try timeInRangeImproved(userProfile: userProfile, modelContext: modelContext, asOf: today)

        return metrics
    }

    /// Evaluates the catalog and persists a record for each newly-earned achievement.
    ///
    /// - Returns: The achievements unlocked by this call, so a caller can
    ///   celebrate them.
    @discardableResult
    func evaluateAchievements(
        userProfile: UserProfile,
        modelContext: ModelContext,
        today: Date = Date()
    ) throws -> [Achievement] {
        let alreadyEarned = try modelContext.fetch(FetchDescriptor<EarnedAchievement>())
        let earnedIDs = Set(alreadyEarned.map { $0.achievementID })

        let metrics = try achievementMetrics(userProfile: userProfile, modelContext: modelContext, today: today)
        let newlyEarned = Achievements.newlyEarned(metrics: metrics, earnedIDs: earnedIDs)

        guard !newlyEarned.isEmpty else { return [] }
        for achievement in newlyEarned {
            modelContext.insert(EarnedAchievement(achievementID: achievement.id, earnedDate: today))
        }
        try modelContext.save()
        return newlyEarned
    }
}

/// A gentle summary of how the user's time in range is trending.
enum TimeInRangeTrend: Equatable {
    /// In-range percentage has improved over the previous 30 days.
    case improving(recent: Double, previous: Double)
    /// In-range percentage is holding steady, or only recent data exists.
    case steady(recent: Double)
    /// Not enough readings yet to show a trend.
    case building
}
