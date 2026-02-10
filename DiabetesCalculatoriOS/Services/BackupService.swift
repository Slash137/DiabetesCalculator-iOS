import Foundation

enum BackupService {
    static func encodeBackup(data: AppDataStore) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(data)
    }

    static func decodeBackup(from data: Data) throws -> AppDataStore {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(AppDataStore.self, from: data)
    }

    static func exportCSV(data store: AppDataStore) -> Data {
        var lines: [String] = []
        lines.append(
            [
                "registro_id",
                "fecha",
                "alimento",
                "gramos_consumidos",
                "hidratos_item",
                "hidratos_totales",
                "raciones_totales",
                "insulina_total",
                "ratio_u_g",
                "glucosa_antes",
                "glucosa_despues_2h",
                "dosis_estado",
                "dosis_confirmada_at",
                "notas"
            ].joined(separator: ";")
        )

        let foodsByID = Dictionary(uniqueKeysWithValues: store.foods.map { ($0.id, $0) })
        let itemsByMeal = Dictionary(grouping: store.mealItems, by: \ .mealID)

        for meal in store.meals.sorted(by: { $0.date > $1.date }) {
            let mealID = meal.id
            let formattedDate = DateUtils.formatDateTime(meal.date)
            let ratio = meal.ratioInsulinPerGram ?? (meal.totalCarbs > 0 ? meal.insulinUnits / meal.totalCarbs : 0)
            let confirmedAt = meal.doseConfirmedAt.map(DateUtils.formatDateTime) ?? ""
            let mealItems = itemsByMeal[mealID] ?? []

            if mealItems.isEmpty {
                let row = [
                    mealID.uuidString,
                    formattedDate,
                    "",
                    "",
                    "",
                    formatFloat(meal.totalCarbs),
                    formatFloat(meal.rations),
                    formatFloat(meal.insulinUnits),
                    formatFloat(ratio),
                    meal.glucoseBeforeMgdl.map(String.init) ?? "",
                    meal.glucoseAfter2hMgdl.map(String.init) ?? "",
                    meal.doseStatus.rawValue,
                    confirmedAt,
                    meal.notes ?? ""
                ]
                lines.append(row.map(escapeCSV).joined(separator: ";"))
            } else {
                for item in mealItems {
                    let foodName = foodsByID[item.foodID]?.name ?? "Desconocido"
                    let row = [
                        mealID.uuidString,
                        formattedDate,
                        foodName,
                        formatFloat(item.gramsConsumed),
                        formatFloat(item.carbsCalculated),
                        formatFloat(meal.totalCarbs),
                        formatFloat(meal.rations),
                        formatFloat(meal.insulinUnits),
                        formatFloat(ratio),
                        meal.glucoseBeforeMgdl.map(String.init) ?? "",
                        meal.glucoseAfter2hMgdl.map(String.init) ?? "",
                        meal.doseStatus.rawValue,
                        confirmedAt,
                        meal.notes ?? ""
                    ]
                    lines.append(row.map(escapeCSV).joined(separator: ";"))
                }
            }
        }

        let csvString = "\u{FEFF}" + lines.joined(separator: "\n")
        return Data(csvString.utf8)
    }

    static func backupDirectory(baseDirectory: URL) -> URL {
        baseDirectory.appendingPathComponent("backups", isDirectory: true)
    }

    static func createAutoBackupIfNeeded(data: AppDataStore, baseDirectory: URL) {
        let backupDirectoryURL = backupDirectory(baseDirectory: baseDirectory)
        try? FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)

        let now = Date()
        if let latest = latestBackupURL(baseDirectory: baseDirectory),
           let attributes = try? FileManager.default.attributesOfItem(atPath: latest.path),
           let modified = attributes[.modificationDate] as? Date,
           now.timeIntervalSince(modified) < 20 * 60 * 60 {
            return
        }

        guard let payload = try? encodeBackup(data: data) else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let fileName = "auto_backup_\(formatter.string(from: now)).json"
        let fileURL = backupDirectoryURL.appendingPathComponent(fileName)

        do {
            try payload.write(to: fileURL, options: [.atomic])
            cleanupBackups(in: backupDirectoryURL, keep: 7)
        } catch {
            // Ignorar errores de respaldo automatico
        }
    }

    static func latestBackupURL(baseDirectory: URL) -> URL? {
        let backupDirectoryURL = backupDirectory(baseDirectory: baseDirectory)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .filter { $0.lastPathComponent.hasPrefix("auto_backup_") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .first
    }

    private static func cleanupBackups(in folder: URL, keep: Int) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let sorted = urls
            .filter { $0.lastPathComponent.hasPrefix("auto_backup_") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        if sorted.count <= keep {
            return
        }

        for file in sorted.dropFirst(keep) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func formatFloat(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "es_ES"), value)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
