import Foundation

/// One weekly challenge: a target count of some controllable behaviour.
struct WeeklyChallenge: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let symbolName: String
    let target: Int
    let kind: Kind

    /// The behaviour a challenge counts. Each maps to a field of `WeekActivity`.
    enum Kind {
        case mealDays
        case glucoseDays
        case exerciseGoalDays
        case carbGoalDays
        case postMealChecks
        case activeDays
    }
}

/// A challenge paired with the user's current progress toward it.
struct WeeklyChallengeProgress: Identifiable {
    let challenge: WeeklyChallenge
    let current: Int

    var id: String { challenge.id }
    var target: Int { challenge.target }
    var isComplete: Bool { current >= challenge.target }
    var fraction: Double {
        guard challenge.target > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(challenge.target)))
    }
}

/// The weekly-challenge pool, deterministic selection, and progress scoring.
enum WeeklyChallenges {
    /// One week's activity, reduced to the metrics challenges are scored against.
    struct WeekActivity: Equatable {
        var mealDays = 0
        var glucoseDays = 0
        var exerciseGoalDays = 0
        var carbGoalDays = 0
        var postMealCheckCount = 0
        var activeDays = 0
    }

    /// How many challenges are active in any given week.
    static let countPerWeek = 3

    /// Every challenge template. Computed so it holds no shared state.
    static var pool: [WeeklyChallenge] {
        [
            WeeklyChallenge(id: "meal-days-5", title: "Log a meal on 5 days", symbolName: "fork.knife", target: 5, kind: .mealDays),
            WeeklyChallenge(id: "glucose-days-5", title: "Log a reading on 5 days", symbolName: "waveform.path.ecg", target: 5, kind: .glucoseDays),
            WeeklyChallenge(id: "exercise-goal-4", title: "Meet your exercise goal on 4 days", symbolName: "figure.walk", target: 4, kind: .exerciseGoalDays),
            WeeklyChallenge(id: "carb-goal-5", title: "Stay within your carb goal on 5 days", symbolName: "leaf.fill", target: 5, kind: .carbGoalDays),
            WeeklyChallenge(id: "post-meal-3", title: "Check glucose after 3 meals", symbolName: "clock.arrow.circlepath", target: 3, kind: .postMealChecks),
            WeeklyChallenge(id: "active-6", title: "Log something on 6 days", symbolName: "checkmark.seal.fill", target: 6, kind: .activeDays)
        ]
    }

    /// A stable, monotonic index for the calendar week containing `date`.
    static func weekIndex(forWeekContaining date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let secondsPerWeek = 7.0 * 24 * 60 * 60
        return Int((start.timeIntervalSinceReferenceDate / secondsPerWeek).rounded(.down))
    }

    /// The challenges active for the week containing `date`.
    ///
    /// Selection is deterministic — the same week always yields the same
    /// challenges — and rotates through the pool from one week to the next.
    static func challenges(forWeekContaining date: Date, calendar: Calendar = .current) -> [WeeklyChallenge] {
        let source = pool
        guard !source.isEmpty else { return [] }
        let count = min(countPerWeek, source.count)
        let base = weekIndex(forWeekContaining: date, calendar: calendar)
        return (0..<count).map { offset in
            let index = ((base + offset) % source.count + source.count) % source.count
            return source[index]
        }
    }

    /// The user's current progress toward `challenge`, read from `week`.
    static func currentProgress(for challenge: WeeklyChallenge, in week: WeekActivity) -> Int {
        switch challenge.kind {
        case .mealDays: return week.mealDays
        case .glucoseDays: return week.glucoseDays
        case .exerciseGoalDays: return week.exerciseGoalDays
        case .carbGoalDays: return week.carbGoalDays
        case .postMealChecks: return week.postMealCheckCount
        case .activeDays: return week.activeDays
        }
    }

    /// Pairs `challenge` with the user's progress in `week`.
    static func progress(for challenge: WeeklyChallenge, in week: WeekActivity) -> WeeklyChallengeProgress {
        WeeklyChallengeProgress(challenge: challenge, current: currentProgress(for: challenge, in: week))
    }

    /// Summarises per-day activity for one week into a `WeekActivity`.
    ///
    /// - Parameter activities: Per-day activity keyed by start-of-day, already
    ///   filtered to the week of interest.
    static func summarize(_ activities: [Date: PointsRules.DailyActivity]) -> WeekActivity {
        WeekActivity(
            mealDays: activities.values.filter { $0.mealCount > 0 }.count,
            glucoseDays: activities.values.filter { $0.glucoseCount > 0 }.count,
            exerciseGoalDays: activities.values.filter { $0.hitExerciseGoal }.count,
            carbGoalDays: activities.values.filter { $0.withinCarbGoal }.count,
            postMealCheckCount: activities.values.reduce(0) { $0 + $1.postMealCheckCount },
            activeDays: activities.count
        )
    }
}
