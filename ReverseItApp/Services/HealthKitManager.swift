import Foundation
import HealthKit
import SwiftData

/// Errors thrown by ``HealthKitManager``. Callers must surface these to the user.
enum HealthKitError: LocalizedError {
    case notAvailable
    case workoutSaveFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .workoutSaveFailed:
            return "The workout could not be saved to Apple Health."
        }
    }
}

/// A Sendable snapshot of a blood glucose sample read from HealthKit.
struct ImportedGlucoseSample: Sendable {
    /// Glucose concentration in mg/dL.
    let value: Double
    let date: Date
}

/// A Sendable snapshot of a workout read from HealthKit.
struct ImportedWorkout: Sendable {
    let type: ExerciseType
    let start: Date
    let duration: TimeInterval
    let kilocalories: Double?
}

@MainActor
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    /// `nil` when HealthKit is unavailable on this device; every operation
    /// silently no-ops (or returns empty) in that case.
    private let healthStore: HKHealthStore?

    var isHealthKitAuthorized = false

    /// mg/dL, the unit used for all glucose values in the app.
    private static let glucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .liter())

    private static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.bloodGlucose),
        HKQuantityType(.activeEnergyBurned),
        .workoutType(),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryFatTotal),
        HKQuantityType(.dietaryProtein),
        HKQuantityType(.bodyMass),
        HKQuantityType(.height)
    ]

    private static let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.bloodGlucose),
        HKQuantityType(.activeEnergyBurned),
        .workoutType(),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryFatTotal),
        HKQuantityType(.dietaryProtein)
    ]

    nonisolated init() {
        healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    // MARK: - Authorization

    /// Presents the HealthKit authorization sheet for all supported types.
    /// - Returns: Whether sharing is authorized after the prompt completes.
    func requestAuthorization() async throws -> Bool {
        guard let healthStore else { return false }

        try await healthStore.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        checkAuthorizationStatus()
        return isHealthKitAuthorized
    }

    func checkAuthorizationStatus() {
        guard let healthStore else {
            isHealthKitAuthorized = false
            return
        }

        let status = healthStore.authorizationStatus(for: HKQuantityType(.bloodGlucose))
        isHealthKitAuthorized = status == .sharingAuthorized
    }

    // MARK: - Reading

    /// Reads glucose samples from the last `days` days, oldest first.
    func fetchGlucoseSamples(forDays days: Int) async throws -> [ImportedGlucoseSample] {
        guard let healthStore else { return [] }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bloodGlucose), predicate: Self.datePredicate(lastDays: days))],
            sortDescriptors: [SortDescriptor(\.endDate)]
        )
        let samples = try await descriptor.result(for: healthStore)

        return samples.map {
            ImportedGlucoseSample(value: $0.quantity.doubleValue(for: Self.glucoseUnit), date: $0.startDate)
        }
    }

    /// Reads workouts from the last `days` days, oldest first.
    func fetchWorkouts(forDays days: Int) async throws -> [ImportedWorkout] {
        guard let healthStore else { return [] }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(Self.datePredicate(lastDays: days))],
            sortDescriptors: [SortDescriptor(\.endDate)]
        )
        let workouts = try await descriptor.result(for: healthStore)

        return workouts.map { workout in
            ImportedWorkout(
                type: ExerciseType(workoutActivityType: workout.workoutActivityType),
                start: workout.startDate,
                duration: workout.duration,
                kilocalories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie())
            )
        }
    }

    // MARK: - Writing

    func saveGlucoseReading(_ reading: GlucoseReading) async throws {
        guard let healthStore else { return }

        var metadata: [String: Any] = ["readingType": reading.readingType.rawValue]
        if let note = reading.note {
            metadata["note"] = note
        }
        // HKMetadataKeyBloodGlucoseMealTime requires an HKBloodGlucoseMealTime
        // number, which only exists for the two meal-relative reading types.
        switch reading.readingType {
        case .beforeMeal:
            metadata[HKMetadataKeyBloodGlucoseMealTime] = HKBloodGlucoseMealTime.preprandial.rawValue
        case .afterMeal:
            metadata[HKMetadataKeyBloodGlucoseMealTime] = HKBloodGlucoseMealTime.postprandial.rawValue
        case .fasting, .bedtime, .random:
            break
        }

        let sample = HKQuantitySample(
            type: HKQuantityType(.bloodGlucose),
            quantity: HKQuantity(unit: Self.glucoseUnit, doubleValue: reading.value),
            start: reading.timestamp,
            end: reading.timestamp,
            metadata: metadata
        )
        try await healthStore.save(sample)
    }

    func saveFoodEntry(_ entry: FoodEntry) async throws {
        guard let healthStore else { return }

        let metadata: [String: Any] = ["meal": entry.mealType.rawValue, "foodName": entry.name]

        func nutrientSample(_ identifier: HKQuantityTypeIdentifier, grams: Double) -> HKQuantitySample? {
            guard grams > 0 else { return nil }
            return HKQuantitySample(
                type: HKQuantityType(identifier),
                quantity: HKQuantity(unit: .gram(), doubleValue: grams),
                start: entry.timestamp,
                end: entry.timestamp,
                metadata: metadata
            )
        }

        let samples = [
            nutrientSample(.dietaryCarbohydrates, grams: entry.carbs),
            nutrientSample(.dietaryProtein, grams: entry.protein),
            nutrientSample(.dietaryFatTotal, grams: entry.fat)
        ].compactMap { $0 }

        guard !samples.isEmpty else { return }
        try await healthStore.save(samples)
    }

    func saveExerciseEntry(_ entry: ExerciseEntry) async throws {
        guard let healthStore else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = entry.exerciseType.workoutActivityType

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        let endDate = entry.startTime.addingTimeInterval(entry.duration)

        try await builder.beginCollection(at: entry.startTime)

        var metadata: [String: Any] = ["intensity": entry.intensity.rawValue]
        if let note = entry.note {
            metadata["note"] = note
        }
        try await builder.addMetadata(metadata)

        if let calories = entry.caloriesBurned {
            let energySample = HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: entry.startTime,
                end: endDate
            )
            try await builder.addSamples([energySample])
        }

        try await builder.endCollection(at: endDate)

        // finishWorkout returns nil when the workout could not be materialized
        // (for example, while the device is locked).
        guard try await builder.finishWorkout() != nil else {
            throw HealthKitError.workoutSaveFailed
        }
    }

    // MARK: - Import

    /// Imports the last week of glucose readings and workouts into the local store.
    func importDataFromHealthKit(modelContext: ModelContext) async throws {
        guard healthStore != nil else { throw HealthKitError.notAvailable }

        async let glucoseSamples = fetchGlucoseSamples(forDays: 7)
        async let workouts = fetchWorkouts(forDays: 7)

        for sample in try await glucoseSamples {
            modelContext.insert(GlucoseReading(timestamp: sample.date, value: sample.value))
        }
        for workout in try await workouts {
            modelContext.insert(
                ExerciseEntry(
                    type: workout.type.rawValue,
                    startTime: workout.start,
                    duration: workout.duration,
                    caloriesBurned: workout.kilocalories
                )
            )
        }
        try modelContext.save()
    }

    // MARK: - Helpers

    private static func datePredicate(lastDays days: Int) -> NSPredicate {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
    }
}
