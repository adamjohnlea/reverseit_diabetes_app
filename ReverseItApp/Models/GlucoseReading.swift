import Foundation
import SwiftData

@Model
final class GlucoseReading {
    var id: UUID
    var timestamp: Date
    var value: Double // in mg/dL
    var note: String?
    var readingType: ReadingType
    
    @Relationship(deleteRule: .nullify) var relatedFood: [FoodEntry]? = []
    
    enum ReadingType: String, Codable, CaseIterable {
        case fasting
        case beforeMeal
        case afterMeal
        case bedtime
        case random
        
        var description: String {
            switch self {
            case .fasting: return "Fasting"
            case .beforeMeal: return "Before Meal"
            case .afterMeal: return "After Meal"
            case .bedtime: return "Bedtime"
            case .random: return "Random Check"
            }
        }
    }
    
    var readingStatus: ReadingStatus {
        if value < 70 {
            return .low
        } else if value > 180 {
            return .high
        } else {
            return .normal
        }
    }
    
    enum ReadingStatus {
        case low
        case normal
        case high
        
        var color: String {
            switch self {
            case .low: return "blue"
            case .normal: return "green"
            case .high: return "red"
            }
        }
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        value: Double,
        note: String? = nil,
        readingType: ReadingType = .random
    ) {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.note = note
        self.readingType = readingType
    }
    
    // Note: This uses default ranges. For user-specific ranges, use UserProfile.targetGlucoseMin/Max
    var isInRangeDefault: Bool {
        return value >= 70 && value <= 140
    }
    
    func isInRange(min: Double, max: Double) -> Bool {
        return value >= min && value <= max
    }
}

extension GlucoseReading {
    static func fetchLatestReadings(_ count: Int, modelContext: ModelContext) throws -> [GlucoseReading] {
        var descriptor = FetchDescriptor<GlucoseReading>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = count
        
        return try modelContext.fetch(descriptor)
    }
    
    static func averageForPeriod(start: Date, end: Date, modelContext: ModelContext) throws -> Double? {
        let descriptor = FetchDescriptor<GlucoseReading>(
            predicate: #Predicate<GlucoseReading> { reading in
                reading.timestamp >= start && reading.timestamp <= end
            }
        )
        
        let readings = try modelContext.fetch(descriptor)
        guard !readings.isEmpty else { return nil }
        
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
}
