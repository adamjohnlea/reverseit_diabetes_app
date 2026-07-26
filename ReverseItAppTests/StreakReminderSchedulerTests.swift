import Foundation
import Testing
@testable import ReverseItApp

struct StreakReminderSchedulerTests {
    private let calendar = Calendar.current

    @Test func schedulesThisEveningWhenNotYetLoggedAndBeforeReminderHour() throws {
        let now = TestSupport.date(hour: 10)
        let fire = try #require(StreakReminderScheduler.nextFireDate(hasLoggedToday: false, now: now))
        #expect(calendar.component(.hour, from: fire) == StreakReminderScheduler.reminderHour)
        #expect(calendar.isDate(fire, inSameDayAs: now))
    }

    @Test func schedulesTomorrowWhenAlreadyLoggedToday() throws {
        let now = TestSupport.date(hour: 10)
        let fire = try #require(StreakReminderScheduler.nextFireDate(hasLoggedToday: true, now: now))
        #expect(fire > now)
        #expect(!calendar.isDate(fire, inSameDayAs: now))
        #expect(calendar.component(.hour, from: fire) == StreakReminderScheduler.reminderHour)
    }

    @Test func schedulesTomorrowWhenPastTheReminderHour() throws {
        let now = TestSupport.date(hour: 21)
        let fire = try #require(StreakReminderScheduler.nextFireDate(hasLoggedToday: false, now: now))
        #expect(fire > now)
        #expect(!calendar.isDate(fire, inSameDayAs: now))
        #expect(calendar.component(.hour, from: fire) == StreakReminderScheduler.reminderHour)
    }
}
