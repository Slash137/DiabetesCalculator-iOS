import Foundation

enum DateUtils {
    static let esLocale = Locale(identifier: "es_ES")

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = esLocale
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = esLocale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = esLocale
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func formatDateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    static func endOfToday() -> Date {
        let start = startOfToday()
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func relativeDayLabel(for date: Date) -> String {
        let todayStart = startOfToday()
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let dayStart = startOfDay(date)

        if dayStart >= todayStart {
            return "Hoy"
        }
        if dayStart >= yesterdayStart {
            return "Ayer"
        }
        return formatDate(date)
    }

    static func relativeDateTime(for date: Date) -> String {
        let todayStart = startOfToday()
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        if date >= todayStart {
            return "Hoy, \(formatTime(date))"
        }
        if date >= yesterdayStart {
            return "Ayer, \(formatTime(date))"
        }
        return formatDateTime(date)
    }
}
