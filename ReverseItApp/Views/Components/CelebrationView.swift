import SwiftUI

/// A tasteful, one-tap-to-dismiss celebration for a level-up and/or new badges.
///
/// Kept intentionally gentle and non-manipulative: it acknowledges progress and
/// gets out of the way.
struct CelebrationView: View {
    let celebration: Celebration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            if let level = celebration.newLevel {
                VStack(spacing: 6) {
                    Text("Level Up!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("You reached Level \(level.level)")
                        .font(.headline)
                    Text(level.stageName)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
            }

            if !celebration.newBadges.isEmpty {
                VStack(spacing: 12) {
                    Text(celebration.newBadges.count == 1 ? "New Badge" : "New Badges")
                        .font(.headline)
                    ForEach(celebration.newBadges) { badge in
                        Label {
                            Text(badge.title)
                        } icon: {
                            Image(systemName: badge.symbolName)
                                .foregroundStyle(.yellow)
                        }
                        .font(.body)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Button("Nice!") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
