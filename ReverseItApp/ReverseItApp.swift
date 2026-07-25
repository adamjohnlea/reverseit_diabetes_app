import SwiftUI
import SwiftData
import HealthKit

@main
struct ReverseItApp: App {
    @State private var healthKitManager = HealthKitManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            GlucoseReading.self,
            FoodEntry.self,
            ExerciseEntry.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
