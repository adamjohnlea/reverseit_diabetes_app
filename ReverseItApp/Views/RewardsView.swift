import SwiftUI
import SwiftData

/// The full rewards detail screen, reached by tapping the Dashboard summary card.
///
/// Shows the level header and track, a gentle time-in-range trend, this week's
/// challenges, and the full badge gallery with earned and locked states.
struct RewardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query private var gamificationProfiles: [GamificationProfile]
    @Query private var earnedAchievements: [EarnedAchievement]

    @State private var summary: RewardSummary?
    @State private var challenges: [WeeklyChallengeProgress] = []
    @State private var trend: TimeInRangeTrend = .building
    @State private var errorMessage: String?

    /// Badge grid columns widen with Dynamic Type so the scaled badge circles fit.
    @ScaledMetric(relativeTo: .title2) private var badgeColumnMinimum: CGFloat = 90

    private var earnedIDs: Set<String> {
        Set(earnedAchievements.map(\.achievementID))
    }

    var body: some View {
        List {
            if let summary {
                levelSection(summary)
                trendSection
                levelTrackSection(summary)
                challengesSection
                badgeGallerySection
            } else {
                Text("Start logging to earn rewards.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($errorMessage)
        .onAppear(perform: refresh)
    }

    // MARK: Level

    private func levelSection(_ summary: RewardSummary) -> some View {
        Section {
            HStack(spacing: 16) {
                XPRingView(fraction: summary.level.fractionToNextLevel, level: summary.level.level, baseSize: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.level.stageName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("\(summary.level.totalPoints) points")
                        .foregroundStyle(.secondary)
                    Text("\(summary.level.pointsToNextLevel) pts to next level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            HStack {
                Label("\(summary.streak.currentStreak) day streak", systemImage: "flame.fill")
                    .foregroundStyle(summary.streak.currentStreak > 0 ? .primary : .secondary)
                Spacer()
                if summary.freezesRemaining > 0 {
                    Label("\(summary.freezesRemaining)", systemImage: "snowflake")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(summary.freezesRemaining) freezes remaining")
                }
            }
        }
    }

    // MARK: Time-in-range trend

    private var trendSection: some View {
        Section("Time in Range") {
            switch trend {
            case let .improving(recent, previous):
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Improving")
                            .fontWeight(.medium)
                        Text("\(Int(recent))% in range, up from \(Int(previous))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.green)
                }
                .accessibilityElement(children: .combine)
            case let .steady(recent):
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Holding steady")
                            .fontWeight(.medium)
                        Text("\(Int(recent))% in range over the last 30 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "equal.circle")
                        .foregroundStyle(.blue)
                }
                .accessibilityElement(children: .combine)
            case .building:
                Label("Keep logging to see your trend", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Level track

    private func levelTrackSection(_ summary: RewardSummary) -> some View {
        Section("Your Journey") {
            ForEach(1...Levels.stageNames.count, id: \.self) { level in
                levelTrackRow(level: level, current: summary.level.level)
            }
        }
    }

    private func levelTrackRow(level: Int, current: Int) -> some View {
        let state: LevelState = level < current ? .reached : (level == current ? .current : .locked)
        return HStack(spacing: 12) {
            Image(systemName: state.symbolName)
                .foregroundStyle(state.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(Levels.stageName(forLevel: level))
                    .fontWeight(state == .current ? .semibold : .regular)
                    .foregroundStyle(state == .locked ? .secondary : .primary)
                Text("Level \(level) · \(Levels.threshold(forLevel: level)) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Levels.stageName(forLevel: level)), level \(level), \(state.accessibilityDescription)")
    }

    private enum LevelState: Equatable {
        case reached, current, locked

        var symbolName: String {
            switch self {
            case .reached: return "checkmark.circle.fill"
            case .current: return "smallcircle.filled.circle.fill"
            case .locked: return "circle"
            }
        }

        var tint: Color {
            switch self {
            case .reached: return .green
            case .current: return .accentColor
            case .locked: return .secondary
            }
        }

        var accessibilityDescription: String {
            switch self {
            case .reached: return "reached"
            case .current: return "current level"
            case .locked: return "locked"
            }
        }
    }

    // MARK: Challenges

    private var challengesSection: some View {
        Section("This Week's Challenges") {
            if challenges.isEmpty {
                Text("No challenges available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(challenges) { challenge in
                    challengeRow(challenge)
                }
            }
        }
    }

    private func challengeRow(_ challenge: WeeklyChallengeProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(challenge.challenge.title)
                } icon: {
                    Image(systemName: challenge.isComplete ? "checkmark.circle.fill" : challenge.challenge.symbolName)
                        .foregroundStyle(challenge.isComplete ? .green : Color.accentColor)
                }
                Spacer()
                Text("\(challenge.current)/\(challenge.target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: challenge.fraction)
                .tint(challenge.isComplete ? .green : .accentColor)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(challenge.challenge.title))
        .accessibilityValue(Text("\(challenge.current) of \(challenge.target)"))
    }

    // MARK: Badge gallery

    private var badgeGallerySection: some View {
        Section("Badges") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: badgeColumnMinimum), spacing: 12)], spacing: 16) {
                ForEach(Achievements.catalog) { badge in
                    BadgeCell(badge: badge, isEarned: earnedIDs.contains(badge.id))
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: Data

    private func refresh() {
        guard let userProfile = userProfiles.first else { return }
        let gamification = gamificationProfiles.first ?? {
            let created = GamificationProfile()
            modelContext.insert(created)
            return created
        }()
        do {
            summary = try gamification.rewardSummary(userProfile: userProfile, modelContext: modelContext)
            challenges = try gamification.weeklyChallengeProgress(userProfile: userProfile, modelContext: modelContext)
            trend = try gamification.timeInRangeTrend(userProfile: userProfile, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A single badge in the gallery, shown earned (in colour) or locked (dimmed
/// with its unlock hint).
private struct BadgeCell: View {
    let badge: Achievement
    let isEarned: Bool

    /// The badge circle grows with Dynamic Type so the icon keeps pace with its label.
    @ScaledMetric(relativeTo: .title2) private var circleSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? Color.yellow.opacity(0.2) : Color(.systemGray6))
                    .frame(width: circleSize, height: circleSize)
                Image(systemName: badge.symbolName)
                    .font(.title2)
                    .foregroundStyle(isEarned ? .yellow : .secondary)
            }
            Text(isEarned ? badge.title : badge.hint)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEarned ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(isEarned ? 1 : 0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEarned ? Text("\(badge.title), earned") : Text("Locked: \(badge.hint)"))
    }
}
