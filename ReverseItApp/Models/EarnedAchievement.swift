import Foundation
import SwiftData

/// A record that the user has unlocked a given achievement.
///
/// The achievement's presentation (title, hint, symbol) lives in the pure
/// `Achievements` catalog, keyed by `achievementID`. Only the fact that it was
/// earned — and when — is persisted here.
@Model
final class EarnedAchievement {
    /// The catalog identifier of the achievement that was earned.
    var achievementID: String
    /// When the achievement was first unlocked.
    var earnedDate: Date
    /// Whether the user has seen the celebration for this achievement.
    var acknowledged: Bool

    init(achievementID: String, earnedDate: Date = Date(), acknowledged: Bool = false) {
        self.achievementID = achievementID
        self.earnedDate = earnedDate
        self.acknowledged = acknowledged
    }
}
