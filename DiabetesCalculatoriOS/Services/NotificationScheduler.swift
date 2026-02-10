import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule2hReminder(mealID: UUID, mealDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Recordatorio de glucosa"
        let measureAt = DateUtils.formatTime(mealDate.addingTimeInterval(2 * 60 * 60))
        content.body = "Mide tu glucosa 2 h despues de la comida (\(measureAt))."
        content.sound = .default

        let triggerDate = mealDate.addingTimeInterval(2 * 60 * 60)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, triggerDate.timeIntervalSinceNow),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "recordatorio_2h_\(mealID.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
