import Foundation

struct NightscoutEntry: Codable, Equatable {
    let id: String?
    let sgv: Int
    let date: Double
    let dateString: String?
    let direction: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case sgv
        case date
        case dateString
        case direction
        case type
    }
}

enum NightscoutGlucoseState: Equatable {
    case idle
    case loading
    case success(NightscoutEntry)
    case error(String)
}

struct NightscoutStatus: Equatable {
    var lastSuccessAt: Date?
    var lastErrorAt: Date?
    var lastErrorMessage: String?
    var consecutiveFailures: Int = 0
}

enum NightscoutService {
    static func latestGlucose(baseURL: String, token: String?) async -> NightscoutEntry? {
        let normalized = normalizeURL(baseURL)
        guard let url = URL(string: "\(normalized)api/v1/entries/sgv.json") else {
            return nil
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = [URLQueryItem(name: "count", value: "1")]
        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            return nil
        }

        var request = URLRequest(url: finalURL)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                return nil
            }
            let entries = try JSONDecoder().decode([NightscoutEntry].self, from: data)
            return entries.first
        } catch {
            return nil
        }
    }

    static func trendArrow(_ direction: String?) -> String {
        switch direction {
        case "TripleUp":
            return "⇈"
        case "DoubleUp":
            return "↑↑"
        case "SingleUp":
            return "↑"
        case "FortyFiveUp":
            return "↗"
        case "Flat":
            return "→"
        case "FortyFiveDown":
            return "↘"
        case "SingleDown":
            return "↓"
        case "DoubleDown":
            return "↓↓"
        case "TripleDown":
            return "⇊"
        default:
            return ""
        }
    }

    private static func normalizeURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.hasSuffix("/") ? trimmed : "\(trimmed)/"
    }
}
