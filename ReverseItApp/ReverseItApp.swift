import SwiftUI
import SwiftData
import HealthKit

@main
struct ReverseItApp: App {
    @State private var healthKitManager = HealthKitManager.shared

    /// UI tests pass `-uitest-reset` for an empty in-memory store, or
    /// `-uitest-seeded` for an in-memory store with a completed profile and
    /// sample data. Production launches always use the persistent store.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            GlucoseReading.self,
            FoodEntry.self,
            ExerciseEntry.self,
            GamificationProfile.self,
            EarnedAchievement.self,
            GoalPeriod.self
        ])
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("-uitest-reset") || arguments.contains("-uitest-seeded")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITest,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if arguments.contains("-uitest-seeded") {
                let context = ModelContext(container)
                context.insert(
                    UserProfile(name: "Test User", age: 45, weight: 80, height: 175, onboardingCompleted: true)
                )
                context.insert(GlucoseReading(value: 110, readingType: .fasting))
                try context.save()
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .task {
                    healthKitManager.checkAuthorizationStatus()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
