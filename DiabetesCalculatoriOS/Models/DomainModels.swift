import Foundation

enum DoseStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case applied
    case skipped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending:
            return "Pendiente"
        case .applied:
            return "Aplicada"
        case .skipped:
            return "No aplicada"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var id: Int = 1
    var name: String
    var gramsPerRation: Double
    var insulinRatio: Double
    var dailyCarbsGoal: Double?
    var dailyRationsGoal: Double?
    var dailyInsulinGoal: Double?
    var reminder2hEnabled: Bool
    var nightscoutURL: String?
    var nightscoutToken: String?
    var createdAt: Date

    static let `default` = UserProfile(
        name: "",
        gramsPerRation: 10,
        insulinRatio: 1,
        dailyCarbsGoal: nil,
        dailyRationsGoal: nil,
        dailyInsulinGoal: nil,
        reminder2hEnabled: false,
        nightscoutURL: nil,
        nightscoutToken: nil,
        createdAt: Date()
    )
}

struct FoodEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var carbsPer100g: Double
    var source: String
    var note: String?

    init(
        id: UUID = UUID(),
        name: String,
        carbsPer100g: Double,
        source: String,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.carbsPer100g = carbsPer100g
        self.source = source
        self.note = note
    }
}

struct MealRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var totalCarbs: Double
    var rations: Double
    var insulinUnits: Double
    var ratioInsulinPerGram: Double?
    var date: Date
    var notes: String?
    var glucoseBeforeMgdl: Int?
    var glucoseAfter2hMgdl: Int?
    var doseStatus: DoseStatus
    var doseConfirmedAt: Date?

    init(
        id: UUID = UUID(),
        totalCarbs: Double,
        rations: Double,
        insulinUnits: Double,
        ratioInsulinPerGram: Double?,
        date: Date = Date(),
        notes: String? = nil,
        glucoseBeforeMgdl: Int? = nil,
        glucoseAfter2hMgdl: Int? = nil,
        doseStatus: DoseStatus = .pending,
        doseConfirmedAt: Date? = nil
    ) {
        self.id = id
        self.totalCarbs = totalCarbs
        self.rations = rations
        self.insulinUnits = insulinUnits
        self.ratioInsulinPerGram = ratioInsulinPerGram
        self.date = date
        self.notes = notes
        self.glucoseBeforeMgdl = glucoseBeforeMgdl
        self.glucoseAfter2hMgdl = glucoseAfter2hMgdl
        self.doseStatus = doseStatus
        self.doseConfirmedAt = doseConfirmedAt
    }
}

struct MealItemRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var mealID: UUID
    var foodID: UUID
    var gramsConsumed: Double
    var carbsCalculated: Double

    init(
        id: UUID = UUID(),
        mealID: UUID,
        foodID: UUID,
        gramsConsumed: Double,
        carbsCalculated: Double
    ) {
        self.id = id
        self.mealID = mealID
        self.foodID = foodID
        self.gramsConsumed = gramsConsumed
        self.carbsCalculated = carbsCalculated
    }
}

struct MealTemplate: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct MealTemplateItem: Codable, Identifiable, Equatable {
    var id: UUID
    var templateID: UUID
    var foodID: UUID
    var grams: Double

    init(id: UUID = UUID(), templateID: UUID, foodID: UUID, grams: Double) {
        self.id = id
        self.templateID = templateID
        self.foodID = foodID
        self.grams = grams
    }
}

struct PendingGlucoseTask: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case before = "ANTES"
        case after2h = "DESPUES_2H"
    }

    var id: UUID
    var mealID: UUID
    var kind: Kind
    var targetDate: Date
    var createdAt: Date
    var attempts: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        mealID: UUID,
        kind: Kind,
        targetDate: Date,
        createdAt: Date = Date(),
        attempts: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.mealID = mealID
        self.kind = kind
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastError = lastError
    }
}

struct AppDataStore: Codable {
    var schemaVersion: Int = 1
    var profile: UserProfile?
    var foods: [FoodEntry]
    var meals: [MealRecord]
    var mealItems: [MealItemRecord]
    var templates: [MealTemplate]
    var templateItems: [MealTemplateItem]
    var pendingGlucose: [PendingGlucoseTask]

    static let empty = AppDataStore(
        profile: nil,
        foods: [],
        meals: [],
        mealItems: [],
        templates: [],
        templateItems: [],
        pendingGlucose: []
    )
}

struct MealDraftItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var foodID: UUID?
    var gramsText: String = ""

    var gramsValue: Double {
        Self.parseDecimal(gramsText) ?? 0
    }

    static func parseDecimal(_ value: String) -> Double? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

struct CurrentCalculation: Equatable {
    var totalCarbs: Double = 0
    var rations: Double = 0
    var insulinUnits: Double = 0
}

struct SaveMealResult {
    var alertMessage: String?
}

enum HistoryDayFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case yesterday
    case last7Days
    case last30Days

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "Todos"
        case .today:
            return "Hoy"
        case .yesterday:
            return "Ayer"
        case .last7Days:
            return "7 dias"
        case .last30Days:
            return "30 dias"
        }
    }
}

enum HistoryDoseStatusFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case applied
    case skipped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendiente"
        case .applied:
            return "Aplicada"
        case .skipped:
            return "No aplicada"
        }
    }

    var value: DoseStatus? {
        switch self {
        case .all:
            return nil
        case .pending:
            return .pending
        case .applied:
            return .applied
        case .skipped:
            return .skipped
        }
    }
}
