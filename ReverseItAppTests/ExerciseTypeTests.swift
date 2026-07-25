import Foundation
import Testing
@testable import ReverseItApp

struct ExerciseTypeTests {
    @Test(arguments: ExerciseType.allCases.filter { $0 != .other })
    func healthKitMappingRoundTrips(type: ExerciseType) {
        #expect(ExerciseType(workoutActivityType: type.workoutActivityType) == type)
    }

    @Test func fuzzyMatchingRecognizesFreeText() {
        #expect(ExerciseType(matching: "morning jog") == .running)
        #expect(ExerciseType(matching: "Weightlifting at gym") == .weightTraining)
        #expect(ExerciseType(matching: "evening bike ride") == .cycling)
        #expect(ExerciseType(matching: "rock climbing") == .other)
    }

    @Test func exerciseTypeWrapperBridgesThePersistedString() {
        let entry = ExerciseEntry(type: "afternoon bike ride", duration: 600)
        #expect(entry.exerciseType == .cycling)

        entry.exerciseType = .tennis
        #expect(entry.type == "Tennis")
        #expect(entry.exerciseType == .tennis)
    }
}
