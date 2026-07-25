import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

struct UserProfileTests {
    @Test func bmiIsComputedFromMetricStorage() {
        let profile = UserProfile(weight: 70, height: 175)
        #expect(abs(profile.bmi - 22.857) < 0.01)
    }

    @Test(arguments: [
        (18.49, "Underweight"),
        (18.5, "Normal"),
        (24.99, "Normal"),
        (25.0, "Overweight"),
        (29.99, "Overweight"),
        (30.0, "Obese")
    ] as [(Double, String)])
    func bmiCategoryBoundaries(testCase: (bmi: Double, expected: String)) {
        // Height of 100 cm makes BMI numerically equal to weight in kg.
        let profile = UserProfile(weight: testCase.bmi, height: 100)
        #expect(profile.bmiCategory == testCase.expected)
    }

    @Test func validateTargetsClampsOutOfRangeValues() {
        let profile = UserProfile(
            targetGlucoseMin: 30,
            targetGlucoseMax: 300,
            targetDailyCarbs: 600,
            targetDailyExerciseMinutes: 400
        )
        profile.validateTargets()
        #expect(profile.targetGlucoseMin == 40)
        #expect(profile.targetGlucoseMax == 250)
        #expect(profile.targetDailyCarbs == 500)
        #expect(profile.targetDailyExerciseMinutes == 360)
    }

    @Test func validateTargetsKeepsInRangeValues() {
        let profile = UserProfile(
            targetGlucoseMin: 80,
            targetGlucoseMax: 160,
            targetDailyCarbs: 100,
            targetDailyExerciseMinutes: 45
        )
        profile.validateTargets()
        #expect(profile.targetGlucoseMin == 80)
        #expect(profile.targetGlucoseMax == 160)
        #expect(profile.targetDailyCarbs == 100)
        #expect(profile.targetDailyExerciseMinutes == 45)
    }

    @Test(arguments: [
        (80.0, UserProfile.GlucoseProgress.ProgressStatus.excellent),
        (79.9, .good),
        (60.0, .good),
        (59.9, .fair),
        (40.0, .fair),
        (39.9, .needsImprovement)
    ] as [(Double, UserProfile.GlucoseProgress.ProgressStatus)])
    func progressStatusThresholds(testCase: (percentage: Double, expected: UserProfile.GlucoseProgress.ProgressStatus)) {
        let progress = UserProfile.GlucoseProgress(
            inRangePercentage: testCase.percentage,
            averageReading: 0,
            totalReadings: 0,
            daysAnalyzed: 30
        )
        #expect(progress.status == testCase.expected)
    }

    @MainActor
    @Test func glucoseProgressComputesInRangePercentageAndAverage() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(targetGlucoseMin: 70, targetGlucoseMax: 140)
        context.insert(profile)
        for value in [100.0, 200.0, 65.0, 120.0] {
            context.insert(GlucoseReading(timestamp: Date().addingTimeInterval(-3600), value: value))
        }
        try context.save()

        let progress = try profile.glucoseProgress(modelContext: context, days: 30)
        #expect(progress.totalReadings == 4)
        #expect(progress.inRangePercentage == 50)
        #expect(abs(progress.averageReading - 121.25) < 0.001)
    }

    @MainActor
    @Test func glucoseProgressIsZeroedWithoutReadings() throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile()
        context.insert(profile)

        let progress = try profile.glucoseProgress(modelContext: context, days: 30)
        #expect(progress.totalReadings == 0)
        #expect(progress.inRangePercentage == 0)
        #expect(progress.averageReading == 0)
    }
}
