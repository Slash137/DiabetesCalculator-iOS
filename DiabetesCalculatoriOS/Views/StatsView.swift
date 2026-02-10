import SwiftUI

enum StatsPeriod: String, CaseIterable, Identifiable {
    case all
    case last7
    case last30
    case last90

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "Todo"
        case .last7:
            return "7d"
        case .last30:
            return "30d"
        case .last90:
            return "90d"
        }
    }

    var days: Int? {
        switch self {
        case .all:
            return nil
        case .last7:
            return 7
        case .last30:
            return 30
        case .last90:
            return 90
        }
    }
}

struct StatsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var period: StatsPeriod = .last30

    private var meals: [MealRecord] {
        let all = store.meals
        guard let days = period.days else { return all }

        let daySeconds: TimeInterval = 24 * 60 * 60
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(-(days - 1)) * daySeconds)
        let end = DateUtils.endOfToday()
        return all.filter { $0.date >= start && $0.date <= end }
    }

    private var summary: StatsSummary {
        StatsSummary(meals: meals, mealItems: store.data.mealItems, foods: store.data.foods)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Periodo", selection: $period) {
                    ForEach(StatsPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                if meals.isEmpty {
                    ContentUnavailableView(
                        "Sin datos",
                        systemImage: "chart.bar.xaxis",
                        description: Text("No hay registros en el periodo seleccionado")
                    )
                } else {
                    statsCard(title: "Resumen") {
                        statRow("Comidas", value: "\(summary.totalMeals)")
                        statRow("Dias con registros", value: "\(summary.daysWithMeals)")
                        statRow("Hidratos totales", value: "\(AppFormatters.one(summary.totalCarbs)) g")
                        statRow("Raciones totales", value: AppFormatters.one(summary.totalRations))
                        statRow("Insulina total", value: "\(AppFormatters.one(summary.totalInsulin)) U")
                        statRow("Comidas por dia", value: AppFormatters.two(summary.mealsPerDay))
                    }

                    statsCard(title: "Promedios") {
                        statRow("Hidratos/comida", value: "\(AppFormatters.one(summary.carbsPerMeal)) g")
                        statRow("Raciones/comida", value: AppFormatters.one(summary.rationsPerMeal))
                        statRow("Insulina/comida", value: "\(AppFormatters.one(summary.insulinPerMeal)) U")
                        statRow("Ratio efectivo U/racion", value: summary.effectiveURationRatio.map(AppFormatters.two) ?? "N/D")
                        statRow("Ratio efectivo U/g", value: summary.effectiveUGRatio.map(AppFormatters.three) ?? "N/D")
                    }

                    statsCard(title: "Glucosa") {
                        statRow("Media antes", value: summary.avgGlucoseBefore.map { "\(AppFormatters.one($0)) mg/dL" } ?? "N/D")
                        statRow("Media 2h", value: summary.avgGlucoseAfter2h.map { "\(AppFormatters.one($0)) mg/dL" } ?? "N/D")
                        statRow("Delta medio 2h", value: summary.avgDelta2h.map { "\(AppFormatters.one($0)) mg/dL" } ?? "N/D")
                        statRow("2h en rango (80-180)", value: summary.inRange2hPct.map { "\(AppFormatters.one($0))%" } ?? "N/D")
                    }

                    if !summary.topFoods.isEmpty {
                        statsCard(title: "Top alimentos") {
                            ForEach(summary.topFoods, id: \.name) { food in
                                statRow(food.name, value: "\(food.uses) usos · \(AppFormatters.one(food.carbs)) g HC")
                            }
                        }
                    }
                }

                MedicalNoticeView()
            }
            .padding()
        }
    }

    private func statsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func statRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

private struct StatsSummary {
    struct TopFood {
        let name: String
        let uses: Int
        let carbs: Double
    }

    let totalMeals: Int
    let daysWithMeals: Int
    let totalCarbs: Double
    let totalRations: Double
    let totalInsulin: Double
    let mealsPerDay: Double
    let carbsPerMeal: Double
    let rationsPerMeal: Double
    let insulinPerMeal: Double
    let effectiveURationRatio: Double?
    let effectiveUGRatio: Double?
    let avgGlucoseBefore: Double?
    let avgGlucoseAfter2h: Double?
    let avgDelta2h: Double?
    let inRange2hPct: Double?
    let topFoods: [TopFood]

    init(meals: [MealRecord], mealItems: [MealItemRecord], foods: [FoodEntry]) {
        totalMeals = meals.count
        let dayStarts = Set(meals.map { DateUtils.startOfDay($0.date) })
        daysWithMeals = max(dayStarts.count, 1)

        totalCarbs = meals.reduce(0) { $0 + $1.totalCarbs }
        totalRations = meals.reduce(0) { $0 + $1.rations }
        totalInsulin = meals.reduce(0) { $0 + $1.insulinUnits }

        mealsPerDay = totalMeals > 0 ? Double(totalMeals) / Double(daysWithMeals) : 0
        carbsPerMeal = totalMeals > 0 ? totalCarbs / Double(totalMeals) : 0
        rationsPerMeal = totalMeals > 0 ? totalRations / Double(totalMeals) : 0
        insulinPerMeal = totalMeals > 0 ? totalInsulin / Double(totalMeals) : 0

        effectiveURationRatio = totalRations > 0 ? totalInsulin / totalRations : nil
        effectiveUGRatio = totalCarbs > 0 ? totalInsulin / totalCarbs : nil

        let beforeValues = meals.compactMap { $0.glucoseBeforeMgdl.map(Double.init) }
        let afterValues = meals.compactMap { $0.glucoseAfter2hMgdl.map(Double.init) }

        avgGlucoseBefore = beforeValues.isEmpty ? nil : beforeValues.reduce(0, +) / Double(beforeValues.count)
        avgGlucoseAfter2h = afterValues.isEmpty ? nil : afterValues.reduce(0, +) / Double(afterValues.count)

        let deltas = meals.compactMap { meal -> Double? in
            guard let before = meal.glucoseBeforeMgdl, let after = meal.glucoseAfter2hMgdl else {
                return nil
            }
            return Double(after - before)
        }
        avgDelta2h = deltas.isEmpty ? nil : deltas.reduce(0, +) / Double(deltas.count)

        if !afterValues.isEmpty {
            let inRange = afterValues.filter { $0 >= 80 && $0 <= 180 }.count
            inRange2hPct = (Double(inRange) / Double(afterValues.count)) * 100
        } else {
            inRange2hPct = nil
        }

        let foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        let mealIDs = Set(meals.map(\.id))
        let filteredItems = mealItems.filter { mealIDs.contains($0.mealID) }

        let groupedByFood = Dictionary(grouping: filteredItems, by: \.foodID)
        topFoods = groupedByFood.compactMap { foodID, items in
            guard let food = foodsByID[foodID] else { return nil }
            let carbs = items.reduce(0) { $0 + $1.carbsCalculated }
            return TopFood(name: food.name, uses: items.count, carbs: carbs)
        }
        .sorted { lhs, rhs in
            if lhs.uses == rhs.uses {
                return lhs.carbs > rhs.carbs
            }
            return lhs.uses > rhs.uses
        }
        .prefix(5)
        .map { $0 }
    }
}

private extension AppFormatters {
    static func three(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "es_ES"), value)
    }
}
