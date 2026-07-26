import Foundation

/// The point values and daily caps that make up the gamification economy.
///
/// Points reward *controllable logging behaviours* — recording readings, meals,
/// and exercise, and meeting the daily carb and exercise goals. A point is never
/// awarded for a glucose value itself, only for the act of logging and for
/// staying within self-set goals. Daily caps stop a user from inflating their
/// score by logging the same kind of entry many times in a single day.
enum PointsRules {
    // MARK: Point values

    /// Points for logging one glucose reading.
    static let glucoseReading = 5
    /// Points for logging one meal.
    static let meal = 5
    /// Points for logging one exercise session.
    static let exerciseSession = 10
    /// Bonus for checking glucose after a meal (an educational behaviour).
    static let postMealCheck = 10
    /// Bonus for meeting the daily exercise goal.
    static let exerciseGoalMet = 15
    /// Bonus for staying within the daily carb goal.
    static let carbGoalMet = 15
    /// Bonus for logging all three entry types in one day.
    static let fullLoggingDay = 10

    // MARK: Daily caps (the maximum count of each action that earns points per day)

    static let glucoseReadingDailyCap = 6
    static let mealDailyCap = 4
    static let exerciseSessionDailyCap = 3
    static let postMealCheckDailyCap = 3

    /// A single day's logging activity, reduced to the counts and goal-completion
    /// flags the economy needs.
    struct DailyActivity: Equatable {
        var glucoseCount: Int
        var mealCount: Int
        var exerciseCount: Int
        var postMealCheckCount: Int
        var hitExerciseGoal: Bool
        var withinCarbGoal: Bool

        init(
            glucoseCount: Int = 0,
            mealCount: Int = 0,
            exerciseCount: Int = 0,
            postMealCheckCount: Int = 0,
            hitExerciseGoal: Bool = false,
            withinCarbGoal: Bool = false
        ) {
            self.glucoseCount = glucoseCount
            self.mealCount = mealCount
            self.exerciseCount = exerciseCount
            self.postMealCheckCount = postMealCheckCount
            self.hitExerciseGoal = hitExerciseGoal
            self.withinCarbGoal = withinCarbGoal
        }

        /// Whether the user logged at least one of every entry type today.
        var isFullLoggingDay: Bool {
            glucoseCount > 0 && mealCount > 0 && exerciseCount > 0
        }
    }

    /// A breakdown of the points earned on a single day, so callers can show
    /// where each contribution came from.
    struct DailyPointsBreakdown: Equatable {
        var glucose: Int
        var meals: Int
        var exercise: Int
        var postMealChecks: Int
        var exerciseGoal: Int
        var carbGoal: Int
        var fullDayBonus: Int

        var total: Int {
            glucose + meals + exercise + postMealChecks + exerciseGoal + carbGoal + fullDayBonus
        }
    }

    /// Computes the points earned for one day's `activity`, applying all daily caps.
    ///
    /// - Parameter activity: The day's aggregated counts and goal-completion flags.
    /// - Returns: A breakdown whose `total` is the day's score.
    static func points(for activity: DailyActivity) -> DailyPointsBreakdown {
        let cappedGlucose = min(activity.glucoseCount, glucoseReadingDailyCap)
        let cappedMeals = min(activity.mealCount, mealDailyCap)
        let cappedExercise = min(activity.exerciseCount, exerciseSessionDailyCap)
        let cappedPostMeal = min(activity.postMealCheckCount, postMealCheckDailyCap)

        return DailyPointsBreakdown(
            glucose: cappedGlucose * glucoseReading,
            meals: cappedMeals * meal,
            exercise: cappedExercise * exerciseSession,
            postMealChecks: cappedPostMeal * postMealCheck,
            exerciseGoal: activity.hitExerciseGoal ? exerciseGoalMet : 0,
            carbGoal: activity.withinCarbGoal ? carbGoalMet : 0,
            fullDayBonus: activity.isFullLoggingDay ? fullLoggingDay : 0
        )
    }
}
