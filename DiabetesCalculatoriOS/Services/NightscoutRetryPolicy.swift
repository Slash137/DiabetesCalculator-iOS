import Foundation

enum NightscoutRetryPolicy {
    static let maxAttempts = 6
    static let baseDelayMinutes: Int = 10
    static let maxDelayMinutes: Int = 360

    static func nextDelayMinutes(for attempts: Int) -> Int {
        let clamped = max(0, attempts)
        let factor = 1 << min(clamped, 10)
        let delay = baseDelayMinutes * factor
        return min(delay, maxDelayMinutes)
    }
}
