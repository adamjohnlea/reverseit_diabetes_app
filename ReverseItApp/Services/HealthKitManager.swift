import Foundation
import HealthKit
import SwiftUI
import SwiftData

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore: HKHealthStore?
    
    @Published var isHealthKitAuthorized = false
    
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
    
    init() {
        // Check if HealthKit is available on this device
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
    }
    
    // Request authorization for HealthKit
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = healthStore else {
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isHealthKitAuthorized = success
                completion(success, error)
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
        
        DispatchQueue.main.async {
            self.isHealthKitAuthorized = (status == .sharingAuthorized)
        }
    }
    
    // MARK: - Read Methods
    
    // Read the most recent blood glucose value
    func fetchLatestGlucose(completion: @escaping (Double?, Error?) -> Void) {
        guard shouldRefreshData() else {
            // Return cached value if available
            completion(nil, nil)
            return
        }
        
        guard let healthStore = healthStore,
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil, nil)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: glucoseType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            DispatchQueue.main.async {
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil, error)
                    return
                }
                
                self.lastFetchDate = Date()
                let glucoseValue = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .milli).unitDivided(by: HKUnit.liter()))
                completion(glucoseValue, nil)
            }
        }
        
        healthStore.execute(query)
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
    func saveGlucoseReading(_ reading: GlucoseReading, completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = healthStore,
              let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(false, nil)
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
        
        healthStore.save(sample) { (success, error) in
            completion(success, error)
        }
    }
    
    // Save a food entry to HealthKit
    func saveFoodEntry(_ entry: FoodEntry, completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = healthStore else {
            completion(false, nil)
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
        
        if allSamples.isEmpty {
            completion(false, nil)
            return
        }
        
        healthStore.save(allSamples) { (success, error) in
            completion(success, error)
        }
    }
    
    // Save an exercise entry to HealthKit
    func saveExerciseEntry(_ entry: ExerciseEntry, completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = healthStore else {
            completion(false, nil)
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
        
        healthStore.save(workout) { (success, error) in
            completion(success, error)
        }
    }
    
    func importDataFromHealthKit(modelContext: ModelContext, completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var importSuccess = true
        
        // Import glucose readings - limit to 7 days and batch process
        group.enter()
        fetchGlucoseReadings(forDays: 7) { samples, error in
            guard let samples = samples, error == nil else {
                importSuccess = false
                group.leave()
                return
            }
            
            // Process in small batches to reduce memory pressure
            let batchSize = 20
            let batches = stride(from: 0, to: samples.count, by: batchSize).map {
                Array(samples[$0..<min($0 + batchSize, samples.count)])
            }
            
            for batch in batches {
                autoreleasepool {
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
                    } catch {
                        print("Error saving batch: \(error)")
                        importSuccess = false
                    }
                }
            }
            
            group.leave()
        }
        
        // Import workouts - limit to 7 days and batch process
        group.enter()
        fetchWorkouts(forDays: 7) { workouts, error in
            guard let workouts = workouts, error == nil else {
                importSuccess = false
                group.leave()
                return
            }
            
            // Process in small batches
            let batchSize = 10
            let batches = stride(from: 0, to: workouts.count, by: batchSize).map {
                Array(workouts[$0..<min($0 + batchSize, workouts.count)])
            }
            
            for batch in batches {
                autoreleasepool {
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
                    } catch {
                        print("Error saving batch: \(error)")
                        importSuccess = false
                    }
                }
            }
            
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(importSuccess)
        }
    }
    
    // Helper to map HKWorkoutActivityType back to string
    private func exerciseTypeFromWorkout(_ workout: HKWorkout) -> String {
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
