import Foundation
import SwiftData

/// Per-user gamification state. Like `UserProfile`, this is a de-facto singleton —
/// views read `gamificationProfiles.first`.
///
/// Only genuinely stateful values are stored here. Points, level, streak, and
/// challenge progress are all *derived* from the user's logged entries (see the
/// extension below), so they can never drift out of sync with the underlying
/// data or be double-counted.
@Model
final class GamificationProfile {
    var id: UUID
    /// Freezes remaining this month that can bridge a missed day in the streak.
    var streakFreezesRemaining: Int
    /// The month (start-of-month) the current freeze allotment belongs to.
    var freezeAllotmentMonth: Date
    /// The highest level already celebrated, so a new level-up can be detected.
    var lastSeenLevel: Int
    /// Points banked from data that has since been pruned by retention cleanup,
    /// keeping the lifetime total monotonic. Wired into the retention path in a
    /// later phase; `0` until then.
    var lifetimePointsCheckpoint: Int
    /// Whether streak-at-risk reminder notifications are enabled (opt-in, off by default).
    var streakRemindersEnabled: Bool
    /// Whether the first reward refresh has run. The baseline pass silently
    /// acknowledges whatever progress already exists so the user is never shown
    /// a retroactive celebration for data logged before rewards were active.
    ///
    /// Has an inline default so SwiftData can backfill it when lightweight-
    /// migrating a store that predates this property.
    var hasEstablishedBaseline: Bool = false

    /// Freezes granted at the start of each month.
    static let monthlyFreezeAllotment = 2

    init(
        id: UUID = UUID(),
        streakFreezesRemaining: Int = GamificationProfile.monthlyFreezeAllotment,
        freezeAllotmentMonth: Date = Date(),
        lastSeenLevel: Int = 1,
        lifetimePointsCheckpoint: Int = 0,
        streakRemindersEnabled: Bool = false,
        hasEstablishedBaseline: Bool = false
    ) {
        self.id = id
        self.streakFreezesRemaining = streakFreezesRemaining
        self.freezeAllotmentMonth = freezeAllotmentMonth
        self.lastSeenLevel = lastSeenLevel
        self.lifetimePointsCheckpoint = lifetimePointsCheckpoint
        self.streakRemindersEnabled = streakRemindersEnabled
        self.hasEstablishedBaseline = hasEstablishedBaseline
    }
}

extension GamificationProfile {
    /// The start-of-day for every day on which the user logged any entry.
    func activeDays(modelContext: ModelContext) throws -> Set<Date> {
        let calendar = Calendar.current
        var days: Set<Date> = []

        for reading in try modelContext.fetch(FetchDescriptor<GlucoseReading>()) {
            days.insert(calendar.startOfDay(for: reading.timestamp))
        }
        for meal in try modelContext.fetch(FetchDescriptor<FoodEntry>()) {
            days.insert(calendar.startOfDay(for: meal.timestamp))
        }
        for exercise in try modelContext.fetch(FetchDescriptor<ExerciseEntry>()) {
            days.insert(calendar.startOfDay(for: exercise.startTime))
        }
        return days
    }

    /// Aggregates every logged entry into per-day activity, keyed by start-of-day.
    ///
    /// Goal-completion flags (`hitExerciseGoal`, `withinCarbGoal`) are evaluated
    /// against the goals on `userProfile`.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    func dailyActivities(
        userProfile: UserProfile,
        modelContext: ModelContext
    ) throws -> [Date: PointsRules.DailyActivity] {
        let calendar = Calendar.current
        var byDay: [Date: PointsRules.DailyActivity] = [:]
        var carbsByDay: [Date: Double] = [:]
        var durationByDay: [Date: TimeInterval] = [:]

        for reading in try modelContext.fetch(FetchDescriptor<GlucoseReading>()) {
            let day = calendar.startOfDay(for: reading.timestamp)
            byDay[day, default: PointsRules.DailyActivity()].glucoseCount += 1
            if reading.readingType == .afterMeal {
                byDay[day, default: PointsRules.DailyActivity()].postMealCheckCount += 1
            }
        }
        for meal in try modelContext.fetch(FetchDescriptor<FoodEntry>()) {
            let day = calendar.startOfDay(for: meal.timestamp)
            byDay[day, default: PointsRules.DailyActivity()].mealCount += 1
            carbsByDay[day, default: 0] += meal.carbs
        }
        for exercise in try modelContext.fetch(FetchDescriptor<ExerciseEntry>()) {
            let day = calendar.startOfDay(for: exercise.startTime)
            byDay[day, default: PointsRules.DailyActivity()].exerciseCount += 1
            durationByDay[day, default: 0] += exercise.duration
        }

        let exerciseGoalSeconds = Double(userProfile.targetDailyExerciseMinutes * 60)
        let carbGoal = Double(userProfile.targetDailyCarbs)
        for day in Array(byDay.keys) {
            guard var activity = byDay[day] else { continue }
            activity.withinCarbGoal = activity.mealCount > 0 && (carbsByDay[day] ?? 0) <= carbGoal
            activity.hitExerciseGoal = (durationByDay[day] ?? 0) >= exerciseGoalSeconds
            byDay[day] = activity
        }
        return byDay
    }

    /// Points derived purely from the currently retained entries, excluding the
    /// banked checkpoint. Used by retention cleanup to keep totals monotonic.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    func derivedPoints(userProfile: UserProfile, modelContext: ModelContext) throws -> Int {
        let activities = try dailyActivities(userProfile: userProfile, modelContext: modelContext)
        return activities.values.reduce(0) { $0 + PointsRules.points(for: $1).total }
    }

    /// The user's lifetime point total: banked checkpoint plus points derived
    /// from all currently retained entries.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    func totalPoints(userProfile: UserProfile, modelContext: ModelContext) throws -> Int {
        lifetimePointsCheckpoint + (try derivedPoints(userProfile: userProfile, modelContext: modelContext))
    }

    /// Resets the monthly freeze allotment when a new calendar month has begun.
    ///
    /// - Parameters:
    ///   - now: The reference "current time".
    ///   - calendar: The calendar used to compare months.
    /// - Returns: Whether a refill occurred.
    @discardableResult
    func refillFreezesIfNeeded(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let allotmentMonth = calendar.dateInterval(of: .month, for: freezeAllotmentMonth)?.start,
              currentMonth > allotmentMonth else {
            return false
        }
        streakFreezesRemaining = GamificationProfile.monthlyFreezeAllotment
        freezeAllotmentMonth = now
        return true
    }

    /// The user's current level and progress toward the next.
    ///
    /// - Parameters:
    ///   - userProfile: The profile holding the daily carb and exercise goals.
    ///   - modelContext: The context to read entries from.
    func levelProgress(userProfile: UserProfile, modelContext: ModelContext) throws -> Levels.LevelProgress {
        Levels.progress(forTotalPoints: try totalPoints(userProfile: userProfile, modelContext: modelContext))
    }

    /// The current forgiving streak, using the freezes remaining this month.
    ///
    /// - Parameters:
    ///   - modelContext: The context to read entries from.
    ///   - today: The reference "current day".
    func currentStreak(
        modelContext: ModelContext,
        today: Date = Date()
    ) throws -> StreakCalculator.StreakResult {
        let days = try activeDays(modelContext: modelContext)
        return StreakCalculator.streak(
            activeDays: days,
            today: today,
            freezesAvailable: streakFreezesRemaining
        )
    }
}
