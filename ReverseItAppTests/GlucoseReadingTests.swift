import Foundation
import Testing
@testable import ReverseItApp

struct GlucoseReadingTests {
    @Test(arguments: [
        (40.0, GlucoseReading.ReadingStatus.low),
        (69.9, .low),
        (70.0, .normal),
        (180.0, .normal),
        (180.1, .high),
        (300.0, .high)
    ] as [(Double, GlucoseReading.ReadingStatus)])
    func readingStatusBoundaries(testCase: (value: Double, expected: GlucoseReading.ReadingStatus)) {
        let reading = GlucoseReading(value: testCase.value)
        #expect(reading.readingStatus == testCase.expected)
    }

    @Test func isInRangeIsInclusiveOfEndpoints() {
        #expect(GlucoseReading(value: 70).isInRange(min: 70, max: 140))
        #expect(GlucoseReading(value: 140).isInRange(min: 70, max: 140))
        #expect(!GlucoseReading(value: 69.9).isInRange(min: 70, max: 140))
        #expect(!GlucoseReading(value: 140.1).isInRange(min: 70, max: 140))
    }
}
