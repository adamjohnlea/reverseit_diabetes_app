import SwiftUI

/// A compact, Activity-ring-style progress ring showing the current level.
///
/// The ring scales with the user's Dynamic Type size so the level text inside
/// never outgrows it.
struct XPRingView: View {
    let fraction: Double
    let level: Int
    /// The ring diameter at the default text size; it grows with Dynamic Type.
    var baseSize: CGFloat = 56

    @ScaledMetric(relativeTo: .headline) private var scaleUnit: CGFloat = 1

    private var diameter: CGFloat { baseSize * scaleUnit }
    private var lineWidth: CGFloat { (baseSize / 9) * scaleUnit }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("LV")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .minimumScaleFactor(0.5)
            .padding(lineWidth)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
    }
}

/// The Dashboard's compact gamification summary: level, streak, this week's
/// top challenge, and the latest badge. Tapping it opens the full Rewards screen.
struct RewardSummaryCard: View {
    let summary: RewardSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            statusRow
            if let challenge = summary.topChallenge {
                challengeRow(challenge)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var header: some View {
        HStack(spacing: 16) {
            XPRingView(fraction: summary.level.fractionToNextLevel, level: summary.level.level, baseSize: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.level.stageName)
                    .font(.headline)
                Text("\(summary.level.pointsToNextLevel) pts to next level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusRow: some View {
        // At accessibility text sizes the streak and badge each get too wide to
        // sit side by side, so stack them vertically instead of overlapping.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            streakLabel
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            if let badge = summary.latestBadge {
                badgeLabel(badge)
            }
        }
    }

    private var streakLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(summary.streak.currentStreak > 0 ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(summary.streak.currentStreak) day streak")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if summary.freezesRemaining > 0 {
                    Label("\(summary.freezesRemaining) freezes", systemImage: "snowflake")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streakAccessibilityLabel)
    }

    private var streakAccessibilityLabel: String {
        let base = "\(summary.streak.currentStreak) day streak"
        guard summary.freezesRemaining > 0 else { return base }
        return base + ", \(summary.freezesRemaining) freezes remaining"
    }

    private func badgeLabel(_ badge: Achievement) -> some View {
        HStack(spacing: 6) {
            Image(systemName: badge.symbolName)
                .foregroundStyle(.yellow)
            Text(badge.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Latest badge: \(badge.title)"))
    }

    private func challengeRow(_ challenge: WeeklyChallengeProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(challenge.challenge.title)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: challenge.challenge.symbolName)
                        .foregroundStyle(Color.accentColor)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("This week: \(challenge.challenge.title)"))
        .accessibilityValue(Text("\(challenge.current) of \(challenge.target)"))
    }
}
