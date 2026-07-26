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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        return #Predicate<FoodEntry> { entry in
            entry.timestamp >= startOfDay && entry.timestamp < endOfDay
        }
    }

    private var todayExercisePredicate: Predicate<ExerciseEntry> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
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
                            .foregroundStyle(.secondary)
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
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal)

                        if glucoseReadings.isEmpty {
                            Text("No data yet. Add glucose readings to see your trend.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            GlucoseChartView(readings: weeklyReadings, targetRange: targetRange)
                                .frame(height: 200)
                                .padding(.horizontal)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground)))
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

    /// The 15 most recent readings from the last 7 days, for the weekly chart.
    private var weeklyReadings: [GlucoseReading] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return glucoseReadings.prefix(15).filter { $0.timestamp >= cutoff }
    }

    private var targetRange: ClosedRange<Double>? {
        guard let profile = userProfiles.first else { return nil }
        return profile.targetGlucoseMin...profile.targetGlucoseMax
    }

    private func dateFormatted() -> String {
        Date.now.formatted(date: .complete, time: .omitted)
    }

    // The @Query is already sorted newest-first.
    private func latestGlucoseReading() -> String {
        guard let latest = glucoseReadings.first else { return "--" }
        return String(format: "%.0f", latest.value)
    }

    private func glucoseStatusColor() -> Color {
        glucoseReadings.first?.readingStatus.color ?? .gray
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
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemGroupedBackground)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

/// Shared glucose chart used by the Dashboard and the Glucose Log.
///
/// Renders exactly the readings it is given (callers decide the window),
/// with an optional shaded band for the user's target range and point
/// colors matching each reading's status.
struct GlucoseChartView: View {
    let readings: [GlucoseReading]
    var targetRange: ClosedRange<Double>?

    private var sortedReadings: [GlucoseReading] {
        readings.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        Chart {
            if let targetRange {
                RectangleMark(
                    yStart: .value("Target Min", targetRange.lowerBound),
                    yEnd: .value("Target Max", targetRange.upperBound)
                )
                .foregroundStyle(.green.opacity(0.1))
            }

            ForEach(sortedReadings) { reading in
                LineMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("Glucose", reading.value)
                )
                .foregroundStyle(Color.pink.gradient)

                PointMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("Glucose", reading.value)
                )
                .foregroundStyle(reading.readingStatus.color)
            }
        }
        .chartYScale(domain: 50...250)
        .chartYAxisLabel("mg/dL")
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.weekday())
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .accessibilityLabel("Glucose trend chart")
    }
}
