import Foundation
import Testing
import SwiftData
@testable import ReverseItApp

struct GamificationFreezeRefillTests {
    private let calendar = Calendar.current

    @Test func noRefillWithinTheSameMonth() {
        let june15 = TestSupport.date(hour: 12)
        let profile = GamificationProfile(streakFreezesRemaining: 0, freezeAllotmentMonth: june15)

        let refilled = profile.refillFreezesIfNeeded(now: TestSupport.date(hour: 12, dayOffset: 5)) // still June
        #expect(refilled == false)
        #expect(profile.streakFreezesRemaining == 0)
    }

    @Test func refillsWhenANewMonthBegins() throws {
        let june15 = TestSupport.date(hour: 12)
        let profile = GamificationProfile(streakFreezesRemaining: 0, freezeAllotmentMonth: june15)

        let july = try #require(calendar.date(byAdding: .day, value: 30, to: june15)) // mid-July
        let refilled = profile.refillFreezesIfNeeded(now: july)
        #expect(refilled == true)
        #expect(profile.streakFreezesRemaining == GamificationProfile.monthlyFreezeAllotment)
    }
}

@MainActor
struct RetentionCheckpointTests {
    @Test func cleanupPreservesLifetimePoints() async throws {
        let context = try TestSupport.makeInMemoryContext()
        let profile = UserProfile(name: "Test", age: 40, weight: 80, height: 175)
        context.insert(profile)
        let gamification = GamificationProfile()
        context.insert(gamification)

        // One recent reading (kept) and one older than the 3-month window (pruned).
        context.insert(GlucoseReading(timestamp: Date().addingTimeInterval(-24 * 3600), value: 100))
        context.insert(GlucoseReading(timestamp: Date().addingTimeInterval(-120 * 24 * 3600), value: 100))
        try context.save()

        let before = try gamification.totalPoints(userProfile: profile, modelContext: context)
        try await UserProfile.cleanupOldData(modelContext: context)
        let after = try gamification.totalPoints(userProfile: profile, modelContext: context)

        // The pruned day's points are banked, so the lifetime total is unchanged.
        #expect(after == before)
        #expect(gamification.lifetimePointsCheckpoint > 0)

        let remaining = try context.fetch(FetchDescriptor<GlucoseReading>())
        #expect(remaining.count == 1)
    }
}
