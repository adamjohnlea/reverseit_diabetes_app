import Foundation

/// Computes a *forgiving* logging streak: consecutive days on which the user
/// logged anything, where a limited number of missed days can be bridged by
/// "freezes" so a single slip doesn't erase weeks of progress.
///
/// The current day is treated as grace — if nothing has been logged yet today
/// the streak is not counted as broken, it simply reflects the run ending
/// yesterday so the UI can nudge the user to keep it alive.
enum StreakCalculator {
    /// The trailing-week active-day count that earns the weekly-consistency reward.
    static let weeklyConsistencyTarget = 5

    /// The result of evaluating the current streak.
    struct StreakResult: Equatable {
        /// Active days in the current streak. Bridged (frozen) days are not counted.
        let currentStreak: Int
        /// How many freezes were consumed to keep the streak alive.
        let freezesUsed: Int
        /// Whether the user has already logged something today.
        let isActiveToday: Bool
    }

    /// Evaluates the current forgiving streak.
    ///
    /// - Parameters:
    ///   - activeDays: Days (any time component) on which at least one entry was logged.
    ///   - today: The reference "current day".
    ///   - freezesAvailable: The maximum number of missed days that may be bridged.
    ///   - calendar: The calendar used to normalise days.
    /// - Returns: The streak length, freezes consumed, and whether today is active.
    static func streak(
        activeDays: some Sequence<Date>,
        today: Date,
        freezesAvailable: Int,
        calendar: Calendar = .current
    ) -> StreakResult {
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        let startOfToday = calendar.startOfDay(for: today)
        let isActiveToday = days.contains(startOfToday)

        guard let earliest = days.min() else {
            return StreakResult(currentStreak: 0, freezesUsed: 0, isActiveToday: false)
        }

        // If today isn't logged yet it's grace, not a break: begin from yesterday.
        var cursor = isActiveToday
            ? startOfToday
            : calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        var streak = 0
        var freezesUsed = 0

        while cursor >= earliest {
            if days.contains(cursor) {
                streak += 1
            } else if freezesUsed < freezesAvailable {
                freezesUsed += 1   // bridge the gap without counting the day
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return StreakResult(currentStreak: streak, freezesUsed: freezesUsed, isActiveToday: isActiveToday)
    }

    /// The number of distinct active days within the trailing 7-day window ending today.
    ///
    /// - Parameters:
    ///   - activeDays: Days on which at least one entry was logged.
    ///   - today: The reference "current day".
    ///   - calendar: The calendar used to normalise days.
    static func activeDaysInTrailingWeek(
        activeDays: some Sequence<Date>,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: today)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return 0 }
        let days = Set(activeDays.map { calendar.startOfDay(for: $0) })
        return days.filter { $0 >= weekAgo && $0 <= startOfToday }.count
    }

    /// Whether the trailing week meets the weekly-consistency target.
    static func meetsWeeklyConsistency(
        activeDays: some Sequence<Date>,
        today: Date,
        calendar: Calendar = .current
    ) -> Bool {
        activeDaysInTrailingWeek(activeDays: activeDays, today: today, calendar: calendar) >= weeklyConsistencyTarget
    }
}
