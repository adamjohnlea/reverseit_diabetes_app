import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    var id: UUID
    var type: String
    var startTime: Date
    var duration: TimeInterval // in seconds
    var caloriesBurned: Double?
    var intensity: ExerciseIntensity
    var note: String?
    
    enum ExerciseIntensity: String, Codable, CaseIterable {
        case light
        case moderate
        case vigorous
        
        var description: LocalizedStringResource {
            switch self {
            case .light: "Light"
            case .moderate: "Moderate"
            case .vigorous: "Vigorous"
            }
        }
        
        var metsMultiplier: Double {
            switch self {
            case .light: return 2.0
            case .moderate: return 4.0
            case .vigorous: return 6.0
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        type: String,
        startTime: Date = Date(),
        duration: TimeInterval,
        caloriesBurned: Double? = nil,
        intensity: ExerciseIntensity = .moderate,
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.duration = duration
        self.caloriesBurned = caloriesBurned
        self.intensity = intensity
        self.note = note
    }
    
    var durationInMinutes: Double {
        return duration / 60.0
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Constants of the standard MET energy formula:
    /// kcal/min = METs × 3.5 × body weight (kg) ÷ 200.
    enum MET {
        /// Resting oxygen consumption in mL·kg⁻¹·min⁻¹ (1 MET by definition).
        static let restingOxygenConsumption = 3.5
        /// Milliliters of oxygen consumed per kilocalorie burned.
        static let millilitersOfOxygenPerKilocalorie = 200.0
    }

    /// Estimated energy burned for this session using the standard MET formula,
    /// preferring the measured `caloriesBurned` when the entry has one.
    ///
    /// - Parameter weightKg: The user's body weight in kilograms.
    func estimatedCalories(weightKg: Double) -> Double {
        if let actual = caloriesBurned {
            return actual
        }

        return durationInMinutes * intensity.metsMultiplier
            * MET.restingOxygenConsumption * weightKg
            / MET.millilitersOfOxygenPerKilocalorie
    }
}

extension ExerciseEntry {
    static func fetchExercisesForDay(_ date: Date, modelContext: ModelContext) throws -> [ExerciseEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<ExerciseEntry>(
            predicate: #Predicate<ExerciseEntry> { entry in
                entry.startTime >= startOfDay && entry.startTime < endOfDay
            },
            sortBy: [SortDescriptor(\.startTime)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    static func totalDurationForDay(_ date: Date, modelContext: ModelContext) throws -> TimeInterval {
        let exercises = try fetchExercisesForDay(date, modelContext: modelContext)
        return exercises.reduce(0) { $0 + $1.duration }
    }
    
    static func totalCaloriesForDay(_ date: Date, weightKg: Double, modelContext: ModelContext) throws -> Double {
        let exercises = try fetchExercisesForDay(date, modelContext: modelContext)
        return exercises.reduce(0) { $0 + $1.estimatedCalories(weightKg: weightKg) }
    }

    func activityLevel(weightKg: Double) -> ActivityLevel {
        let caloriesPerHour = estimatedCalories(weightKg: weightKg) / (duration / 3600)

        switch caloriesPerHour {
        case ..<200: return .light
        case 200..<400: return .moderate
        case 400...: return .intense
        default: return .moderate
        }
    }
    
    enum ActivityLevel {
        case light
        case moderate
        case intense
        
        var description: LocalizedStringResource {
            switch self {
            case .light: "Light Activity"
            case .moderate: "Moderate Activity"
            case .intense: "Intense Activity"
            }
        }
        
        var icon: String {
            switch self {
            case .light: return "figure.walk"
            case .moderate: return "figure.run"
            case .intense: return "figure.highintensity.intervaltraining"
            }
        }
    }
    
    func progressTowardDailyGoal(targetMinutes: Int) -> Double {
        return min(durationInMinutes / Double(targetMinutes), 1.0)
    }
}
