import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var age: Int
    var weight: Double // in kg
    var height: Double // in cm
    var diagnosisDate: Date
    var targetGlucoseMin: Double
    var targetGlucoseMax: Double
    var targetDailyCarbs: Int
    var targetDailyExerciseMinutes: Int
    var lastUpdated: Date
    var useMetricSystem: Bool
    var onboardingCompleted: Bool

    var bmiCategory: String {
        if bmi < 18.5 {
            return "Underweight"
        } else if bmi < 25 {
            return "Normal"
        } else if bmi < 30 {
            return "Overweight"
        } else {
            return "Obese"
        }
    }

    var diabetesDuration: String {
        let components = Calendar.current.dateComponents([.year, .month], from: diagnosisDate, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0

        if years > 0 {
            return "\(years) year\(years == 1 ? "" : "s")"
        } else {
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        age: Int = 0,
        weight: Double = 0.0,
        height: Double = 0.0,
        diagnosisDate: Date = Date(),
        targetGlucoseMin: Double = 70.0,
        targetGlucoseMax: Double = 140.0,
        targetDailyCarbs: Int = 150,
        targetDailyExerciseMinutes: Int = 30,
        lastUpdated: Date = Date(),
        useMetricSystem: Bool = true,
        onboardingCompleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.weight = weight
        self.height = height
        self.diagnosisDate = diagnosisDate
        self.targetGlucoseMin = targetGlucoseMin
        self.targetGlucoseMax = targetGlucoseMax
        self.targetDailyCarbs = targetDailyCarbs
        self.targetDailyExerciseMinutes = targetDailyExerciseMinutes
        self.lastUpdated = lastUpdated
        self.useMetricSystem = useMetricSystem
        self.onboardingCompleted = onboardingCompleted
    }

    var bmi: Double {
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
}

extension UserProfile {
    @MainActor
    static func cleanupOldData(modelContext: ModelContext) async throws {
        // Keep last 3 months of data
        guard let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) else {
            throw DataError.invalidDate
        }

        // Preserve lifetime points across pruning: bank whatever the
        // soon-to-be-deleted data currently contributes, so the total stays
        // monotonic even after old readings are removed.
        let gamification = try modelContext.fetch(FetchDescriptor<GamificationProfile>()).first
        let userProfile = try modelContext.fetch(FetchDescriptor<UserProfile>()).first
        let derivedBefore: Int?
        if let gamification, let userProfile {
            derivedBefore = try gamification.derivedPoints(userProfile: userProfile, modelContext: modelContext)
        } else {
            derivedBefore = nil
        }

        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp < threeMonthsAgo
            }
        )

        let oldReadings = try modelContext.fetch(descriptor)
        oldReadings.forEach { modelContext.delete($0) }
        try modelContext.save()

        if let gamification, let userProfile, let derivedBefore {
            let derivedAfter = try gamification.derivedPoints(userProfile: userProfile, modelContext: modelContext)
            gamification.lifetimePointsCheckpoint += (derivedBefore - derivedAfter)
            try modelContext.save()
        }
    }

    /// Bounds within which each user-editable target must fall.
    enum TargetLimits {
        static let glucoseMin = 40.0...120.0
        static let glucoseMax = 140.0...250.0
        static let dailyCarbs = 0...500
        static let dailyExerciseMinutes = 0...360
    }

    func validateTargets() {
        targetGlucoseMin = targetGlucoseMin.clamped(to: TargetLimits.glucoseMin)
        targetGlucoseMax = targetGlucoseMax.clamped(to: TargetLimits.glucoseMax)
        targetDailyCarbs = targetDailyCarbs.clamped(to: TargetLimits.dailyCarbs)
        targetDailyExerciseMinutes = targetDailyExerciseMinutes.clamped(to: TargetLimits.dailyExerciseMinutes)
    }

    enum DataError: LocalizedError {
        case invalidDate
        case fetchFailed

        var errorDescription: String? {
            switch self {
            case .invalidDate: return String(localized: "Could not calculate date range")
            case .fetchFailed: return String(localized: "Failed to fetch data")
            }
        }
    }

    func glucoseProgress(modelContext: ModelContext, days: Int = 30) throws -> GlucoseProgress {
        let endDate = Date()
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else {
            throw DataError.invalidDate
        }

        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp >= startDate && reading.timestamp <= endDate
            }
        )

        let readings = try modelContext.fetch(descriptor)
        let totalReadings = readings.count

        // Handle case with no readings
        guard totalReadings > 0 else {
            return GlucoseProgress(
                inRangePercentage: 0,
                averageReading: 0,
                totalReadings: 0,
                daysAnalyzed: days
            )
        }

        let inRangeCount = readings.filter { $0.value >= targetGlucoseMin && $0.value <= targetGlucoseMax }.count
        let totalValue = readings.reduce(0.0) { $0 + $1.value }

        return GlucoseProgress(
            inRangePercentage: Double(inRangeCount) / Double(totalReadings) * 100,
            averageReading: totalValue / Double(totalReadings),
            totalReadings: totalReadings,
            daysAnalyzed: days
        )
    }

    struct GlucoseProgress {
        let inRangePercentage: Double
        let averageReading: Double
        let totalReadings: Int
        let daysAnalyzed: Int

        var status: ProgressStatus {
            switch inRangePercentage {
            case 80...: return .excellent
            case 60...: return .good
            case 40...: return .fair
            default: return .needsImprovement
            }
        }

        enum ProgressStatus {
            case excellent
            case good
            case fair
            case needsImprovement

            var description: LocalizedStringResource {
                switch self {
                case .excellent: "Excellent Control"
                case .good: "Good Control"
                case .fair: "Fair Control"
                case .needsImprovement: "Needs Improvement"
                }
            }
        }
    }

    func isOnTrackWithDailyCarbs(modelContext: ModelContext) throws -> Bool {
        let today = Date()
        let carbs = try FoodEntry.totalCarbsForDay(today, modelContext: modelContext)
        return carbs <= Double(targetDailyCarbs)
    }

    func isOnTrackWithExercise(modelContext: ModelContext) throws -> Bool {
        let today = Date()
        let duration = try ExerciseEntry.totalDurationForDay(today, modelContext: modelContext)
        return duration >= Double(targetDailyExerciseMinutes * 60) // Convert minutes to seconds
    }
}

extension ModelContext {
    @MainActor
    func resetAllData() async throws {
        // Delete in order to respect relationships
        try delete(model: GlucoseReading.self)
        try delete(model: FoodEntry.self)
        try delete(model: ExerciseEntry.self)
        try delete(model: EarnedAchievement.self)
        try delete(model: GamificationProfile.self)
        try delete(model: GoalPeriod.self)
        try delete(model: UserProfile.self)
        try save()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
