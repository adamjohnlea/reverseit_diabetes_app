import Foundation
import HealthKit
import SwiftUI
import SwiftData

@MainActor
@Observable
class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore: HKHealthStore?
    
    var isHealthKitAuthorized = false
    
    // Health data types we want to read from HealthKit
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!
    ]
    
    // Health data types we want to write to HealthKit
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!
    ]
    
    private var lastFetchDate: Date?
    private let minimumFetchInterval: TimeInterval = 60 // 1 minute
    
    nonisolated init() {
        // Check if HealthKit is available on this device
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
    }
    
    // Request authorization for HealthKit
    func requestAuthorization() async throws -> Bool {
        guard let healthStore = healthStore else {
            return false
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
                Task { @MainActor in
                    self?.isHealthKitAuthorized = success
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: success)
                    }
                }
            }
        }
    }
    
    // Check the authorization status
    func checkAuthorizationStatus() {
        guard let healthStore = healthStore else {
            isHealthKitAuthorized = false
            return
        }
        
        let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
        let status = healthStore.authorizationStatus(for: bloodGlucoseType)
        
        isHealthKitAuthorized = (status == .sharingAuthorized)
    }
    
    // MARK: - Read Methods
    
    // Read the most recent blood glucose value
    func fetchLatestGlucose() async throws -> Double? {
        guard let healthStore = healthStore,
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: glucoseType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    self?.lastFetchDate = Date()
                    let glucoseValue = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter()))
                    continuation.resume(returning: glucoseValue)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func shouldRefreshData() -> Bool {
        guard let lastFetch = lastFetchDate else { return true }
        return Date().timeIntervalSince(lastFetch) > minimumFetchInterval
    }
    
    // Fetch blood glucose readings for the last days
    func fetchGlucoseReadings(forDays days: Int, completion: @escaping ([HKQuantitySample]?, Error?) -> Void) {
        guard let healthStore = healthStore,
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil, nil)
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample] else {
                completion(nil, error)
                return
            }
            
            completion(samples, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch workouts for the last days
    func fetchWorkouts(forDays days: Int, completion: @escaping ([HKWorkout]?, Error?) -> Void) {
        guard let healthStore = healthStore else {
            completion(nil, nil)
            return
        }
        
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let workouts = samples as? [HKWorkout] else {
                completion(nil, error)
                return
            }
            
            completion(workouts, nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Write Methods
    
    // Save a blood glucose reading to HealthKit
    func saveGlucoseReading(_ reading: GlucoseReading) async throws {
        guard let healthStore = healthStore,
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            return
        }
        
        // Convert mg/dL to mmol/L if needed
        let value = reading.value 
        let unit = HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter())
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        
        // Create metadata if we have a note
        var metadata: [String: Any]? = nil
        if let note = reading.note {
            metadata = [HKMetadataKeyBloodGlucoseMealTime: reading.readingType.rawValue, 
                        "note": note]
        } else {
            metadata = [HKMetadataKeyBloodGlucoseMealTime: reading.readingType.rawValue]
        }
        
        let sample = HKQuantitySample(type: glucoseType, 
                                      quantity: quantity, 
                                      start: reading.timestamp, 
                                      end: reading.timestamp,
                                      metadata: metadata)
        
        try await healthStore.save(sample)
    }
    
    // Save a food entry to HealthKit
    func saveFoodEntry(_ entry: FoodEntry) async throws {
        guard let healthStore = healthStore else {
            return
        }
        
        var allSamples: [HKSample] = []
        
        // Create carbs sample
        if entry.carbs > 0, let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbsQuantity = HKQuantity(unit: .gram(), doubleValue: entry.carbs)
            let carbsSample = HKQuantitySample(type: carbsType, 
                                             quantity: carbsQuantity, 
                                             start: entry.timestamp, 
                                             end: entry.timestamp,
                                             metadata: ["meal": entry.mealType.rawValue, "foodName": entry.name])
            allSamples.append(carbsSample)
        }
        
        // Create protein sample
        if entry.protein > 0, let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinQuantity = HKQuantity(unit: .gram(), doubleValue: entry.protein)
            let proteinSample = HKQuantitySample(type: proteinType, 
                                              quantity: proteinQuantity, 
                                              start: entry.timestamp, 
                                              end: entry.timestamp,
                                              metadata: ["meal": entry.mealType.rawValue, "foodName": entry.name])
            allSamples.append(proteinSample)
        }
        
        // Create fat sample
        if entry.fat > 0, let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fatQuantity = HKQuantity(unit: .gram(), doubleValue: entry.fat)
            let fatSample = HKQuantitySample(type: fatType, 
                                          quantity: fatQuantity, 
                                          start: entry.timestamp, 
                                          end: entry.timestamp,
                                          metadata: ["meal": entry.mealType.rawValue, "foodName": entry.name])
            allSamples.append(fatSample)
        }
        
        guard !allSamples.isEmpty else {
            return
        }
        
        try await healthStore.save(allSamples)
    }
    
    // Save an exercise entry to HealthKit
    func saveExerciseEntry(_ entry: ExerciseEntry) async throws {
        guard let healthStore = healthStore else {
            return
        }
        
        // Get the appropriate workout activity type
        let workoutType = workoutActivityType(for: entry.type)
        
        // Create metadata if we have a note
        var metadata: [String: Any] = ["intensity": entry.intensity.rawValue]
        if let note = entry.note {
            metadata["note"] = note
        }
        
        // Create the workout
        let endDate = entry.startTime.addingTimeInterval(entry.duration)
        let energyBurned = entry.caloriesBurned != nil ? HKQuantity(unit: .kilocalorie(), doubleValue: entry.caloriesBurned!) : nil
        
        let workout = HKWorkout(activityType: workoutType,
                                start: entry.startTime,
                                end: endDate,
                                duration: entry.duration,
                                totalEnergyBurned: energyBurned,
                                totalDistance: nil,
                                metadata: metadata)
        
        try await healthStore.save(workout)
    }
    
    func importDataFromHealthKit(modelContext: ModelContext) async -> Bool {
        return await withTaskGroup(of: Bool.self) { group in
            // Import glucose readings
            group.addTask {
                do {
                    guard let samples = try await self.fetchGlucoseReadingsAsync(forDays: 7) else {
                        return false
                    }
                    
                    // Process in small batches to reduce memory pressure
                    let batchSize = 20
                    let batches = stride(from: 0, to: samples.count, by: batchSize).map {
                        Array(samples[$0..<min($0 + batchSize, samples.count)])
                    }
                    
                    for batch in batches {
                        let batchSuccess = autoreleasepool { () -> Bool in
                            for sample in batch {
                                let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter()))
                                let timestamp = sample.startDate
                                let readingType: GlucoseReading.ReadingType = .random
                                
                                let reading = GlucoseReading(timestamp: timestamp, value: value, readingType: readingType)
                                modelContext.insert(reading)
                            }
                            
                            // Save after each batch to reduce memory footprint
                            do {
                                try modelContext.save()
                                return true
                            } catch {
                                print("Error saving batch: \(error)")
                                return false
                            }
                        }
                        
                        if !batchSuccess {
                            return false
                        }
                    }
                    return true
                } catch {
                    return false
                }
            }
            
            // Import workouts
            group.addTask {
                do {
                    guard let workouts = try await self.fetchWorkoutsAsync(forDays: 7) else {
                        return false
                    }
                    
                    // Process in small batches
                    let batchSize = 10
                    let batches = stride(from: 0, to: workouts.count, by: batchSize).map {
                        Array(workouts[$0..<min($0 + batchSize, workouts.count)])
                    }
                    
                    for batch in batches {
                        let batchSuccess = autoreleasepool { () -> Bool in
                            for workout in batch {
                                let type = self.exerciseTypeFromWorkout(workout)
                                let startTime = workout.startDate
                                let duration = workout.duration
                                var caloriesBurned: Double? = nil
                                
                                if let energyBurned = workout.totalEnergyBurned {
                                    caloriesBurned = energyBurned.doubleValue(for: .kilocalorie())
                                }
                                
                                let intensity: ExerciseEntry.ExerciseIntensity = .moderate
                                
                                let exerciseEntry = ExerciseEntry(
                                    type: type,
                                    startTime: startTime,
                                    duration: duration,
                                    caloriesBurned: caloriesBurned,
                                    intensity: intensity
                                )
                                
                                modelContext.insert(exerciseEntry)
                            }
                            
                            // Save after each batch
                            do {
                                try modelContext.save()
                                return true
                            } catch {
                                print("Error saving batch: \(error)")
                                return false
                            }
                        }
                        
                        if !batchSuccess {
                            return false
                        }
                    }
                    return true
                } catch {
                    return false
                }
            }
            
            // Wait for all tasks and return true only if all succeeded
            var allSucceeded = true
            for await result in group {
                if !result {
                    allSucceeded = false
                }
            }
            return allSucceeded
        }
    }
    
    // Async wrapper for fetchGlucoseReadings
    private func fetchGlucoseReadingsAsync(forDays days: Int) async throws -> [HKQuantitySample]? {
        return try await withCheckedThrowingContinuation { continuation in
            fetchGlucoseReadings(forDays: days) { samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples)
                }
            }
        }
    }
    
    // Async wrapper for fetchWorkouts
    private func fetchWorkoutsAsync(forDays days: Int) async throws -> [HKWorkout]? {
        return try await withCheckedThrowingContinuation { continuation in
            fetchWorkouts(forDays: days) { workouts, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workouts)
                }
            }
        }
    }
    
    // Helper to map HKWorkoutActivityType back to string
    private nonisolated func exerciseTypeFromWorkout(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .traditionalStrengthTraining:
            return "Weight Training"
        case .pilates:
            return "Pilates"
        case .dance:
            return "Dance"
        case .hiking:
            return "Hiking"
        case .tennis:
            return "Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .rowing:
            return "Rowing"
        case .elliptical:
            return "Elliptical"
        default:
            return "Other Exercise"
        }
    }
    
    // Helper method to map exercise type to HKWorkoutActivityType
    private func workoutActivityType(for exerciseType: String) -> HKWorkoutActivityType {
        let type = exerciseType.lowercased()
        
        if type.contains("walk") {
            return .walking
        } else if type.contains("run") || type.contains("jog") {
            return .running
        } else if type.contains("bike") || type.contains("cycle") {
            return .cycling
        } else if type.contains("swim") {
            return .swimming
        } else if type.contains("yoga") {
            return .yoga
        } else if type.contains("hiit") {
            return .highIntensityIntervalTraining
        } else if type.contains("weight") || type.contains("gym") {
            return .traditionalStrengthTraining
        } else if type.contains("pilates") {
            return .pilates
        } else if type.contains("dance") {
            return .dance
        } else if type.contains("hike") || type.contains("hiking") {
            return .hiking
        } else if type.contains("tennis") {
            return .tennis
        } else if type.contains("basketball") {
            return .basketball
        } else if type.contains("soccer") || type.contains("football") {
            return .soccer
        } else if type.contains("row") {
            return .rowing
        } else if type.contains("elliptical") {
            return .elliptical
        }
        
        return .other
    }
}
