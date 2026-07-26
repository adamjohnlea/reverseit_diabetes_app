import Foundation
import Testing
@testable import ReverseItApp

struct NutritionLabelParserTests {
    @Test func parsesTypicalUSLabelTable() {
        let result = NutritionLabelParser.parse(rows: [
            ["Calories", "230"],
            ["Total Fat", "8g"],
            ["Total Carbohydrate", "37g"],
            ["Protein", "3g"]
        ])
        #expect(result.calories == 230)
        #expect(result.fat == 8)
        #expect(result.carbs == 37)
        #expect(result.protein == 3)
    }

    @Test func parsesLineBasedText() {
        let result = NutritionLabelParser.parse(lines: [
            "Calories 230",
            "Total Fat 8g",
            "Total Carbohydrate 37g",
            "Protein 3g"
        ])
        #expect(result.calories == 230)
        #expect(result.fat == 8)
        #expect(result.carbs == 37)
        #expect(result.protein == 3)
    }

    @Test func missingFieldsStayNil() {
        let result = NutritionLabelParser.parse(lines: [
            "Calories 150",
            "Total Carbohydrate 20g"
        ])
        #expect(result.calories == 150)
        #expect(result.carbs == 20)
        #expect(result.protein == nil)
        #expect(result.fat == nil)
        #expect(!result.isEmpty)
    }

    @Test func nonNutritionTextIsEmpty() {
        let result = NutritionLabelParser.parse(rows: [["hello"], ["world"]])
        #expect(result.isEmpty)
    }

    @Test func handlesUnitAndDecimalVariations() {
        let result = NutritionLabelParser.parse(lines: [
            "Calories 190 kcal",
            "Total Fat 1.5 g",
            "Total Carbohydrate 12 g",
            "Protein 0.5g"
        ])
        #expect(result.calories == 190)
        #expect(result.fat == 1.5)
        #expect(result.carbs == 12)
        #expect(result.protein == 0.5)
    }

    @Test func subRowsDoNotOverwriteTotals() {
        let result = NutritionLabelParser.parse(lines: [
            "Total Fat 8g",
            "Saturated Fat 1g",
            "Trans Fat 0g",
            "Total Carbohydrate 37g",
            "Dietary Fiber 4g",
            "Total Sugars 12g",
            "Includes 10g Added Sugars",
            "Protein 3g"
        ])
        #expect(result.fat == 8)
        #expect(result.carbs == 37)
        #expect(result.protein == 3)
    }

    @Test func ignoresCaloriesFromFatRow() {
        let result = NutritionLabelParser.parse(lines: [
            "Calories 250",
            "Calories from Fat 70",
            "Total Fat 8g"
        ])
        #expect(result.calories == 250)
        #expect(result.fat == 8)
    }

    @Test func picksPerServingFromTwoColumnRow() {
        let result = NutritionLabelParser.parse(rows: [
            ["Total Carbohydrate", "37g", "74g"]
        ])
        #expect(result.carbs == 37)
    }

    @Test func ignoresDailyValuePercentages() {
        let result = NutritionLabelParser.parse(rows: [
            ["Total Fat", "8g", "10%"],
            ["Total Carbohydrate", "37g", "13%"]
        ])
        #expect(result.fat == 8)
        #expect(result.carbs == 37)
    }

    @Test func isCaseAndWhitespaceInsensitive() {
        let result = NutritionLabelParser.parse(lines: [
            "  CALORIES  210 ",
            "total fat 9g",
            " Total Carbohydrate 30G ",
            " PROTEIN  6 g"
        ])
        #expect(result.calories == 210)
        #expect(result.fat == 9)
        #expect(result.carbs == 30)
        #expect(result.protein == 6)
    }

    @Test func ignoresMilligramValuesForMacros() {
        // Sodium/cholesterol rows are in mg and must never be read as a macro.
        let result = NutritionLabelParser.parse(lines: [
            "Total Fat 8g",
            "Sodium 160mg"
        ])
        #expect(result.fat == 8)
    }
}
