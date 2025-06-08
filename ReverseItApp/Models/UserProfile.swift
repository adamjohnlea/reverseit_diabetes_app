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
    static func cleanupOldData(modelContext: ModelContext) {
        // Keep last 3 months of data
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp < threeMonthsAgo
            }
        )
        
        do {
            let oldReadings = try modelContext.fetch(descriptor)
            oldReadings.forEach { modelContext.delete($0) }
            try modelContext.save()
        } catch {
            print("Error cleaning up old data: \(error)")
        }
    }
    
    func validateTargets() {
        // Ensure targets are within reasonable ranges
        targetGlucoseMin = max(40, min(targetGlucoseMin, 120))
        targetGlucoseMax = max(140, min(targetGlucoseMax, 250))
        targetDailyCarbs = max(0, min(targetDailyCarbs, 500))
        targetDailyExerciseMinutes = max(0, min(targetDailyExerciseMinutes, 360))
    }
    
    func glucoseProgress(modelContext: ModelContext, days: Int = 30) throws -> GlucoseProgress {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp >= startDate && reading.timestamp <= endDate
            }
        )
        
        let readings = try modelContext.fetch(descriptor)
        let totalReadings = readings.count
        let inRangeCount = readings.filter { $0.value >= targetGlucoseMin && $0.value <= targetGlucoseMax }.count
        
        return GlucoseProgress(
            inRangePercentage: Double(inRangeCount) / Double(totalReadings) * 100,
            averageReading: readings.reduce(0.0) { $0 + $1.value } / Double(totalReadings),
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
            
            var description: String {
                switch self {
                case .excellent: return "Excellent Control"
                case .good: return "Good Control"
                case .fair: return "Fair Control"
                case .needsImprovement: return "Needs Improvement"
                }
            }
            
            var color: String {
                switch self {
                case .excellent: return "green"
                case .good: return "blue"
                case .fair: return "yellow"
                case .needsImprovement: return "red"
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
    func resetAllData() throws {
        try delete(model: UserProfile.self)
        try delete(model: GlucoseReading.self)
        try delete(model: FoodEntry.self)
        try delete(model: ExerciseEntry.self)
        try save()
    }
}
