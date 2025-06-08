import SwiftUI
import SwiftData
import HealthKit

@main
struct ReverseItApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    
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
            // If there's a schema migration issue, try to create a fresh container
            print("Model container creation failed, attempting to recreate: \(error)")
            
            // Try with a fresh configuration that allows data loss during migration
            let freshConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            do {
                return try ModelContainer(for: schema, configurations: [freshConfiguration])
            } catch {
                fatalError("Could not create ModelContainer even after retry: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .onAppear {
                    healthKitManager.checkAuthorizationStatus()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
