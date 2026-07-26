import SwiftUI
import SwiftData
import Charts

struct GlucoseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GlucoseReading.timestamp, order: .reverse, animation: .default) private var readings: [GlucoseReading]
    @Query private var userProfiles: [UserProfile]
    
    // Limit visible readings to reduce memory usage
    private var visibleReadings: [GlucoseReading] {
        Array(readings.prefix(100))
    }
    @State private var showingAddSheet = false
    @State private var readingPendingDeletion: GlucoseReading?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Glucose Chart
                Section {
                    if visibleReadings.isEmpty {
                        Text("No glucose readings yet. Add your first reading to start tracking.")
                            .foregroundStyle(.secondary)
                            .frame(height: 200)
                    } else {
                        GlucoseChartView(readings: Array(visibleReadings.prefix(15)), targetRange: targetRange)
                            .frame(height: 200)
                    }
                }
                
                // List of readings
                Section("Recent Readings") {
                    if visibleReadings.isEmpty {
                        Text("No glucose readings yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleReadings) { reading in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(reading.timestamp.formatted(date: .numeric, time: .shortened))
                                        .font(.headline)
                                    Text(reading.readingType.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text("\(Int(reading.value)) mg/dL")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(reading.readingStatus.color)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                "\(String(localized: reading.readingType.description)), \(Int(reading.value)) mg/dL, \(String(localized: reading.readingStatus.description))"
                            )
                            .accessibilityAction(named: "Delete") {
                                readingPendingDeletion = reading
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    readingPendingDeletion = reading
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Statistics
                if !readings.isEmpty {
                    Section("Statistics") {
                        StatisticRow(title: "Average", value: averageGlucose())
                        StatisticRow(title: "Lowest", value: lowestGlucose())
                        StatisticRow(title: "Highest", value: highestGlucose())
                    }
                }
            }
            .navigationTitle("Glucose Log")
            .confirmDelete("Delete this glucose reading?", item: $readingPendingDeletion) { reading in
                delete(reading)
            }
            .errorAlert($errorMessage)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Glucose Reading")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGlucoseView()
                    .presentationDetents([.medium])
            }
        }
    }

    private var targetRange: ClosedRange<Double>? {
        guard let profile = userProfiles.first else { return nil }
        return profile.targetGlucoseMin...profile.targetGlucoseMax
    }
    
    private func delete(_ reading: GlucoseReading) {
        modelContext.delete(reading)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func averageGlucose() -> String {
        if readings.isEmpty { return "--" }
        let sum = readings.reduce(0) { $0 + $1.value }
        return String(format: "%.0f mg/dL", sum / Double(readings.count))
    }
    
    private func lowestGlucose() -> String {
        if let lowest = readings.min(by: { $0.value < $1.value }) {
            return String(format: "%.0f mg/dL", lowest.value)
        }
        return "--"
    }
    
    private func highestGlucose() -> String {
        if let highest = readings.max(by: { $0.value < $1.value }) {
            return String(format: "%.0f mg/dL", highest.value)
        }
        return "--"
    }
}

struct StatisticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct AddGlucoseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager
    
    @State private var glucoseValue = ""
    @State private var note = ""
    @State private var readingType: GlucoseReading.ReadingType = .random
    @State private var timestamp = Date()
    @State private var syncToHealth = true
    @State private var showingHealthSyncAlert = false
    @State private var healthSyncError: Error? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Glucose Value", text: $glucoseValue)
                        .keyboardType(.numberPad)
                    
                    Picker("Reading Type", selection: $readingType) {
                        Text("Fasting").tag(GlucoseReading.ReadingType.fasting)
                        Text("Before Meal").tag(GlucoseReading.ReadingType.beforeMeal)
                        Text("After Meal").tag(GlucoseReading.ReadingType.afterMeal)
                        Text("Bedtime").tag(GlucoseReading.ReadingType.bedtime)
                        Text("Random").tag(GlucoseReading.ReadingType.random)
                    }
                    
                    DatePicker("Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
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
                    Button("Save Reading") {
                        saveReading()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(glucoseValue.isEmpty)
                }
            }
            .navigationTitle("Add Glucose Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Health Sync Error", isPresented: $showingHealthSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to sync glucose reading to Apple Health: \(healthSyncError?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func saveReading() {
        guard let value = Double(glucoseValue) else { return }
        
        let newReading = GlucoseReading(
            timestamp: timestamp,
            value: value,
            note: note.isEmpty ? nil : note,
            readingType: readingType
        )
        
        modelContext.insert(newReading)
        
        // Sync to HealthKit if authorized and sync is enabled
        if healthKitManager.isHealthKitAuthorized && syncToHealth {
            Task {
                do {
                    try await healthKitManager.saveGlucoseReading(newReading)
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
}