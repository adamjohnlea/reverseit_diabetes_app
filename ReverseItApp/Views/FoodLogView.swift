import SwiftUI
import SwiftData
import Charts

struct FoodLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.timestamp, order: .reverse, animation: .default) private var foodEntries: [FoodEntry]
    @Query private var userProfiles: [UserProfile]
    
    @State private var showingAddSheet = false
    @State private var selectedDate = Date()
    
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
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(filteredEntries) { entry in
                                FoodEntryRow(entry: entry)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            modelContext.delete(entry)
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
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFoodView()
                    .presentationDetents([.large])
            }
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
                .foregroundColor(.secondary)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", value))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    
                    Text(mealTypeLabel())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mealTypeColor().opacity(0.2))
                        .foregroundColor(mealTypeColor())
                        .clipShape(Capsule())
                }
                
                Text(formattedTime(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(entry.carbs))g carbs")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("\(Int(entry.calories)) kcal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func mealTypeLabel() -> String {
        switch entry.mealType {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }
    
    private func mealTypeColor() -> Color {
        switch entry.mealType {
        case .breakfast: return .purple
        case .lunch: return .blue
        case .dinner: return .green
        case .snack: return .orange
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AddFoodView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
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
    @State private var healthSyncError: Error? = nil
    
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
                
                Section(header: Text("Nutrition")) {
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $carbs)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Calories")
                        Spacer()
                        if calculateCalories {
                            Text(calculatedCalories)
                                .frame(width: 80, alignment: .trailing)
                            Text("kcal")
                                .foregroundColor(.secondary)
                        } else {
                            TextField("0", text: $calories)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("kcal")
                                .foregroundColor(.secondary)
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
        let carbsVal = Double(carbs) ?? 0
        let proteinVal = Double(protein) ?? 0
        let fatVal = Double(fat) ?? 0
        
        // 4 calories per gram of carbs and protein, 9 calories per gram of fat
        let total = (carbsVal * 4) + (proteinVal * 4) + (fatVal * 9)
        return String(format: "%.0f", total)
    }
    
    private func saveEntry() {
        let carbsVal = Double(carbs) ?? 0
        let proteinVal = Double(protein) ?? 0
        let fatVal = Double(fat) ?? 0
        let caloriesVal: Double
        
        if calculateCalories {
            caloriesVal = (carbsVal * 4) + (proteinVal * 4) + (fatVal * 9)
        } else {
            caloriesVal = Double(calories) ?? 0
        }
        
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
        
        // Sync to HealthKit if authorized and sync is enabled
        if healthKitManager.isHealthKitAuthorized && syncToHealth {
            healthKitManager.saveFoodEntry(newEntry) { success, error in
                if let error = error {
                    healthSyncError = error
                    showingHealthSyncAlert = true
                }
            }
        }
        
        dismiss()
    }
}