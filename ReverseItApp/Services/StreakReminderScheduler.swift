import Foundation
import UserNotifications
import os

/// Schedules a single, gentle evening reminder when the user hasn't logged
/// anything yet today, to help keep their streak alive.
///
/// Opt-in only. The reminder is a one-shot request that is recomputed whenever
/// the app's state changes (scene changes, toggling the setting), so it never
/// fires on a day the user has already logged.
enum StreakReminderScheduler {
    /// Identifier of the single pending reminder request.
    static let reminderIdentifier = "streak-at-risk-reminder"
    /// The hour of day (24-hour) the evening nudge fires.
    static let reminderHour = 20

    private static let logger = Logger(subsystem: "ReverseIt", category: "StreakReminder")

    /// Requests notification authorization.
    ///
    /// - Returns: Whether permission was granted.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Reschedules — or removes — the evening streak nudge to match the current
    /// state. Safe to call often (e.g. on every scene change).
    ///
    /// - Parameters:
    ///   - enabled: Whether the user has opted into streak reminders.
    ///   - hasLoggedToday: Whether the user has already logged an entry today.
    ///   - now: The reference "current time".
    ///   - calendar: The calendar used to compute the fire date.
    static func refresh(
        enabled: Bool,
        hasLoggedToday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        guard enabled,
              let fireDate = nextFireDate(hasLoggedToday: hasLoggedToday, now: now, calendar: calendar) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Keep your streak going")
        content.body = String(localized: "You haven't logged anything today. A quick entry keeps your streak alive.")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule streak reminder: \(error.localizedDescription)")
        }
    }

    /// The next moment the evening nudge should fire, or `nil` if none applies.
    ///
    /// If nothing is logged yet today and it's still before the reminder hour,
    /// the nudge is scheduled for this evening; otherwise it's scheduled for
    /// tomorrow evening (when the app can reschedule again once the user logs).
    ///
    /// - Parameters:
    ///   - hasLoggedToday: Whether the user has already logged an entry today.
    ///   - now: The reference "current time".
    ///   - calendar: The calendar used to compute the fire date.
    static func nextFireDate(
        hasLoggedToday: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        guard let todayReminder = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: startOfToday) else {
            return nil
        }
        if !hasLoggedToday && now < todayReminder {
            return todayReminder
        }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return nil }
        return calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: tomorrow)
    }
}
