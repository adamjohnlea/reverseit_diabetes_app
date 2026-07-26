import Foundation
import SwiftData
@testable import ReverseItApp

enum TestSupport {
    /// Builds an isolated in-memory SwiftData context mirroring the app's schema.
    @MainActor
    static func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            UserProfile.self,
            GlucoseReading.self,
            FoodEntry.self,
            ExerciseEntry.self,
            GamificationProfile.self,
            EarnedAchievement.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    /// A fixed reference day (June 15, 2025) so date-bucketing tests are deterministic.
    static func date(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15 + dayOffset
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
