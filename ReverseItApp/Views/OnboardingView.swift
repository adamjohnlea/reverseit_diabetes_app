import SwiftUI
import SwiftData
import HealthKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var currentPage = 0
    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var diagnosisDate = Date()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isHealthKitAuthorizing = false
    @State private var useMetricSystem = true
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField {
        case name, age, weight, height
    }

    private var isFormValid: Bool {
        guard let ageValue = Int(age),
              let weightValue = Double(weight),
              let heightValue = Double(height)
        else {
            return false
        }
        return !name.isEmpty && ageValue > 0 && ageValue < 120 && weightValue > 0 && heightValue > 0
    }

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Welcome Page
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.pink)
                        .padding()
                        .symbolEffect(.pulse)
                    
                    Text("Welcome to ReverseIt!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Your journey to reverse type 2 diabetes starts here")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    Button("Get Started") {
                        withAnimation {
                            currentPage = 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 40)
                }
                .padding()
                .tag(0)

                // Profile Page
                VStack(spacing: 20) {
                    Text("Tell us about yourself")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Form {
                        Section(header: Text("Unit Preference")) {
                            Picker("Units", selection: $useMetricSystem) {
                                Text("Metric (kg, cm)").tag(true)
                                Text("Imperial (lb, in)").tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Section(header: Text("Personal Information")) {
                            TextField("Name", text: $name)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .focused($focusedField, equals: .name)

                            TextField("Age", text: $age)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .age)

                            TextField(useMetricSystem ? "Weight (kg)" : "Weight (lb)", text: $weight)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .weight)

                            TextField(useMetricSystem ? "Height (cm)" : "Height (in)", text: $height)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .height)
                        }
                        
                        Section(header: Text("Medical Information")) {
                            DatePicker("Diagnosis Date", selection: $diagnosisDate, in: ...Date(), displayedComponents: [.date])
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .keyboard) {
                            HStack {
                                Spacer()
                                Button("Done") {
                                    focusedField = nil
                                }
                            }
                        }
                    }
                    
                    Button("Continue") {
                        if validateAndCreateProfile() {
                            withAnimation {
                                createUserProfile()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!isFormValid)
                }
                .padding()
                .tag(1)

                // HealthKit Authorization Page
                VStack(spacing: 20) {
                    Image(systemName: "heart.text.square.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.red)
                        .padding()
                    
                    Text("Health Data Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("ReverseIt works best when it can access your health data. This helps us track your progress automatically.")
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if isHealthKitAuthorizing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Button(healthKitManager.isHealthKitAuthorized ? "Continue" : "Allow Health Access") {
                            if healthKitManager.isHealthKitAuthorized {
                                Task {
                                    do {
                                        try await healthKitManager.importDataFromHealthKit(modelContext: modelContext)
                                    } catch {
                                        alertMessage = "Failed to import health data. You can try again later in settings."
                                        showAlert = true
                                    }
                                    completeOnboarding()
                                }
                            } else {
                                isHealthKitAuthorizing = true
                                Task {
                                    do {
                                        let success = try await healthKitManager.requestAuthorization()
                                        isHealthKitAuthorizing = false
                                        if !success {
                                            alertMessage = "Unable to access Health data. You can enable this later in settings."
                                            showAlert = true
                                        }
                                        completeOnboarding()
                                    } catch {
                                        isHealthKitAuthorizing = false
                                        alertMessage = "Unable to access Health data. You can enable this later in settings."
                                        showAlert = true
                                        completeOnboarding()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding()
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea([.bottom])
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func validateAndCreateProfile() -> Bool {
        guard let ageInt = Int(age), ageInt > 0, ageInt < 120 else {
            alertMessage = "Please enter a valid age between 1 and 120"
            showAlert = true
            return false
        }
        
        guard let weightDouble = Double(weight), weightDouble > 0 else {
            alertMessage = "Please enter a valid weight"
            showAlert = true
            return false
        }
        
        if useMetricSystem {
            guard weightDouble < 500 else {
                alertMessage = "Please enter a valid weight in kg"
                showAlert = true
                return false
            }
        } else {
            guard weightDouble < 1000 else {
                alertMessage = "Please enter a valid weight in lb"
                showAlert = true
                return false
            }
        }
        
        guard let heightDouble = Double(height), heightDouble > 0 else {
            alertMessage = "Please enter a valid height"
            showAlert = true
            return false
        }
        
        if useMetricSystem {
            guard heightDouble < 300 else {
                alertMessage = "Please enter a valid height in cm"
                showAlert = true
                return false
            }
        } else {
            guard heightDouble < 120 else {
                alertMessage = "Please enter a valid height in inches"
                showAlert = true
                return false
            }
        }
        
        return true
    }

    private func createUserProfile() {
        // If using imperial units, convert to metric for storage
        let weightInKg: Double
        let heightInCm: Double
        
        if useMetricSystem {
            weightInKg = Double(weight) ?? 0.0
            heightInCm = Double(height) ?? 0.0
        } else {
            // Convert lbs to kg
            weightInKg = (Double(weight) ?? 0.0) * 0.453592
            // Convert inches to cm
            heightInCm = (Double(height) ?? 0.0) * 2.54
        }
        
        let newProfile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: Int(age) ?? 0,
            weight: weightInKg,    // Stored in kg
            height: heightInCm,    // Stored in cm
            diagnosisDate: diagnosisDate,
            useMetricSystem: useMetricSystem,
            onboardingCompleted: false
        )
        
        modelContext.insert(newProfile)
        
        do {
            try modelContext.save()
            withAnimation {
                currentPage = 2 // Move to HealthKit page
            }
        } catch {
            alertMessage = "Failed to save profile. Please try again."
            showAlert = true
        }
    }
    
    private func completeOnboarding() {
        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(descriptor)
            if let profile = profiles.first {
                profile.onboardingCompleted = true
                try modelContext.save()
            }
        } catch {
            alertMessage = "Failed to finish setup. Please try again."
            showAlert = true
        }
    }
}
