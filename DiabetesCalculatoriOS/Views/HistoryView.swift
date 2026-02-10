import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    @State private var searchQuery = ""
    @State private var dayFilter: HistoryDayFilter = .all
    @State private var doseFilter: HistoryDoseStatusFilter = .all

    @State private var templateMealID: UUID?
    @State private var templateName = ""
    @State private var message: String?

    private var filteredMeals: [MealRecord] {
        store.mealsFiltered(query: searchQuery, dayFilter: dayFilter, doseFilter: doseFilter)
    }

    private var groupedMeals: [(String, [MealRecord])] {
        let grouped = Dictionary(grouping: filteredMeals) { meal in
            DateUtils.relativeDayLabel(for: meal.date)
        }

        return grouped
            .sorted { lhs, rhs in
                let leftDate = lhs.value.first?.date ?? .distantPast
                let rightDate = rhs.value.first?.date ?? .distantPast
                return leftDate > rightDate
            }
            .map { key, value in
                (key, value.sorted { $0.date > $1.date })
            }
    }

    var body: some View {
        List {
            filterSection

            if groupedMeals.isEmpty {
                ContentUnavailableView(
                    "Sin registros",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(searchQuery.isEmpty ? "Guarda una comida para empezar" : "No hay resultados con estos filtros")
                )
            } else {
                ForEach(groupedMeals, id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1) { meal in
                            MealHistoryRow(meal: meal)
                                .swipeActions(edge: .trailing) {
                                    Button("Eliminar", role: .destructive) {
                                        store.deleteMeal(meal)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Menu {
                                        ForEach(DoseStatus.allCases) { status in
                                            Button(status.label) {
                                                store.updateDoseStatus(meal: meal, status: status)
                                            }
                                        }
                                    } label: {
                                        Label("Dosis", systemImage: "syringe")
                                    }
                                    .tint(.blue)

                                    Button {
                                        templateMealID = meal.id
                                        templateName = "Plantilla \(DateUtils.formatDateTime(meal.date))"
                                    } label: {
                                        Label("Plantilla", systemImage: "rectangle.stack.badge.plus")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                }
            }

            MedicalNoticeView()
                .listRowSeparator(.hidden)
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchQuery, prompt: "Buscar por alimento o nota")
        .alert("Crear plantilla", isPresented: Binding(
            get: { templateMealID != nil },
            set: { newValue in
                if !newValue {
                    templateMealID = nil
                }
            }
        )) {
            TextField("Nombre", text: $templateName)
            Button("Cancelar", role: .cancel) {
                templateMealID = nil
            }
            Button("Guardar") {
                guard let mealID = templateMealID else { return }
                do {
                    try store.createTemplateFromMeal(mealID: mealID, name: templateName)
                    message = "Plantilla creada"
                } catch {
                    message = error.localizedDescription
                }
                templateMealID = nil
            }
        } message: {
            Text("Se guardaran los mismos alimentos y gramos de esta comida")
        }
        .alert("Aviso", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var filterSection: some View {
        Section {
            Picker("Periodo", selection: $dayFilter) {
                ForEach(HistoryDayFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Dosis", selection: $doseFilter) {
                ForEach(HistoryDoseStatusFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

private struct MealHistoryRow: View {
    @EnvironmentObject private var store: AppStore
    let meal: MealRecord

    private var itemsWithFood: [(MealItemRecord, FoodEntry?)] {
        store.mealItemsWithFood(for: meal.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateUtils.relativeDateTime(for: meal.date))
                        .font(.headline)
                    Text("\(AppFormatters.one(meal.totalCarbs)) g HC · \(AppFormatters.one(meal.rations)) raciones · \(AppFormatters.one(meal.insulinUnits)) U")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                DoseStatusBadge(status: meal.doseStatus)
            }

            if !itemsWithFood.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(itemsWithFood, id: \.0.id) { item, food in
                        Text("• \(food?.name ?? "Desconocido"): \(AppFormatters.one(item.gramsConsumed)) g (\(AppFormatters.one(item.carbsCalculated)) g HC)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 14) {
                Label(meal.glucoseBeforeMgdl.map { "\($0) mg/dL" } ?? "—", systemImage: "drop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(meal.glucoseAfter2hMgdl.map { "\($0) mg/dL" } ?? "Pendiente", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = meal.notes, !notes.isEmpty {
                Text(notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if meal.doseStatus == .applied, let confirmed = meal.doseConfirmedAt {
                Text("Confirmada \(DateUtils.formatTime(confirmed))")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DoseStatusBadge: View {
    let status: DoseStatus

    private var color: Color {
        switch status {
        case .pending:
            return .orange
        case .applied:
            return .green
        case .skipped:
            return .gray
        }
    }

    private var icon: String {
        switch status {
        case .pending:
            return "hourglass"
        case .applied:
            return "checkmark.circle"
        case .skipped:
            return "minus.circle"
        }
    }

    var body: some View {
        Label(status.label, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
