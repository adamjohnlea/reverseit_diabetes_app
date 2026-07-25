import SwiftUI

/// Single source of truth for status → color mappings.
///
/// Kept separate from the models so model files stay UI-framework-free.
/// The glucose convention treats a low reading as the most urgent state.
extension GlucoseReading.ReadingStatus {
    var color: Color {
        switch self {
        case .low: .red
        case .normal: .green
        case .high: .orange
        }
    }
}

extension UserProfile.GlucoseProgress.ProgressStatus {
    var color: Color {
        switch self {
        case .excellent: .green
        case .good: .blue
        case .fair: .yellow
        case .needsImprovement: .red
        }
    }
}
