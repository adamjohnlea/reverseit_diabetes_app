import Foundation
import Testing
@testable import ReverseItApp

struct GamificationLevelsTests {
    @Test func firstLevelStartsAtZero() {
        let progress = Levels.progress(forTotalPoints: 0)
        #expect(progress.level == 1)
        #expect(progress.stageName == "Getting Started")
        #expect(progress.currentLevelFloor == 0)
        #expect(progress.nextLevelThreshold == 100)
        #expect(progress.pointsToNextLevel == 100)
        #expect(progress.fractionToNextLevel == 0)
    }

    @Test func levelIncrementsAtThreshold() {
        #expect(Levels.progress(forTotalPoints: 99).level == 1)

        let reached = Levels.progress(forTotalPoints: 100)
        #expect(reached.level == 2)
        #expect(reached.currentLevelFloor == 100)
        #expect(reached.nextLevelThreshold == 250)
    }

    @Test func fractionToNextLevelIsHalfwayAtMidpoint() {
        // Level 1 spans 0...100, so 50 points is halfway to level 2.
        #expect(Levels.progress(forTotalPoints: 50).fractionToNextLevel == 0.5)
    }

    @Test func progressionContinuesBeyondNamedTiers() {
        let top = Levels.progress(forTotalPoints: 3200)
        #expect(top.level == 10)
        #expect(top.stageName == "Champion")
        #expect(top.nextLevelThreshold == 4000)

        let beyond = Levels.progress(forTotalPoints: 4000)
        #expect(beyond.level == 11)
        #expect(beyond.stageName == "Champion")   // top name is reused past the tiers
        #expect(beyond.currentLevelFloor == 4000)
        #expect(beyond.nextLevelThreshold == 4800)
    }

    @Test func thresholdFormulaBeyondTable() {
        #expect(Levels.threshold(forLevel: 11) == 4000)
        #expect(Levels.threshold(forLevel: 12) == 4800)
    }
}
