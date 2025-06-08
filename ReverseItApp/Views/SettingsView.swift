import SwiftUI
import SwiftData
import HealthKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // User profile settings
    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var diagnosisDate = Date()
    
    // Goal settings
    @State private var targetGlucoseMin = ""
    @State private var targetGlucoseMax = ""
    @State private var targetDailyCarbs = ""
    @State private var targetDailyExerciseMinutes = ""
    
    // App settings
    @State private var useImperial = false
    @State private var allowNotifications = true
    @State private var syncWithHealthApp = false
    @State private var importFromHealthApp = false
    
    // Alerts
    @State private var showingHealthKitAlert = false
    @State private var healthKitAlertTitle = ""
    @State private var healthKitAlertMessage = ""
    @State private var showingImportAlert = false
    @State private var importSuccessful = false
    
    // Add reset confirmation state
    @State private var showingResetConfirm = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile
                Section(header: Text("Profile")) {
                    if let profile = userProfiles.first {
                        profileFields(profile: profile)
                    } else {
                        Text("No profile found")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Goal settings
                Section(header: Text("Health Goals")) {
                    if let profile = userProfiles.first {
                        goalFields(profile: profile)
                    }
                }
                
                // App settings
                Section(header: Text("App Settings")) {
                    Toggle("Use Imperial Units", isOn: $useImperial)
                        .onChange(of: useImperial) { _, newValue in
                            if let profile = userProfiles.first {
                                profile.useMetricSystem = !newValue
                                loadProfile() // Reload profile to update displayed units
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("Error saving unit preference: \(error)")
                                }
                            }
                        }
                    Toggle("Enable Notifications", isOn: $allowNotifications)
                }
                
                // Health integration
                Section(header: Text("Apple Health Integration")) {
                    if HKHealthStore.isHealthDataAvailable() {
                        Toggle("Sync with Apple Health", isOn: $syncWithHealthApp)
                            .onChange(of: syncWithHealthApp) { oldValue, newValue in
                                if newValue {
                                    requestHealthKitAccess()
                                }
                            }
                            
                        Button("Import Data from Apple Health") {
                            requestHealthKitImport()
                        }
                        .disabled(!healthKitManager.isHealthKitAuthorized)
                        
                        Text("Syncing with Apple Health allows you to share glucose readings, meals, and exercise data with the Health app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Apple Health is not available on this device.")
                            .foregroundColor(.secondary)
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About ReverseIt!")
                    }
                    
                    NavigationLink {
                        HelpView()
                    } label: {
                        Text("Help & Support")
                    }
                    
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text("Privacy Policy")
                    }
                }
                
                // Save button
                Section {
                    Button("Save Changes") {
                        saveProfile()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!hasChanges())
                }
                
                // Add Danger Zone section at the bottom
                Section(header: Text("Danger Zone").foregroundColor(.red)) {
                    Button("Reset App Data", role: .destructive) {
                        showingResetConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadProfile()
                syncWithHealthApp = healthKitManager.isHealthKitAuthorized
            }
            .alert(healthKitAlertTitle, isPresented: $showingHealthKitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthKitAlertMessage)
            }
            .alert(importSuccessful ? "Import Successful" : "Import Failed", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importSuccessful ? "Data from Apple Health has been imported successfully." : "Failed to import data from Apple Health. Please try again.")
            }
            .alert("Reset App", isPresented: $showingResetConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAppData()
                }
            } message: {
                Text("This will delete all your data and restart the app. This action cannot be undone.")
            }
        }
    }
    
    private func requestHealthKitAccess() {
        healthKitManager.requestAuthorization { success, error in
            syncWithHealthApp = success
            
            if !success {
                healthKitAlertTitle = "Health Access Denied"
                healthKitAlertMessage = "Unable to access Apple Health. Please enable access in the Settings app."
                showingHealthKitAlert = true
            }
        }
    }
    
    private func requestHealthKitImport() {
        healthKitManager.importDataFromHealthKit(modelContext: modelContext) { success in
            importSuccessful = success
            showingImportAlert = true
        }
    }
    
    @ViewBuilder
    private func profileFields(profile: UserProfile) -> some View {
        TextField("Name", text: $name)
            .textContentType(.name)
        
        HStack {
            Text("Age")
            Spacer()
            TextField("Age", text: $age)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text("years")
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Weight")
            Spacer()
            TextField("Weight", text: $weight)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(useImperial ? "lbs" : "kg")
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Height")
            Spacer()
            TextField("Height", text: $height)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(useImperial ? "in" : "cm")
                .foregroundColor(.secondary)
        }
        
        DatePicker("Diagnosis Date", selection: $diagnosisDate, displayedComponents: [.date])
    }
    
    @ViewBuilder
    private func goalFields(profile: UserProfile) -> some View {
        HStack {
            Text("Target Glucose Range")
            Spacer()
            TextField("", text: $targetGlucoseMin)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)
            Text("-")
            TextField("", text: $targetGlucoseMax)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)
            Text("mg/dL")
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Daily Carb Target")
            Spacer()
            TextField("", text: $targetDailyCarbs)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("g")
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Daily Exercise Target")
            Spacer()
            TextField("", text: $targetDailyExerciseMinutes)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("min")
                .foregroundColor(.secondary)
        }
    }
    
    private func loadProfile() {
        guard let profile = userProfiles.first else { return }
        
        name = profile.name
        age = "\(profile.age)"
        
        // Values are stored in metric (kg, cm)
        if useImperial {
            // Convert kg to lbs
            let weightInLbs = profile.weight * 2.20462
            weight = String(format: "%.1f", weightInLbs)
            
            // Convert cm to inches
            let heightInInches = profile.height / 2.54
            height = String(format: "%.1f", heightInInches)
        } else {
            // No conversion needed
            weight = String(format: "%.1f", profile.weight)
            height = String(format: "%.1f", profile.height)
        }
        
        diagnosisDate = profile.diagnosisDate
        targetGlucoseMin = "\(Int(profile.targetGlucoseMin))"
        targetGlucoseMax = "\(Int(profile.targetGlucoseMax))"
        targetDailyCarbs = "\(profile.targetDailyCarbs)"
        targetDailyExerciseMinutes = "\(profile.targetDailyExerciseMinutes)"
        
        useImperial = !profile.useMetricSystem
    }

    private func saveProfile() {
        guard let profile = userProfiles.first else { return }
        
        profile.name = name
        profile.age = Int(age) ?? 0
        
        let weightValue = Double(weight) ?? 0.0
        let heightValue = Double(height) ?? 0.0
        
        // Convert to metric for storage if using imperial
        if useImperial {
            // Convert lbs to kg (1 lb = 0.453592 kg)
            profile.weight = weightValue * 0.453592
            // Convert inches to cm (1 inch = 2.54 cm)
            profile.height = heightValue * 2.54
        } else {
            // Already in metric, store as is
            profile.weight = weightValue
            profile.height = heightValue
        }
        
        profile.diagnosisDate = diagnosisDate
        profile.targetGlucoseMin = Double(targetGlucoseMin) ?? 70.0
        profile.targetGlucoseMax = Double(targetGlucoseMax) ?? 140.0
        profile.targetDailyCarbs = Int(targetDailyCarbs) ?? 150
        profile.targetDailyExerciseMinutes = Int(targetDailyExerciseMinutes) ?? 30
        profile.lastUpdated = Date()
        profile.useMetricSystem = !useImperial
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving profile: \(error)")
        }
    }
    
    private func hasChanges() -> Bool {
        guard let profile = userProfiles.first else { return false }
        
        // Get current values in metric for comparison
        let currentWeight: Double
        let currentHeight: Double
        
        if useImperial {
            currentWeight = (Double(weight) ?? 0.0) * 0.453592  // Convert lbs to kg
            currentHeight = (Double(height) ?? 0.0) * 2.54      // Convert inches to cm
        } else {
            currentWeight = Double(weight) ?? 0.0
            currentHeight = Double(height) ?? 0.0
        }
        
        return name != profile.name ||
               Int(age) != profile.age ||
               abs(currentWeight - profile.weight) > 0.01 ||    // Use small epsilon for float comparison
               abs(currentHeight - profile.height) > 0.01 ||
               diagnosisDate != profile.diagnosisDate ||
               Double(targetGlucoseMin) != profile.targetGlucoseMin ||
               Double(targetGlucoseMax) != profile.targetGlucoseMax ||
               Int(targetDailyCarbs) != profile.targetDailyCarbs ||
               Int(targetDailyExerciseMinutes) != profile.targetDailyExerciseMinutes
    }
    
    private func resetAppData() {
        do {
            try modelContext.delete(model: UserProfile.self)
            try modelContext.delete(model: GlucoseReading.self)
            try modelContext.delete(model: FoodEntry.self)
            try modelContext.delete(model: ExerciseEntry.self)
            try modelContext.save()
        } catch {
            print("Error resetting app data: \(error)")
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About ReverseIt!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("ReverseIt! is designed to help people reverse type 2 diabetes through lifestyle changes, diet tracking, and regular monitoring of health metrics.")
                
                Text("Recent research has shown that type 2 diabetes can be reversed in many cases through proper diet, exercise, and weight management. This app provides the tools you need to track your progress and make informed decisions about your health.")
                
                Text("Key Features:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    FeatureRow(icon: "fork.knife", text: "Food and carb tracking")
                    FeatureRow(icon: "figure.walk", text: "Exercise monitoring")
                    FeatureRow(icon: "waveform.path.ecg", text: "Blood glucose tracking")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress visualization")
                    FeatureRow(icon: "icloud", text: "Cross-device syncing")
                }
                
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(text)
        }
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section(header: Text("Frequently Asked Questions")) {
                DisclosureGroup("How do I track my glucose levels?") {
                    Text("Tap on the Glucose tab and use the + button to add a new reading. You can specify when the reading was taken and add notes.")
                        .padding(.vertical)
                }
                
                DisclosureGroup("How do I log my meals?") {
                    Text("Go to the Food Log tab and tap + to add a new meal. Enter the name, nutrition details, and meal type.")
                        .padding(.vertical)
                }
                
                DisclosureGroup("Can I change my daily targets?") {
                    Text("Yes! Go to Settings and update your health goals to match your doctor's recommendations.")
                        .padding(.vertical)
                }
                
                DisclosureGroup("Does this sync with Apple Health?") {
                    Text("Yes, when you enable Health sync in Settings, your exercise and glucose data will sync with Apple Health.")
                        .padding(.vertical)
                }
            }
            
            Section(header: Text("Contact Support")) {
                Button(action: {}) {
                    Label("Email Support", systemImage: "envelope")
                }
                
                Button(action: {}) {
                    Label("Visit Website", systemImage: "globe")
                }
            }
        }
        .navigationTitle("Help & Support")
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your privacy is important to us. This policy outlines what data ReverseIt collects and how it's used.")
                
                Group {
                    Text("Data Collection")
                        .font(.headline)
                    
                    Text("ReverseIt collects the health data you enter, including glucose readings, food entries, and exercise information. This data is stored securely and never sold to third parties.")
                }
                
                Group {
                    Text("Data Storage")
                        .font(.headline)
                    
                    Text("Your data is primarily stored on your device. When you enable iCloud syncing, your data is encrypted and stored in your personal iCloud account to enable access across your devices.")
                }
                
                Group {
                    Text("Apple Health Integration")
                        .font(.headline)
                    
                    Text("With your permission, ReverseIt can read from and write to Apple Health. This integration helps provide a more complete picture of your health.")
                }
                
                Text("Last updated: May 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
