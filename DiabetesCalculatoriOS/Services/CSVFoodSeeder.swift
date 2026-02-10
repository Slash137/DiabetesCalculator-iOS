import Foundation

enum CSVFoodSeeder {
    static func loadFoodsFromBundle() -> [FoodEntry] {
        guard let url = Bundle.main.url(forResource: "alimentos_librito", withExtension: "csv") else {
            return []
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let rows = parseCSV(content)
        guard rows.count > 1 else { return [] }

        return rows.dropFirst().compactMap { columns in
            guard columns.count >= 4 else { return nil }
            let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let carbsRaw = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            let source = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let note = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty, let carbs = Double(carbsRaw) else { return nil }
            return FoodEntry(name: name, carbsPer100g: carbs, source: source, note: note.isEmpty ? nil : note)
        }
    }

    static func mergeSeedData(existing: [FoodEntry], seed: [FoodEntry]) -> [FoodEntry] {
        guard !seed.isEmpty else { return existing }

        if existing.isEmpty {
            return seed.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        var indexedByName = Dictionary(uniqueKeysWithValues: existing.map { ($0.name.lowercased(), $0) })
        for food in seed {
            let key = food.name.lowercased()
            if var existingFood = indexedByName[key] {
                existingFood.carbsPer100g = food.carbsPer100g
                existingFood.source = food.source
                existingFood.note = food.note
                indexedByName[key] = existingFood
            } else {
                indexedByName[key] = food
            }
        }

        return indexedByName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let char = normalized[index]

            if char == "\"" {
                let next = normalized.index(after: index)
                if insideQuotes, next < normalized.endIndex, normalized[next] == "\"" {
                    currentField.append("\"")
                    index = next
                } else {
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if char == "\n" && !insideQuotes {
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }

            index = normalized.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
