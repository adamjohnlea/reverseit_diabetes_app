import SwiftUI
import SwiftData
import HealthKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var selectedTab = 0
    @Query private var userProfiles: [UserProfile]
    
    var body: some View {
        Group {
            if userProfiles.isEmpty || !userProfiles.first!.onboardingCompleted {
                OnboardingView()
            } else {
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem {
                            Label("Dashboard", systemImage: "house.fill")
                        }
                        .tag(0)
                    
                    FoodLogView()
                        .tabItem {
                            Label("Food Log", systemImage: "fork.knife")
                        }
                        .tag(1)
                    
                    ExerciseLogView()
                        .tabItem {
                            Label("Exercise", systemImage: "figure.walk")
                        }
                        .tag(2)
                    
                    GlucoseLogView()
                        .tabItem {
                            Label("Glucose", systemImage: "waveform.path.ecg")
                        }
                        .tag(3)
                    
                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(4)
                }
                .animation(.easeInOut, value: selectedTab)
            }
        }
    }
}
