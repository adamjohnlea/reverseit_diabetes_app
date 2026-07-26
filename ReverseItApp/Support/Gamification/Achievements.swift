import Foundation

/// A single unlockable achievement.
///
/// Unlock conditions are expressed as data (`Criterion`) and evaluated against a
/// precomputed `Achievements.Metrics`, so the catalog is pure and testable and
/// never reaches into SwiftData itself. As with levels, achievements reward
/// *logging behaviour and consistency*, never a glucose value.
struct Achievement: Identifiable {
    let id: String
    let title: LocalizedStringResource
    /// Shown while the achievement is still locked.
    let hint: LocalizedStringResource
    let symbolName: String
    let criterion: Criterion

    /// A data-driven unlock condition, evaluated against `Achievements.Metrics`.
    enum Criterion: Equatable {
        case firstGlucoseLog
        case firstMealLog
        case firstExerciseLog
        case totalLogs(Int)
        case streakDays(Int)
        case postMealChecks(Int)
        case exerciseGoalDays(Int)
        case carbGoalDays(Int)
        case weeklyConsistency
        case allWeeklyChallengesComplete
        case timeInRangeImproved
    }

    /// Whether `metrics` satisfy this achievement's criterion.
    func isSatisfied(by metrics: Achievements.Metrics) -> Bool {
        switch criterion {
        case .firstGlucoseLog: return metrics.glucoseLogCount >= 1
        case .firstMealLog: return metrics.mealLogCount >= 1
        case .firstExerciseLog: return metrics.exerciseLogCount >= 1
        case .totalLogs(let target): return metrics.totalLogCount >= target
        case .streakDays(let target): return metrics.currentStreak >= target
        case .postMealChecks(let target): return metrics.postMealCheckCount >= target
        case .exerciseGoalDays(let target): return metrics.exerciseGoalDayCount >= target
        case .carbGoalDays(let target): return metrics.carbGoalDayCount >= target
        case .weeklyConsistency: return metrics.metWeeklyConsistency
        case .allWeeklyChallengesComplete: return metrics.allWeeklyChallengesComplete
        case .timeInRangeImproved: return metrics.timeInRangeImproved
        }
    }
}

/// The achievement catalog and the evaluation entry point.
enum Achievements {
    /// Precomputed metrics an achievement criterion is evaluated against.
    struct Metrics: Equatable {
        var glucoseLogCount = 0
        var mealLogCount = 0
        var exerciseLogCount = 0
        var totalLogCount = 0
        var currentStreak = 0
        var postMealCheckCount = 0
        var exerciseGoalDayCount = 0
        var carbGoalDayCount = 0
        var metWeeklyConsistency = false
        var allWeeklyChallengesComplete = false
        var timeInRangeImproved = false
    }

    /// Every achievement the app can award. Computed so it holds no shared state.
    static var catalog: [Achievement] {
        [
            Achievement(id: "first-glucose", title: "First Reading", hint: "Log your first glucose reading", symbolName: "waveform.path.ecg", criterion: .firstGlucoseLog),
            Achievement(id: "first-meal", title: "First Meal", hint: "Log your first meal", symbolName: "fork.knife", criterion: .firstMealLog),
            Achievement(id: "first-exercise", title: "First Workout", hint: "Log your first workout", symbolName: "figure.walk", criterion: .firstExerciseLog),
            Achievement(id: "logs-100", title: "Century", hint: "Log 100 entries in total", symbolName: "square.stack.3d.up.fill", criterion: .totalLogs(100)),
            Achievement(id: "logs-500", title: "Dedicated Logger", hint: "Log 500 entries in total", symbolName: "star.circle.fill", criterion: .totalLogs(500)),
            Achievement(id: "streak-7", title: "One Week Strong", hint: "Keep a 7-day logging streak", symbolName: "flame.fill", criterion: .streakDays(7)),
            Achievement(id: "streak-30", title: "Monthly Momentum", hint: "Keep a 30-day logging streak", symbolName: "flame.circle.fill", criterion: .streakDays(30)),
            Achievement(id: "streak-90", title: "Season of Consistency", hint: "Keep a 90-day logging streak", symbolName: "crown.fill", criterion: .streakDays(90)),
            Achievement(id: "post-meal-10", title: "Curious Mind", hint: "Check glucose after 10 meals", symbolName: "clock.arrow.circlepath", criterion: .postMealChecks(10)),
            Achievement(id: "exercise-week", title: "Active Week", hint: "Meet your exercise goal on 7 days", symbolName: "figure.run.circle.fill", criterion: .exerciseGoalDays(7)),
            Achievement(id: "carb-week", title: "Balanced Week", hint: "Stay within your carb goal on 7 days", symbolName: "leaf.circle.fill", criterion: .carbGoalDays(7)),
            Achievement(id: "tir-improved", title: "Trending Up", hint: "Improve your time in range over a month", symbolName: "chart.line.uptrend.xyaxis", criterion: .timeInRangeImproved),
            Achievement(id: "challenges-complete", title: "Challenge Champion", hint: "Complete every weekly challenge", symbolName: "checkmark.seal.fill", criterion: .allWeeklyChallengesComplete)
        ]
    }

    /// The achievements satisfied by `metrics` that are not already in `earnedIDs`.
    ///
    /// - Parameters:
    ///   - metrics: The user's current metrics.
    ///   - earnedIDs: The identifiers of achievements already unlocked.
    static func newlyEarned(metrics: Metrics, earnedIDs: Set<String>) -> [Achievement] {
        catalog.filter { !earnedIDs.contains($0.id) && $0.isSatisfied(by: metrics) }
    }
}
