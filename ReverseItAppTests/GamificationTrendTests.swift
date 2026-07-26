import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

@MainActor
struct GamificationTrendTests {
    private let today = TestSupport.date(hour: 12)

    private func makeFixture() throws -> (GamificationProfile, UserProfile, ModelContext) {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175) // range 70...140
        context.insert(profile)
        let gamification = GamificationProfile()
        context.insert(gamification)
        return (gamification, profile, context)
    }

    private func addReadings(_ values: [Double], dayOffset: Int, to context: ModelContext) {
        for value in values {
            context.insert(GlucoseReading(timestamp: TestSupport.date(hour: 8, dayOffset: dayOffset), value: value))
        }
    }

    @Test func buildingWithoutEnoughData() throws {
        let (gamification, profile, context) = try makeFixture()
        let trend = try gamification.timeInRangeTrend(userProfile: profile, modelContext: context, asOf: today)
        #expect(trend == .building)
    }

    @Test func steadyWithOnlyRecentData() throws {
        let (gamification, profile, context) = try makeFixture()
        addReadings([100, 100, 100, 100, 100], dayOffset: -10, to: context) // all in range, recent window
        try context.save()

        let trend = try gamification.timeInRangeTrend(userProfile: profile, modelContext: context, asOf: today)
        guard case let .steady(recent) = trend else {
            Issue.record("Expected steady, got \(trend)")
            return
        }
        #expect(abs(recent - 100) < 0.001)
    }

    @Test func improvingWhenRecentIsHigher() throws {
        let (gamification, profile, context) = try makeFixture()
        addReadings([200, 200, 200, 200, 100], dayOffset: -45, to: context) // prior window: 1/5 in range
        addReadings([100, 100, 100, 100, 100], dayOffset: -10, to: context) // recent window: 5/5 in range
        try context.save()

        let trend = try gamification.timeInRangeTrend(userProfile: profile, modelContext: context, asOf: today)
        guard case let .improving(recent, previous) = trend else {
            Issue.record("Expected improving, got \(trend)")
            return
        }
        #expect(abs(recent - 100) < 0.001)
        #expect(abs(previous - 20) < 0.001)
    }

    @Test func steadyWhenNoMeaningfulImprovement() throws {
        let (gamification, profile, context) = try makeFixture()
        addReadings([100, 100, 100, 100, 100], dayOffset: -45, to: context) // prior: 100%
        addReadings([100, 100, 100, 100, 100], dayOffset: -10, to: context) // recent: 100%
        try context.save()

        let trend = try gamification.timeInRangeTrend(userProfile: profile, modelContext: context, asOf: today)
        guard case .steady = trend else {
            Issue.record("Expected steady, got \(trend)")
            return
        }
    }
}
