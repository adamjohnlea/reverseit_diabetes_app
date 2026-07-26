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

    /// Sanity bounds for profile input, in each unit system.
    private enum InputLimits {
        static let maxWeightKg = 500.0
        static let maxWeightLb = 1000.0
        static let maxHeightCm = 300.0
        static let maxHeightIn = 120.0
        static let maxAge = 120
    }

    private var isFormValid: Bool {
        guard let ageValue = Int(age),
              let weightValue = Double(weight),
              let heightValue = Double(height)
        else {
            return false
        }
        return !name.isEmpty && ageValue > 0 && ageValue < InputLimits.maxAge && weightValue > 0 && heightValue > 0
    }

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Welcome Page
                VStack(spacing: 20) {
                    Image(systemName: "heart.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(.pink)
                        .padding()
                        .symbolEffect(.pulse)

                    Text("Welcome to ManageIt!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Take control of your type 2 diabetes, one day at a time")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Text("ManageIt! is a tracking and educational tool. It does not provide medical advice, diagnosis, or treatment and is not a substitute for professional healthcare. Always consult your doctor before changing your diet, exercise, medication, or diabetes management plan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

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
                                .textInputAutocapitalization(.words)
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
                        .foregroundStyle(.red)
                        .padding()

                    Text("Health Data Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("ManageIt! works best when it can access your health data. This helps us track your progress automatically.")
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
        .ignoresSafeArea(edges: .bottom)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func validateAndCreateProfile() -> Bool {
        guard let ageInt = Int(age), ageInt > 0, ageInt < InputLimits.maxAge else {
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
            guard weightDouble < InputLimits.maxWeightKg else {
                alertMessage = "Please enter a valid weight in kg"
                showAlert = true
                return false
            }
        } else {
            guard weightDouble < InputLimits.maxWeightLb else {
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
            guard heightDouble < InputLimits.maxHeightCm else {
                alertMessage = "Please enter a valid height in cm"
                showAlert = true
                return false
            }
        } else {
            guard heightDouble < InputLimits.maxHeightIn else {
                alertMessage = "Please enter a valid height in inches"
                showAlert = true
                return false
            }
        }

        return true
    }

    private func createUserProfile() {
        let newProfile = UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: Int(age) ?? 0,
            diagnosisDate: diagnosisDate,
            useMetricSystem: useMetricSystem,
            onboardingCompleted: false
        )
        if useMetricSystem {
            newProfile.weight = Double(weight) ?? 0.0
            newProfile.height = Double(height) ?? 0.0
        } else {
            newProfile.weightInPounds = Double(weight) ?? 0.0
            newProfile.heightInInches = Double(height) ?? 0.0
        }

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
