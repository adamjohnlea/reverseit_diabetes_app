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
    
    /// Clinical classification thresholds, in mg/dL.
    enum Threshold {
        static let low = 70.0
        static let high = 180.0
    }

    var readingStatus: ReadingStatus {
        if value < Threshold.low {
            return .low
        } else if value > Threshold.high {
            return .high
        } else {
            return .normal
        }
    }

    enum ReadingStatus {
        case low
        case normal
        case high

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
