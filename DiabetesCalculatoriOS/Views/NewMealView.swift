import SwiftUI

struct NewMealView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedTab: AppTab

    @State private var draftItems: [MealDraftItem] = [MealDraftItem()]
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var toastMessage: String?

    @State private var showTemplates = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""

    var body: some View {
        Group {
            if store.profile == nil {
                noProfileView
            } else {
                contentView
            }
        }
        .animation(.default, value: store.profile != nil)
        .sheet(isPresented: $showTemplates) {
            NavigationStack {
                templatesSheet
            }
        }
        .alert("Guardar plantilla", isPresented: $showSaveTemplate) {
            TextField("Nombre de plantilla", text: $templateName)
            Button("Cancelar", role: .cancel) {
                templateName = ""
            }
            Button("Guardar") {
                do {
                    try store.saveTemplate(name: templateName, draftItems: draftItems)
                    toastMessage = "Plantilla guardada"
                    templateName = ""
                } catch {
                    toastMessage = error.localizedDescription
                }
            }
        } message: {
            Text("Guarda esta combinacion para reutilizarla en otra comida")
        }
        .alert("Aviso", isPresented: Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(toastMessage ?? "")
        }
        .onAppear {
            store.refreshNightscoutNow()
        }
    }

    private var noProfileView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MedicalNoticeView()

                ContentUnavailableView(
                    "Configura tu perfil",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Necesitas gramos por racion y ratio de insulina para calcular la comida.")
                )

                Button("Ir a Perfil") {
                    selectedTab = .profile
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                NightscoutHeaderView()

                templateButtons

                VStack(spacing: 12) {
                    ForEach($draftItems) { $item in
                        DraftMealItemRow(
                            item: $item,
                            foods: store.foods,
                            onDelete: {
                                removeItem(item.id)
                            },
                            canDelete: draftItems.count > 1
                        )
                    }
                }

                Button {
                    draftItems.append(MealDraftItem())
                } label: {
                    Label("Anadir alimento", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notas")
                        .font(.headline)
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                        .padding(4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                summarySection

                Button {
                    saveMeal()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Guardar comida")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canSaveMeal(draftItems: draftItems) || isSaving)

                MedicalNoticeView()
            }
            .padding()
        }
    }

    private var templateButtons: some View {
        HStack(spacing: 10) {
            Button {
                showTemplates = true
            } label: {
                Label("Plantillas", systemImage: "rectangle.stack")
            }
            .buttonStyle(.bordered)

            Button {
                templateName = ""
                showSaveTemplate = true
            } label: {
                Label("Guardar plantilla", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        let calc = store.calculation(for: draftItems)
        return VStack(spacing: 10) {
            summaryRow(title: "Hidratos", value: "\(AppFormatters.one(calc.totalCarbs)) g")
            summaryRow(title: "Raciones", value: AppFormatters.one(calc.rations))
            summaryRow(title: "Insulina", value: "\(AppFormatters.one(calc.insulinUnits)) U")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private var templatesSheet: some View {
        List {
            if store.templates.isEmpty {
                ContentUnavailableView(
                    "Sin plantillas",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Guarda una comida como plantilla para reutilizarla.")
                )
            } else {
                ForEach(store.templates) { template in
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            draftItems = store.applyTemplate(template)
                            showTemplates = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(DateUtils.formatDateTime(template.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        let items = store.templateItemsWithFood(for: template.id)
                        if !items.isEmpty {
                            Text(items.map { item, food in
                                "\(food?.name ?? "Desconocido") (\(AppFormatters.one(item.grams)) g)"
                            }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Eliminar", role: .destructive) {
                            store.deleteTemplate(template)
                        }
                    }
                }
            }
        }
        .navigationTitle("Plantillas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cerrar") {
                    showTemplates = false
                }
            }
        }
    }

    private func removeItem(_ id: UUID) {
        guard draftItems.count > 1 else { return }
        draftItems.removeAll { $0.id == id }
    }

    private func saveMeal() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let result = try await store.saveMeal(draftItems: draftItems, notes: notes)
                draftItems = [MealDraftItem()]
                notes = ""
                toastMessage = result.alertMessage ?? "Comida guardada"
            } catch {
                toastMessage = error.localizedDescription
            }
        }
    }
}

private struct DraftMealItemRow: View {
    @Binding var item: MealDraftItem
    let foods: [FoodEntry]
    let onDelete: () -> Void
    let canDelete: Bool

    private var selectedFood: FoodEntry? {
        guard let id = item.foodID else { return nil }
        return foods.first { $0.id == id }
    }

    private var carbsText: String {
        guard let food = selectedFood else { return "0 g" }
        let carbs = InsulinCalculator.calculateCarbs(carbsPer100g: food.carbsPer100g, gramsConsumed: item.gramsValue)
        return "\(AppFormatters.one(carbs)) g"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Alimento")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                }
            }

            Picker("Selecciona", selection: $item.foodID) {
                Text("Selecciona...").tag(Optional<UUID>.none)
                ForEach(foods) { food in
                    Text("\(food.name) (\(AppFormatters.one(food.carbsPer100g)) g/100g)")
                        .tag(Optional(food.id))
                }
            }
            .pickerStyle(.menu)

            TextField("Gramos", text: Binding(
                get: { item.gramsText },
                set: { newValue in
                    if newValue.isEmpty || newValue.range(of: "^\\d*([\\.,]\\d*)?$", options: .regularExpression) != nil {
                        item.gramsText = newValue
                    }
                }
            ))
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)

            HStack {
                Text("Hidratos calculados")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(carbsText)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
