import SwiftUI
import SwiftData
import HealthKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @Query private var userProfiles: [UserProfile]
    @Query private var gamificationProfiles: [GamificationProfile]

    var body: some View {
        Group {
            if let profile = userProfiles.first, profile.onboardingCompleted {
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
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active || phase == .background else { return }
            Task { await refreshStreakReminder() }
        }
    }

    /// Reschedules the opt-in evening streak reminder to reflect whether the
    /// user has already logged today.
    private func refreshStreakReminder() async {
        guard let gamification = gamificationProfiles.first, gamification.streakRemindersEnabled else {
            await StreakReminderScheduler.refresh(enabled: false, hasLoggedToday: false)
            return
        }
        let hasLoggedToday: Bool
        do {
            hasLoggedToday = try gamification.currentStreak(modelContext: modelContext).isActiveToday
        } catch {
            // Non-critical: at worst an extra reminder is scheduled.
            hasLoggedToday = false
        }
        await StreakReminderScheduler.refresh(enabled: true, hasLoggedToday: hasLoggedToday)
    }
}
