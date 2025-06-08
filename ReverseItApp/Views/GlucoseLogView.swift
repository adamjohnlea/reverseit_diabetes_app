import SwiftUI
import SwiftData
import Charts

struct GlucoseLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GlucoseReading.timestamp, order: .reverse, animation: .default) private var readings: [GlucoseReading]
    
    // Limit visible readings to reduce memory usage
    private var visibleReadings: [GlucoseReading] {
        Array(readings.prefix(100))
    }
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Glucose Chart
                Section {
                    if visibleReadings.isEmpty {
                        Text("No glucose readings yet. Add your first reading to start tracking.")
                            .foregroundColor(.secondary)
                            .frame(height: 200)
                    } else {
                        Chart(visibleReadings.prefix(15), id: \.id) { reading in
                            LineMark(
                                x: .value("Date", reading.timestamp),
                                y: .value("Glucose", reading.value)
                            )
                            .foregroundStyle(Color.pink.gradient)
                            
                            PointMark(
                                x: .value("Date", reading.timestamp),
                                y: .value("Glucose", reading.value)
                            )
                            .foregroundStyle(Color.pink)
                        }
                        .frame(height: 200)
                        .chartYScale(domain: 50...250)
                    }
                }
                
                // List of readings
                Section("Recent Readings") {
                    if visibleReadings.isEmpty {
                        Text("No glucose readings yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(visibleReadings) { reading in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(formattedDate(reading.timestamp))
                                        .font(.headline)
                                    Text(reading.readingType.rawValue.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(Int(reading.value)) mg/dL")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(glucoseColor(reading.value))
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(reading)
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
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddGlucoseView()
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func glucoseColor(_ value: Double) -> Color {
        if value < 70 {
            return .red
        } else if value > 180 {
            return .orange
        } else {
            return .green
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
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct AddGlucoseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var glucoseValue = ""
    @State private var note = ""
    @State private var readingType: GlucoseReading.ReadingType = .random
    @State private var timestamp = Date()
    
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
    
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var syncToHealth = true
    @State private var showingHealthSyncAlert = false
    @State private var healthSyncError: Error? = nil
    
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
            healthKitManager.saveGlucoseReading(newReading) { success, error in
                if let error = error {
                    healthSyncError = error
                    showingHealthSyncAlert = true
                }
            }
        }
        
        dismiss()
    }
}