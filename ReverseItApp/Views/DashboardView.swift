import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var glucoseReadings: [GlucoseReading]
    
    // Use explicit predicates to limit data loaded
    private var todayPredicate: Predicate<FoodEntry> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return #Predicate<FoodEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
        }
    }
    
    private var todayExercisePredicate: Predicate<ExerciseEntry> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return #Predicate<ExerciseEntry> { entry in
            entry.startTime >= startOfDay && entry.startTime < endOfDay
        }
    }
    
    @Query private var todayFoodEntries: [FoodEntry]
    @Query private var todayExerciseEntries: [ExerciseEntry]
    
    init() {
        // Initialize queries with predicates
        _todayFoodEntries = Query(filter: todayPredicate)
        _todayExerciseEntries = Query(filter: todayExercisePredicate)
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hello, \(userProfiles.first?.name ?? "Friend")")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(dateFormatted())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // Quick Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        DashboardCard(
                            title: "Glucose",
                            value: latestGlucoseReading(),
                            unit: "mg/dL",
                            systemImage: "waveform.path.ecg",
                            color: glucoseStatusColor(),
                            isAnimating: isAnimating
                        )
                        
                        DashboardCard(
                            title: "Daily Carbs",
                            value: dailyCarbsTotal(),
                            unit: "g",
                            systemImage: "fork.knife",
                            color: .blue,
                            isAnimating: isAnimating
                        )
                        
                        DashboardCard(
                            title: "Exercise",
                            value: dailyExerciseMinutes(),
                            unit: "min",
                            systemImage: "figure.walk",
                            color: .green,
                            isAnimating: isAnimating
                        )
                        
                        DashboardCard(
                            title: "Progress",
                            value: daysOfJourney(),
                            unit: "days",
                            systemImage: "calendar",
                            color: .purple,
                            isAnimating: isAnimating
                        )
                    }
                    .padding(.horizontal)
                    
                    // Weekly Glucose Chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weekly Glucose Trend")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if glucoseReadings.isEmpty {
                            Text("No data yet. Add glucose readings to see your trend.")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            // Limit to 15 most recent readings for the chart
                            GlucoseChartView(readings: Array(glucoseReadings.prefix(15)))
                                .frame(height: 200)
                                .padding(.horizontal)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground)))
                    .padding(.horizontal)
                    
                    // Quick Actions
                    HStack(spacing: 15) {
                        NavigationLink(destination: AddGlucoseView()) {
                            QuickActionButton(
                                title: "Add Glucose", 
                                systemImage: "plus.circle",
                                color: .pink
                            )
                        }
                        
                        NavigationLink(destination: AddFoodView()) {
                            QuickActionButton(
                                title: "Log Food", 
                                systemImage: "fork.knife",
                                color: .blue
                            )
                        }
                        
                        NavigationLink(destination: AddExerciseView()) {
                            QuickActionButton(
                                title: "Log Exercise", 
                                systemImage: "figure.walk",
                                color: .green
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private func dateFormatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
    
    private func latestGlucoseReading() -> String {
        if let latest = glucoseReadings.sorted(by: { $0.timestamp > $1.timestamp }).first {
            return String(format: "%.0f", latest.value)
        }
        return "--"
    }
    
    private func glucoseStatusColor() -> Color {
        if let latest = glucoseReadings.sorted(by: { $0.timestamp > $1.timestamp }).first {
            if latest.value < 70 {
                return .red
            } else if latest.value > 180 {
                return .orange
            } else {
                return .green
            }
        }
        return .gray
    }
    
    private func dailyCarbsTotal() -> String {
        let totalCarbs = todayFoodEntries.reduce(0) { $0 + $1.carbs }
        return String(format: "%.0f", totalCarbs)
    }
    
    private func dailyExerciseMinutes() -> String {
        let totalMinutes = todayExerciseEntries.reduce(0) { $0 + $1.durationInMinutes }
        return String(format: "%.0f", totalMinutes)
    }
    
    private func daysOfJourney() -> String {
        if let firstProfile = userProfiles.first {
            let days = Calendar.current.dateComponents([.day], from: firstProfile.diagnosisDate, to: Date()).day ?? 0
            return "\(days)"
        }
        return "0"
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let color: Color
    let isAnimating: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(color)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(Circle())
                .shadow(radius: 2)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct GlucoseChartView: View {
    let readings: [GlucoseReading]
    
    var filteredReadings: [GlucoseReading] {
        // Get last 7 days of readings
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        return readings.filter { $0.timestamp >= startDate }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        Chart(filteredReadings, id: \.id) { reading in
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
        .chartYScale(domain: 50...250)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday())
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}