import SwiftUI

struct FoodsView: View {
    @EnvironmentObject private var store: AppStore

    @State private var searchQuery = ""
    @State private var showEditor = false
    @State private var editingFood: FoodEntry?

    var body: some View {
        List {
            ForEach(store.foodsFiltered(query: searchQuery)) { food in
                VStack(alignment: .leading, spacing: 6) {
                    Text(food.name)
                        .font(.headline)

                    Text("\(AppFormatters.one(food.carbsPer100g)) g HC por 100 g")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(food.source)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())

                        if let note = food.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingFood = food
                    showEditor = true
                }
                .swipeActions {
                    Button("Eliminar", role: .destructive) {
                        store.deleteFood(food)
                    }
                }
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar alimento")
        .overlay {
            if store.foodsFiltered(query: searchQuery).isEmpty {
                ContentUnavailableView(
                    "Sin alimentos",
                    systemImage: "fork.knife",
                    description: Text("Agrega un alimento para empezar")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingFood = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                FoodEditorView(foodToEdit: editingFood) { saved in
                    store.upsertFood(saved)
                }
            }
        }
    }
}

private struct FoodEditorView: View {
    let foodToEdit: FoodEntry?
    let onSave: (FoodEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var carbs: String
    @State private var source: String
    @State private var note: String

    init(foodToEdit: FoodEntry?, onSave: @escaping (FoodEntry) -> Void) {
        self.foodToEdit = foodToEdit
        self.onSave = onSave

        _name = State(initialValue: foodToEdit?.name ?? "")
        _carbs = State(initialValue: foodToEdit.map { AppFormatters.one($0.carbsPer100g) } ?? "")
        _source = State(initialValue: foodToEdit?.source ?? "personal")
        _note = State(initialValue: foodToEdit?.note ?? "")
    }

    var body: some View {
        Form {
            Section("Datos") {
                TextField("Nombre", text: $name)
                TextField("Hidratos por 100g", text: Binding(
                    get: { carbs },
                    set: { newValue in
                        if newValue.isEmpty || newValue.range(of: "^\\d*([\\.,]\\d*)?$", options: .regularExpression) != nil {
                            carbs = newValue
                        }
                    }
                ))
                .keyboardType(.decimalPad)

                TextField("Fuente", text: $source)
                TextField("Nota (opcional)", text: $note, axis: .vertical)
            }
        }
        .navigationTitle(foodToEdit == nil ? "Nuevo alimento" : "Editar alimento")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    guard let carbsValue = carbs.parsedDecimal,
                          carbsValue >= 0,
                          !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return
                    }

                    let item = FoodEntry(
                        id: foodToEdit?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        carbsPer100g: carbsValue,
                        source: source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "personal"
                            : source.trimmingCharacters(in: .whitespacesAndNewlines),
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : note.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    onSave(item)
                    dismiss()
                }
            }
        }
    }
}
