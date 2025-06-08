import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var timestamp: Date
    var carbs: Double // in grams
    var protein: Double // in grams
    var fat: Double // in grams
    var calories: Double
    var mealType: MealType
    var photo: Data? // Optional photo of the food
    var note: String?
    
    @Relationship var glucoseReadings: [GlucoseReading]? = []
    
    enum MealType: String, Codable, CaseIterable {
        case breakfast = "breakfast"
        case lunch = "lunch"
        case dinner = "dinner"
        case snack = "snack"
        
        var description: String {
            switch self {
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            }
        }
        
        var icon: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.stars.fill"
            case .snack: return "star.fill"
            }
        }
    }
    
    var totalMacros: Double {
        return carbs + protein + fat
    }
    
    var macroPercentages: (carbs: Double, protein: Double, fat: Double) {
        let total = totalMacros
        guard total > 0 else { return (0, 0, 0) }
        
        return (
            carbs: (carbs / total) * 100,
            protein: (protein / total) * 100,
            fat: (fat / total) * 100
        )
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        timestamp: Date = Date(),
        carbs: Double,
        protein: Double,
        fat: Double,
        calories: Double,
        mealType: MealType,
        photo: Data? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.calories = calories
        self.mealType = mealType
        self.photo = photo
        self.note = note
    }
    
    func validate() -> Bool {
        guard !name.isEmpty,
              carbs >= 0, protein >= 0, fat >= 0,
              calories >= 0
        else {
            return false
        }
        return true
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var mealPeriod: String {
        let hour = Calendar.current.component(.hour, from: timestamp)
        switch hour {
        case 5..<11: return "Morning"
        case 11..<16: return "Afternoon"
        case 16..<22: return "Evening"
        default: return "Night"
        }
    }
}

extension FoodEntry {
    static func fetchMealsForDay(_ date: Date, modelContext: ModelContext) throws -> [FoodEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> { entry in
                entry.timestamp >= startOfDay && entry.timestamp < endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    static func totalCarbsForDay(_ date: Date, modelContext: ModelContext) throws -> Double {
        let meals = try fetchMealsForDay(date, modelContext: modelContext)
        return meals.reduce(0) { $0 + $1.carbs }
    }
    
    static func totalCaloriesForDay(_ date: Date, modelContext: ModelContext) throws -> Double {
        let meals = try fetchMealsForDay(date, modelContext: modelContext)
        return meals.reduce(0) { $0 + $1.calories }
    }
    
    func glucoseImpact(timeWindow: TimeInterval = 7200) -> [GlucoseReading]? {
        // Look for glucose readings within 2 hours after meal
        guard let readings = glucoseReadings else { return nil }
        
        return readings.filter { reading in
            reading.timestamp > timestamp && 
            reading.timestamp <= timestamp.addingTimeInterval(timeWindow)
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    var averageGlucoseImpact: Double? {
        guard let readings = glucoseImpact() else { return nil }
        guard !readings.isEmpty else { return nil }
        
        let sum = readings.reduce(0.0) { $0 + $1.value }
        return sum / Double(readings.count)
    }
    
    var carbPercentage: Double {
        guard calories > 0 else { return 0 }
        return (carbs * 4 / calories) * 100
    }
    
    var proteinPercentage: Double {
        guard calories > 0 else { return 0 }
        return (protein * 4 / calories) * 100
    }
    
    var fatPercentage: Double {
        guard calories > 0 else { return 0 }
        return (fat * 9 / calories) * 100
    }
}
