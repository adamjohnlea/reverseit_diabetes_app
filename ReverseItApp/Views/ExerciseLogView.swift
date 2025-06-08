import SwiftUI
import SwiftData
import Charts

struct ExerciseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseEntry.startTime, order: .reverse, animation: .default) private var exercises: [ExerciseEntry]
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
                    // Summary and progress
                    Section {
                        VStack(spacing: 15) {
                            // Progress circle
                            ZStack {
                                Circle()
                                    .stroke(
                                        Color(.systemGray5),
                                        lineWidth: 15
                                    )
                                
                                Circle()
                                    .trim(from: 0, to: progressFraction)
                                    .stroke(
                                        Color.green,
                                        style: StrokeStyle(
                                            lineWidth: 15,
                                            lineCap: .round
                                        )
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeOut, value: progressFraction)
                                
                                VStack(spacing: 5) {
                                    Text("\(totalMinutes) min")
                                        .font(.system(size: 36, weight: .bold))
                                    
                                    Text("of \(targetMinutes) min")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: 200)
                            
                            // Calories burned
                            if totalCaloriesBurned > 0 {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    
                                    Text("\(Int(totalCaloriesBurned)) calories burned")
                                        .font(.headline)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Weekly progress chart
                    Section(header: Text("Weekly Progress")) {
                        Chart(lastSevenDays, id: \.day) { dayData in
                            BarMark(
                                x: .value("Day", dayData.day, unit: .day),
                                y: .value("Minutes", dayData.minutes)
                            )
                            .foregroundStyle(Color.green.gradient)
                            .cornerRadius(4)
                        }
                        .frame(height: 180)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday())
                            }
                        }
                    }
                    
                    // Exercises for selected date
                    Section {
                        if filteredExercises.isEmpty {
                            Text("No exercises logged for this date")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(filteredExercises) { exercise in
                                ExerciseEntryRow(exercise: exercise)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            modelContext.delete(exercise)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text("Exercises")
                    }
                }
            }
            .navigationTitle("Exercise Log")
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExerciseView()
                    .presentationDetents([.large])
            }
        }
    }
    
    private var filteredExercises: [ExerciseEntry] {
        let calendar = Calendar.current
        return exercises.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
    }
    
    private var targetMinutes: Int {
        return userProfiles.first?.targetDailyExerciseMinutes ?? 30
    }
    
    private var totalMinutes: Int {
        let minutes = filteredExercises.reduce(0) { $0 + Int($1.durationInMinutes) }
        return minutes
    }
    
    private var progressFraction: Double {
        if targetMinutes == 0 { return 0 }
        return min(Double(totalMinutes) / Double(targetMinutes), 1.0)
    }
    
    private var totalCaloriesBurned: Double {
        filteredExercises.reduce(0) { $0 + ($1.caloriesBurned ?? 0) }
    }
    
    struct DayExerciseData {
        let day: Date
        let minutes: Int
    }
    
    private var lastSevenDays: [DayExerciseData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).map { dayOffset -> DayExerciseData in
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dayExercises = exercises.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
            let minutes = dayExercises.reduce(0) { $0 + Int($1.durationInMinutes) }
            return DayExerciseData(day: day, minutes: minutes)
        }.reversed()
    }
}

struct ExerciseEntryRow: View {
    let exercise: ExerciseEntry
    
    var body: some View {
        HStack {
            exerciseIcon
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(exerciseColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.type)
                    .font(.headline)
                
                Text(formattedTime(exercise.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(exercise.durationInMinutes)) min")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let calories = exercise.caloriesBurned {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var exerciseIcon: Image {
        let type = exercise.type.lowercased()
        if type.contains("walk") {
            return Image(systemName: "figure.walk")
        } else if type.contains("run") || type.contains("jog") {
            return Image(systemName: "figure.run")
        } else if type.contains("bike") || type.contains("cycle") {
            return Image(systemName: "figure.outdoor.cycle")
        } else if type.contains("swim") {
            return Image(systemName: "figure.pool.swim")
        } else if type.contains("yoga") {
            return Image(systemName: "figure.yoga")
        } else if type.contains("gym") || type.contains("weight") {
            return Image(systemName: "dumbbell.fill")
        } else {
            return Image(systemName: "heart.fill")
        }
    }
    
    private var exerciseColor: Color {
        switch exercise.intensity {
        case .light: return .blue
        case .moderate: return .green
        case .vigorous: return .orange
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    // List of common exercise types
    private let exerciseTypes = [
        "Walking", "Running", "Cycling", "Swimming", "Yoga", 
        "Weight Training", "HIIT", "Pilates", "Dance", "Hiking", 
        "Tennis", "Basketball", "Soccer", "Rowing", "Elliptical"
    ]
    
    @State private var type = "Walking"
    @State private var customType = ""
    @State private var useCustomType = false
    @State private var startTime = Date()
    @State private var durationHours = 0
    @State private var durationMinutes = 30
    @State private var caloriesBurned = ""
    @State private var intensity: ExerciseEntry.ExerciseIntensity = .moderate
    @State private var note = ""
    
    // HealthKit integration
    @State private var syncToHealth = true
    @State private var showingHealthSyncAlert = false
    @State private var healthSyncError: Error? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Details")) {
                    if useCustomType {
                        TextField("Exercise Type", text: $customType)
                    } else {
                        Picker("Exercise Type", selection: $type) {
                            ForEach(exerciseTypes, id: \.self) { exerciseType in
                                Text(exerciseType).tag(exerciseType)
                            }
                        }
                    }
                    
                    Toggle("Custom exercise type", isOn: $useCustomType)
                    
                    DatePicker("Start Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $durationHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour) hr").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70)
                        
                        Picker("", selection: $durationMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70)
                    }
                    
                    Picker("Intensity", selection: $intensity) {
                        Text("Light").tag(ExerciseEntry.ExerciseIntensity.light)
                        Text("Moderate").tag(ExerciseEntry.ExerciseIntensity.moderate)
                        Text("Vigorous").tag(ExerciseEntry.ExerciseIntensity.vigorous)
                    }
                    
                    HStack {
                        Text("Calories Burned")
                        Spacer()
                        TextField("Optional", text: $caloriesBurned)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
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
                    Button("Save Exercise") {
                        saveExercise()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(durationHours == 0 && durationMinutes == 0)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Health Sync Error", isPresented: $showingHealthSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to sync exercise to Apple Health: \(healthSyncError?.localizedDescription ?? "Unknown error")")
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
    
    private func saveExercise() {
        let exerciseType = useCustomType ? customType : type
        let duration = TimeInterval((durationHours * 3600) + (durationMinutes * 60))
        let calories = caloriesBurned.isEmpty ? nil : Double(caloriesBurned)
        
        let newExercise = ExerciseEntry(
            type: exerciseType,
            startTime: startTime,
            duration: duration,
            caloriesBurned: calories,
            intensity: intensity,
            note: note.isEmpty ? nil : note
        )
        
        modelContext.insert(newExercise)
        
        // Sync to HealthKit if authorized and sync is enabled
        if healthKitManager.isHealthKitAuthorized && syncToHealth {
            healthKitManager.saveExerciseEntry(newExercise) { success, error in
                if let error = error {
                    healthSyncError = error
                    showingHealthSyncAlert = true
                }
            }
        }
        
        dismiss()
    }
}