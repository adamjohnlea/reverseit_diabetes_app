import Foundation
import Testing
@testable import ReverseItApp

struct FoodEntryTests {
    private func makeEntry(
        name: String = "Bowl",
        timestamp: Date = TestSupport.date(hour: 12),
        carbs: Double = 50,
        protein: Double = 25,
        fat: Double = 10,
        calories: Double = 390
    ) -> FoodEntry {
        FoodEntry(
            name: name,
            timestamp: timestamp,
            carbs: carbs,
            protein: protein,
            fat: fat,
            calories: calories,
            mealType: .lunch
        )
    }

    @Test func macroPercentagesSumToOneHundred() {
        let percentages = makeEntry().macroPercentages
        #expect(abs(percentages.carbs + percentages.protein + percentages.fat - 100) < 0.001)
        #expect(abs(percentages.carbs - 58.82) < 0.01)
        #expect(abs(percentages.protein - 29.41) < 0.01)
        #expect(abs(percentages.fat - 11.76) < 0.01)
    }

    @Test func macroPercentagesAreZeroWithoutMacros() {
        let percentages = makeEntry(carbs: 0, protein: 0, fat: 0, calories: 0).macroPercentages
        #expect(percentages.carbs == 0)
        #expect(percentages.protein == 0)
        #expect(percentages.fat == 0)
    }

    @Test func caloriePercentagesUseAtwaterFactors() {
        let entry = makeEntry()
        #expect(abs(entry.carbPercentage - 51.28) < 0.01)
        #expect(abs(entry.proteinPercentage - 25.64) < 0.01)
        #expect(abs(entry.fatPercentage - 23.08) < 0.01)
    }

    @Test func caloriePercentagesAreZeroWithoutCalories() {
        let entry = makeEntry(calories: 0)
        #expect(entry.carbPercentage == 0)
        #expect(entry.proteinPercentage == 0)
        #expect(entry.fatPercentage == 0)
    }

    @Test func validateRejectsEmptyNameAndNegativeValues() {
        #expect(makeEntry().validate())
        #expect(!makeEntry(name: "").validate())
        #expect(!makeEntry(carbs: -1).validate())
        #expect(!makeEntry(protein: -1).validate())
        #expect(!makeEntry(fat: -1).validate())
        #expect(!makeEntry(calories: -1).validate())
    }

    @Test(arguments: [
        (4, "Night"),
        (5, "Morning"),
        (10, "Morning"),
        (11, "Afternoon"),
        (15, "Afternoon"),
        (16, "Evening"),
        (21, "Evening"),
        (22, "Night")
    ] as [(Int, String)])
    func mealPeriodBucketsByHour(testCase: (hour: Int, expected: String)) {
        let entry = makeEntry(timestamp: TestSupport.date(hour: testCase.hour))
        #expect(entry.mealPeriod == testCase.expected)
    }
}
