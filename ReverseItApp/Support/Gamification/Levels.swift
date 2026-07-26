import Foundation

/// Maps a running point total to an engagement level.
///
/// Level names describe the user's *logging habit and consistency* — never a
/// health or medical outcome. Despite the app's name, no level implies diabetes
/// has been reversed. Progression is unbounded: past the named tiers, each
/// further level costs a fixed increment.
enum Levels {
    /// Cumulative points required to *reach* each level, indexed from level 1 (0 points).
    static let thresholds: [Int] = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]

    /// Points added per level once past the final entry in `thresholds`.
    static let incrementBeyondThresholds = 800

    /// An encouraging, habit-focused name for each level in `thresholds`.
    static let stageNames: [String] = [
        "Getting Started",
        "Finding Your Feet",
        "Building Habits",
        "Finding Rhythm",
        "Steady Progress",
        "Staying Consistent",
        "Fully Committed",
        "In Control",
        "Thriving",
        "Champion"
    ]

    /// A user's current level and their progress toward the next one.
    struct LevelProgress: Equatable {
        /// The 1-based level number.
        let level: Int
        /// The habit-focused name for this level.
        let stageName: String
        /// The user's lifetime point total.
        let totalPoints: Int
        /// Cumulative points at the start of this level.
        let currentLevelFloor: Int
        /// Cumulative points needed to reach the next level.
        let nextLevelThreshold: Int

        /// Points earned since reaching the current level.
        var pointsIntoLevel: Int { totalPoints - currentLevelFloor }
        /// Points that separate this level from the next.
        var pointsForThisLevel: Int { nextLevelThreshold - currentLevelFloor }
        /// Points still needed to reach the next level.
        var pointsToNextLevel: Int { max(0, nextLevelThreshold - totalPoints) }
        /// Progress toward the next level, in the range 0...1.
        var fractionToNextLevel: Double {
            guard pointsForThisLevel > 0 else { return 0 }
            return min(1, max(0, Double(pointsIntoLevel) / Double(pointsForThisLevel)))
        }
    }

    /// The cumulative points needed to reach `level`.
    ///
    /// - Parameter level: The 1-based level number.
    /// - Returns: Cumulative points required to reach `level`.
    static func threshold(forLevel level: Int) -> Int {
        precondition(level >= 1, "Levels are 1-based")
        if level <= thresholds.count {
            return thresholds[level - 1]
        }
        let extraLevels = level - thresholds.count
        return thresholds[thresholds.count - 1] + extraLevels * incrementBeyondThresholds
    }

    /// The habit-focused name for `level`, reusing the top name beyond the named tiers.
    ///
    /// - Parameter level: The 1-based level number.
    static func stageName(forLevel level: Int) -> String {
        precondition(level >= 1, "Levels are 1-based")
        let index = min(level, stageNames.count) - 1
        return stageNames[index]
    }

    /// The level a user with `totalPoints` has reached, and their progress toward the next.
    ///
    /// - Parameter totalPoints: The user's lifetime point total.
    static func progress(forTotalPoints totalPoints: Int) -> LevelProgress {
        let points = max(0, totalPoints)
        var level = 1
        while threshold(forLevel: level + 1) <= points {
            level += 1
        }
        return LevelProgress(
            level: level,
            stageName: stageName(forLevel: level),
            totalPoints: points,
            currentLevelFloor: threshold(forLevel: level),
            nextLevelThreshold: threshold(forLevel: level + 1)
        )
    }
}
