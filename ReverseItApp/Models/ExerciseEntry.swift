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
        
        var description: String {
            switch self {
            case .light: return "Light"
            case .moderate: return "Moderate"
            case .vigorous: return "Vigorous"
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
    
    var estimatedCalories: Double {
        if let actual = caloriesBurned {
            return actual
        }
        
        return (durationInMinutes * intensity.metsMultiplier * 3.5) / 200.0
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
    
    static func totalCaloriesForDay(_ date: Date, modelContext: ModelContext) throws -> Double {
        let exercises = try fetchExercisesForDay(date, modelContext: modelContext)
        return exercises.reduce(0) { $0 + ($1.caloriesBurned ?? $1.estimatedCalories) }
    }
    
    var activityLevel: ActivityLevel {
        let caloriesPerHour = (caloriesBurned ?? estimatedCalories) / (duration / 3600)
        
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
        
        var description: String {
            switch self {
            case .light: return "Light Activity"
            case .moderate: return "Moderate Activity"
            case .intense: return "Intense Activity"
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
