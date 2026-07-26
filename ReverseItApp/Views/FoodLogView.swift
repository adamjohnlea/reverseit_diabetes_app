import SwiftUI
import SwiftData
import Charts
import PhotosUI
import UIKit

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse, animation: .default) private var foodEntries: [FoodEntry]
    @Query private var userProfiles: [UserProfile]

    @State private var showingAddSheet = false
    @State private var selectedDate = Date()
    @State private var entryPendingDeletion: FoodEntry?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date selection
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))

                List {
                    // Daily Summary
                    Section {
                        HStack(spacing: 20) {
                            NutrientCard(title: "Carbs", value: totalCarbsForSelectedDate(), goal: userProfiles.first?.targetDailyCarbs ?? 150, unit: "g", color: .blue)

                            NutrientCard(title: "Protein", value: totalProteinForSelectedDate(), goal: nil, unit: "g", color: .green)

                            NutrientCard(title: "Fat", value: totalFatForSelectedDate(), goal: nil, unit: "g", color: .orange)
                        }
                        .padding(.vertical, 8)

                        // Nutrition chart
                        Chart {
                            SectorMark(
                                angle: .value("Value", totalCarbsForSelectedDate()),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(.blue)

                            SectorMark(
                                angle: .value("Value", totalProteinForSelectedDate()),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(.green)

                            SectorMark(
                                angle: .value("Value", totalFatForSelectedDate()),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(.orange)
                        }
                        .frame(height: 200)
                    }

                    // Meals for selected date
                    Section {
                        if filteredEntries.isEmpty {
                            Text("No meals logged for this date")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(filteredEntries) { entry in
                                FoodEntryRow(entry: entry)
                                    .accessibilityAction(named: "Delete") {
                                        entryPendingDeletion = entry
                                    }
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            entryPendingDeletion = entry
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text("Meals")
                    }
                }
            }
            .navigationTitle("Food Log")
            .confirmDelete("Delete this meal?", item: $entryPendingDeletion) { entry in
                delete(entry)
            }
            .errorAlert($errorMessage)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Food")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFoodView()
                    .presentationDetents([.large])
            }
        }
    }

    private func delete(_ entry: FoodEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var filteredEntries: [FoodEntry] {
        let calendar = Calendar.current
        return foodEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }

    private func totalCarbsForSelectedDate() -> Double {
        filteredEntries.reduce(0) { $0 + $1.carbs }
    }

    private func totalProteinForSelectedDate() -> Double {
        filteredEntries.reduce(0) { $0 + $1.protein }
    }

    private func totalFatForSelectedDate() -> Double {
        filteredEntries.reduce(0) { $0 + $1.fat }
    }
}

struct NutrientCard: View {
    let title: String
    let value: Double
    let goal: Int?
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", value))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let goalValue = goal {
                ProgressView(value: min(value, Double(goalValue)), total: Double(goalValue))
                    .progressViewStyle(.linear)
                    .tint(color)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(Color(.tertiarySystemGroupedBackground)))
        .accessibilityElement(children: .combine)
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.headline)

                    Text(entry.mealType.description)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mealTypeColor().opacity(0.2))
                        .foregroundStyle(mealTypeColor())
                        .clipShape(Capsule())
                }

                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(entry.carbs))g carbs")
                    .font(.subheadline)
                    .foregroundStyle(.blue)

                Text("\(Int(entry.calories)) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func mealTypeColor() -> Color {
        switch entry.mealType {
        case .breakfast: return .purple
        case .lunch: return .blue
        case .dinner: return .green
        case .snack: return .orange
        }
    }

}

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager

    @State private var name = ""
    @State private var carbs = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var calories = ""
    @State private var mealType: FoodEntry.MealType = .lunch
    @State private var timestamp = Date()
    @State private var note = ""

    // For automatic calculation
    @State private var calculateCalories = true

    // HealthKit integration
    @State private var syncToHealth = true
    @State private var showingHealthSyncAlert = false
    @State private var healthSyncError: Error?
    @State private var saveError: String?

    // Nutrition-label scanning
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food Name", text: $name)

                    Picker("Meal Type", selection: $mealType) {
                        Text("Breakfast").tag(FoodEntry.MealType.breakfast)
                        Text("Lunch").tag(FoodEntry.MealType.lunch)
                        Text("Dinner").tag(FoodEntry.MealType.dinner)
                        Text("Snack").tag(FoodEntry.MealType.snack)
                    }

                    DatePicker("Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Menu {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                        }
                        Button {
                            showingPhotosPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Label("Scan Nutrition Label", systemImage: "text.viewfinder")
                    }
                    .disabled(isScanning)
                    .accessibilityLabel("Scan nutrition label")

                    if isScanning {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Scanning…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Nutrition")) {
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Calories")
                        Spacer()
                        if calculateCalories {
                            Text(calculatedCalories)
                                .frame(width: 80, alignment: .trailing)
                            Text("kcal")
                                .foregroundStyle(.secondary)
                        } else {
                            TextField("0", text: $calories)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("kcal")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("Calculate calories automatically", isOn: $calculateCalories)
                }

                Section {
                    TextField("Notes", text: $note, axis: .vertical)
                        .lineLimit(3)
                }

                if healthKitManager.isHealthKitAuthorized {
                    Section {
                        Toggle("Sync to Apple Health", isOn: $syncToHealth)
                    }
                }

                Section {
                    Button("Save Food Entry") {
                        saveEntry()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(name.isEmpty || (carbs.isEmpty && protein.isEmpty && fat.isEmpty))
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Health Sync Error", isPresented: $showingHealthSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to sync food entry to Apple Health: \(healthSyncError?.localizedDescription ?? "Unknown error")")
            }
            .errorAlert($saveError)
            .errorAlert($scanError)
            .sheet(isPresented: $showingCamera) {
                CameraPicker { data in
                    Task { await runScan(data) }
                }
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self) {
                            await runScan(data)
                        } else {
                            scanError = String(localized: "Couldn't load the selected image.")
                        }
                    } catch {
                        scanError = error.localizedDescription
                    }
                    photosPickerItem = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var calculatedCalories: String {
        return String(format: "%.0f", computedCalories())
    }

    private func computedCalories() -> Double {
        let carbsVal = Double(carbs) ?? 0
        let proteinVal = Double(protein) ?? 0
        let fatVal = Double(fat) ?? 0
        return carbsVal * FoodEntry.Energy.caloriesPerGramOfCarbs
            + proteinVal * FoodEntry.Energy.caloriesPerGramOfProtein
            + fatVal * FoodEntry.Energy.caloriesPerGramOfFat
    }

    private func saveEntry() {
        let carbsVal = Double(carbs) ?? 0
        let proteinVal = Double(protein) ?? 0
        let fatVal = Double(fat) ?? 0
        let caloriesVal = calculateCalories ? computedCalories() : (Double(calories) ?? 0)

        let newEntry = FoodEntry(
            name: name,
            timestamp: timestamp,
            carbs: carbsVal,
            protein: proteinVal,
            fat: fatVal,
            calories: caloriesVal,
            mealType: mealType,
            note: note.isEmpty ? nil : note
        )

        modelContext.insert(newEntry)
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
            return
        }

        // Sync to HealthKit if authorized and sync is enabled
        if healthKitManager.isHealthKitAuthorized && syncToHealth {
            Task {
                do {
                    try await healthKitManager.saveFoodEntry(newEntry)
                } catch {
                    await MainActor.run {
                        healthSyncError = error
                        showingHealthSyncAlert = true
                    }
                }
            }
        }

        dismiss()
    }

    @MainActor
    private func runScan(_ imageData: Data) async {
        isScanning = true
        defer { isScanning = false }
        do {
            let nutrition = try await NutritionLabelScanner.scan(imageData: imageData)
            apply(nutrition)
        } catch {
            scanError = error.localizedDescription
        }
    }

    /// Writes scanned values into the form fields, leaving unrecognized fields untouched so
    /// the user can still type them. When the label states calories, automatic calculation
    /// is turned off so the label's value is kept; otherwise calories keep computing from macros.
    @MainActor
    private func apply(_ nutrition: ScannedNutrition) {
        if let carbsValue = nutrition.carbs { carbs = Self.decimalString(carbsValue) }
        if let proteinValue = nutrition.protein { protein = Self.decimalString(proteinValue) }
        if let fatValue = nutrition.fat { fat = Self.decimalString(fatValue) }
        if let caloriesValue = nutrition.calories {
            calculateCalories = false
            calories = Self.decimalString(caloriesValue)
        }
        // `name` is intentionally left for the user — nutrition labels carry no food name.
    }

    /// Formats a scanned value for a decimal-pad text field, dropping a redundant ".0".
    private static func decimalString(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
