import Foundation
import SwiftData

/// A dated snapshot of the user's daily carb and exercise goals.
///
/// Goal-based point bonuses are judged against the targets that were in effect
/// on the day an entry was logged — not the user's *current* targets — so
/// changing a goal never rewrites the points already earned for past days.
///
/// A period is recorded only when a target actually changes (see
/// `recordChange`), and the first change also lays down a `.distantPast`
/// baseline capturing the previous targets. The common "goals never change"
/// case therefore stores nothing at all, and callers fall back to the profile's
/// current targets.
@Model
final class GoalPeriod {
    /// The start-of-day from which these targets apply, until the next period.
    var effectiveFrom: Date
    var targetDailyCarbs: Int
    var targetDailyExerciseMinutes: Int

    init(effectiveFrom: Date, targetDailyCarbs: Int, targetDailyExerciseMinutes: Int) {
        self.effectiveFrom = effectiveFrom
        self.targetDailyCarbs = targetDailyCarbs
        self.targetDailyExerciseMinutes = targetDailyExerciseMinutes
    }
}

extension GoalPeriod {
    /// The carb and exercise targets in effect on `day`.
    ///
    /// Chooses the latest period beginning on or before `day`. When no period
    /// covers the day, falls back to the profile's current targets — the correct
    /// answer when the user has never changed a goal (so no periods exist).
    ///
    /// - Parameters:
    ///   - day: The start-of-day to resolve targets for.
    ///   - periods: All recorded periods, sorted ascending by `effectiveFrom`.
    ///   - fallback: The profile whose current targets apply when no period does.
    /// - Returns: The carb (grams) and exercise (minutes) targets for the day.
    static func effectiveTargets(
        for day: Date,
        periods: [GoalPeriod],
        fallback: UserProfile
    ) -> (carbs: Int, exerciseMinutes: Int) {
        var chosen: GoalPeriod?
        for period in periods where period.effectiveFrom <= day {
            chosen = period
        }
        if let resolved = chosen ?? periods.first {
            return (resolved.targetDailyCarbs, resolved.targetDailyExerciseMinutes)
        }
        return (fallback.targetDailyCarbs, fallback.targetDailyExerciseMinutes)
    }

    /// Records a goal change so future point calculations use the right targets
    /// per day.
    ///
    /// The first change also lays down a `.distantPast` baseline capturing the
    /// *previous* targets, so every already-logged day keeps the goal it was
    /// earned under. Repeated changes on the same day collapse into one period.
    /// The caller is responsible for saving the context.
    ///
    /// - Parameters:
    ///   - previousCarbs: The carb target before this change.
    ///   - previousExerciseMinutes: The exercise target before this change.
    ///   - newCarbs: The new carb target.
    ///   - newExerciseMinutes: The new exercise target.
    ///   - date: When the new targets take effect (defaults to now).
    ///   - modelContext: The context to record into.
    static func recordChange(
        previousCarbs: Int,
        previousExerciseMinutes: Int,
        newCarbs: Int,
        newExerciseMinutes: Int,
        on date: Date = Date(),
        modelContext: ModelContext
    ) throws {
        let periods = try modelContext.fetch(
            FetchDescriptor<GoalPeriod>(sortBy: [SortDescriptor(\.effectiveFrom)])
        )

        // First change ever: preserve the prior targets as the historical
        // baseline so past days aren't re-judged against the new goal.
        if periods.isEmpty {
            modelContext.insert(
                GoalPeriod(
                    effectiveFrom: .distantPast,
                    targetDailyCarbs: previousCarbs,
                    targetDailyExerciseMinutes: previousExerciseMinutes
                )
            )
        }

        let effectiveDay = Calendar.current.startOfDay(for: date)
        if let existing = periods.first(where: { $0.effectiveFrom == effectiveDay }) {
            existing.targetDailyCarbs = newCarbs
            existing.targetDailyExerciseMinutes = newExerciseMinutes
        } else {
            modelContext.insert(
                GoalPeriod(
                    effectiveFrom: effectiveDay,
                    targetDailyCarbs: newCarbs,
                    targetDailyExerciseMinutes: newExerciseMinutes
                )
            )
        }
    }
}
