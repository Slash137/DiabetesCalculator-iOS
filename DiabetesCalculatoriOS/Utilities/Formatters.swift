import Foundation

enum AppFormatters {
    static let decimalOne: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let decimalTwo: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func one(_ value: Double) -> String {
        decimalOne.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    static func two(_ value: Double) -> String {
        decimalTwo.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

extension String {
    var parsedDecimal: Double? {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
