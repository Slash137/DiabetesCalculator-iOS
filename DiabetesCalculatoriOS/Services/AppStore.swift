import Foundation

@MainActor
final class AppStore: ObservableObject {
    enum AppStoreError: LocalizedError {
        case profileMissing
        case invalidData(String)
        case ioFailure(String)

        var errorDescription: String? {
            switch self {
            case .profileMissing:
                return "Configura tu perfil antes de guardar comidas"
            case .invalidData(let message):
                return message
            case .ioFailure(let message):
                return message
            }
        }
    }

    @Published private(set) var data: AppDataStore = .empty
    @Published var nightscoutState: NightscoutGlucoseState = .idle
    @Published var nightscoutStatus: NightscoutStatus = NightscoutStatus()

    private let baseDirectory: URL
    private let dataFileURL: URL
    private var nightscoutTask: Task<Void, Never>?

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appDirectory = appSupport.appendingPathComponent("DiabetesCalculatoriOS", isDirectory: true)
        self.baseDirectory = appDirectory
        self.dataFileURL = appDirectory.appendingPathComponent("data.json")

        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        } catch {
            // Continuar con almacenamiento temporal
        }

        load()
        seedFoodsIfNeeded()
        NotificationScheduler.requestAuthorizationIfNeeded()
        startNightscoutPolling()
    }

    deinit {
        nightscoutTask?.cancel()
    }

    var profile: UserProfile? {
        data.profile
    }

    var foods: [FoodEntry] {
        data.foods.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var meals: [MealRecord] {
        data.meals.sorted { $0.date > $1.date }
    }

    var templates: [MealTemplate] {
        data.templates.sorted { $0.createdAt > $1.createdAt }
    }

    var pendingGlucoseTasks: [PendingGlucoseTask] {
        data.pendingGlucose.sorted { $0.createdAt < $1.createdAt }
    }

    var pendingMaxAttempts: Int {
        pendingGlucoseTasks.map(\.attempts).max() ?? 0
    }

    func restartNightscoutPolling() {
        startNightscoutPolling()
    }

    func foodsFiltered(query: String) -> [FoodEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return foods
        }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(normalized) }
    }

    func food(by id: UUID) -> FoodEntry? {
        data.foods.first { $0.id == id }
    }

    func mealItems(for mealID: UUID) -> [MealItemRecord] {
        data.mealItems.filter { $0.mealID == mealID }
    }

    func mealItemsWithFood(for mealID: UUID) -> [(MealItemRecord, FoodEntry?)] {
        let foodsByID = Dictionary(uniqueKeysWithValues: data.foods.map { ($0.id, $0) })
        return mealItems(for: mealID)
            .sorted { lhs, rhs in
                let leftName = foodsByID[lhs.foodID]?.name ?? ""
                let rightName = foodsByID[rhs.foodID]?.name ?? ""
                return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
            }
            .map { ($0, foodsByID[$0.foodID]) }
    }

    func templateItems(for templateID: UUID) -> [MealTemplateItem] {
        data.templateItems.filter { $0.templateID == templateID }
    }

    func templateItemsWithFood(for templateID: UUID) -> [(MealTemplateItem, FoodEntry?)] {
        let foodsByID = Dictionary(uniqueKeysWithValues: data.foods.map { ($0.id, $0) })
        return templateItems(for: templateID)
            .map { ($0, foodsByID[$0.foodID]) }
    }

    func upsertFood(_ food: FoodEntry) {
        if let index = data.foods.firstIndex(where: { $0.id == food.id }) {
            data.foods[index] = food
        } else {
            data.foods.append(food)
        }
        data.foods.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
    }

    func deleteFood(_ food: FoodEntry) {
        data.foods.removeAll { $0.id == food.id }
        data.mealItems.removeAll { $0.foodID == food.id }
        data.templateItems.removeAll { $0.foodID == food.id }
        persist()
    }

    func saveProfile(_ profile: UserProfile) {
        data.profile = profile
        persist()
        startNightscoutPolling()
    }

    func calculation(for draftItems: [MealDraftItem]) -> CurrentCalculation {
        guard let profile else { return CurrentCalculation() }

        let totalCarbs = draftItems.reduce(into: 0.0) { partial, item in
            guard let foodID = item.foodID,
                  let food = food(by: foodID) else {
                return
            }
            let carbs = InsulinCalculator.calculateCarbs(
                carbsPer100g: food.carbsPer100g,
                gramsConsumed: item.gramsValue
            )
            partial += carbs
        }

        let rations = InsulinCalculator.calculateRations(
            totalCarbs: totalCarbs,
            gramsPerRation: profile.gramsPerRation
        )
        let insulin = InsulinCalculator.calculateInsulin(
            rations: rations,
            insulinRatio: profile.insulinRatio
        )

        return CurrentCalculation(totalCarbs: totalCarbs, rations: rations, insulinUnits: insulin)
    }

    func canSaveMeal(draftItems: [MealDraftItem]) -> Bool {
        guard profile != nil else { return false }
        return draftItems.contains {
            $0.foodID != nil && (($0.gramsValue.isFinite ? $0.gramsValue : 0) > 0)
        }
    }

    func saveMeal(draftItems: [MealDraftItem], notes: String) async throws -> SaveMealResult {
        guard let profile else {
            throw AppStoreError.profileMissing
        }

        let validItems = draftItems.compactMap { draft -> (FoodEntry, Double)? in
            guard let foodID = draft.foodID,
                  let food = food(by: foodID),
                  draft.gramsValue > 0 else {
                return nil
            }
            return (food, draft.gramsValue)
        }

        if validItems.isEmpty {
            throw AppStoreError.invalidData("Anade al menos un alimento valido")
        }

        let calculation = self.calculation(for: draftItems)
        if !calculation.totalCarbs.isFinite || !calculation.rations.isFinite || !calculation.insulinUnits.isFinite {
            throw AppStoreError.invalidData("Calculo invalido. Revisa los datos")
        }

        let mealDate = Date()
        var glucoseBefore: Int?
        var pendingBefore = false

        let hasNightscout = !(profile.nightscoutURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if hasNightscout, let url = profile.nightscoutURL {
            if let latest = await NightscoutService.latestGlucose(baseURL: url, token: profile.nightscoutToken) {
                glucoseBefore = latest.sgv
            } else {
                pendingBefore = true
            }
        }

        let ratioInsulinPerGram: Double? = profile.gramsPerRation > 0
            ? profile.insulinRatio / profile.gramsPerRation
            : nil

        let meal = MealRecord(
            totalCarbs: calculation.totalCarbs,
            rations: calculation.rations,
            insulinUnits: calculation.insulinUnits,
            ratioInsulinPerGram: ratioInsulinPerGram,
            date: mealDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            glucoseBeforeMgdl: glucoseBefore,
            glucoseAfter2hMgdl: nil,
            doseStatus: .pending,
            doseConfirmedAt: nil
        )

        let itemRecords = validItems.map { food, grams in
            let carbs = InsulinCalculator.calculateCarbs(carbsPer100g: food.carbsPer100g, gramsConsumed: grams)
            return MealItemRecord(
                mealID: meal.id,
                foodID: food.id,
                gramsConsumed: grams,
                carbsCalculated: carbs
            )
        }

        data.meals.append(meal)
        data.mealItems.append(contentsOf: itemRecords)

        if pendingBefore {
            data.pendingGlucose.append(
                PendingGlucoseTask(
                    mealID: meal.id,
                    kind: .before,
                    targetDate: mealDate
                )
            )
        }

        if profile.reminder2hEnabled {
            NotificationScheduler.schedule2hReminder(mealID: meal.id, mealDate: mealDate)
        }

        let alert = buildDailyGoalAlert(afterAdding: calculation)
        persist()
        return SaveMealResult(alertMessage: alert)
    }

    func deleteMeal(_ meal: MealRecord) {
        data.meals.removeAll { $0.id == meal.id }
        data.mealItems.removeAll { $0.mealID == meal.id }
        data.pendingGlucose.removeAll { $0.mealID == meal.id }
        persist()
    }

    func updateDoseStatus(meal: MealRecord, status: DoseStatus) {
        guard let index = data.meals.firstIndex(where: { $0.id == meal.id }) else {
            return
        }

        var updated = data.meals[index]
        updated.doseStatus = status
        updated.doseConfirmedAt = (status == .applied) ? Date() : nil
        data.meals[index] = updated
        persist()
    }

    func saveTemplate(name: String, draftItems: [MealDraftItem]) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            throw AppStoreError.invalidData("Introduce un nombre para la plantilla")
        }

        let validItems = draftItems.compactMap { draft -> MealTemplateItem? in
            guard let foodID = draft.foodID, draft.gramsValue > 0 else { return nil }
            return MealTemplateItem(templateID: UUID(), foodID: foodID, grams: draft.gramsValue)
        }

        if validItems.isEmpty {
            throw AppStoreError.invalidData("No hay alimentos validos para guardar")
        }

        let template = MealTemplate(name: cleanName)
        let templateItems = validItems.map {
            MealTemplateItem(templateID: template.id, foodID: $0.foodID, grams: $0.grams)
        }

        data.templates.append(template)
        data.templateItems.append(contentsOf: templateItems)
        persist()
    }

    func deleteTemplate(_ template: MealTemplate) {
        data.templates.removeAll { $0.id == template.id }
        data.templateItems.removeAll { $0.templateID == template.id }
        persist()
    }

    func applyTemplate(_ template: MealTemplate) -> [MealDraftItem] {
        let items = templateItems(for: template.id)
        guard !items.isEmpty else { return [MealDraftItem()] }

        return items.map { item in
            MealDraftItem(
                foodID: item.foodID,
                gramsText: formatGrams(item.grams)
            )
        }
    }

    func createTemplateFromMeal(mealID: UUID, name: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            throw AppStoreError.invalidData("Introduce un nombre para la plantilla")
        }

        let sourceItems = mealItems(for: mealID)
        if sourceItems.isEmpty {
            throw AppStoreError.invalidData("La comida no tiene alimentos")
        }

        let template = MealTemplate(name: cleanName)
        let templateItems = sourceItems.map {
            MealTemplateItem(templateID: template.id, foodID: $0.foodID, grams: $0.gramsConsumed)
        }

        data.templates.append(template)
        data.templateItems.append(contentsOf: templateItems)
        persist()
    }

    func mealsFiltered(
        query: String,
        dayFilter: HistoryDayFilter,
        doseFilter: HistoryDoseStatusFilter
    ) -> [MealRecord] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let foodsByID = Dictionary(uniqueKeysWithValues: data.foods.map { ($0.id, $0.name) })
        let itemsByMeal = Dictionary(grouping: data.mealItems, by: \.mealID)
        let calendar = Calendar.current

        return meals.filter { meal in
            if doseFilter != .all, meal.doseStatus != doseFilter.value {
                return false
            }

            if !matchesDayFilter(meal.date, dayFilter: dayFilter, calendar: calendar) {
                return false
            }

            if normalizedQuery.isEmpty {
                return true
            }

            if meal.notes?.localizedCaseInsensitiveContains(normalizedQuery) == true {
                return true
            }

            let names = (itemsByMeal[meal.id] ?? []).compactMap { foodsByID[$0.foodID] }
            return names.contains { $0.localizedCaseInsensitiveContains(normalizedQuery) }
        }
    }

    func exportBackupPayload() throws -> Data {
        try BackupService.encodeBackup(data: data)
    }

    func exportCSVPayload() -> Data {
        BackupService.exportCSV(data: data)
    }

    func importBackupPayload(_ payload: Data) throws {
        let imported = try BackupService.decodeBackup(from: payload)
        data = imported
        normalizeAfterImport()
        persist()
        startNightscoutPolling()
    }

    func importLatestAutoBackup() throws -> Bool {
        guard let latestURL = BackupService.latestBackupURL(baseDirectory: baseDirectory) else {
            return false
        }
        let payload = try Data(contentsOf: latestURL)
        let imported = try BackupService.decodeBackup(from: payload)
        data = imported
        normalizeAfterImport()
        persist()
        startNightscoutPolling()
        return true
    }

    func latestAutoBackupDate() -> Date? {
        guard let latestURL = BackupService.latestBackupURL(baseDirectory: baseDirectory) else {
            return nil
        }
        let values = try? latestURL.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    func createAutoBackupIfNeeded() {
        BackupService.createAutoBackupIfNeeded(data: data, baseDirectory: baseDirectory)
    }

    func refreshNightscoutNow() {
        Task {
            await refreshNightscout()
        }
    }

    private func refreshNightscout() async {
        guard let profile,
              let rawURL = profile.nightscoutURL,
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nightscoutState = .idle
            return
        }

        nightscoutState = .loading
        if let entry = await NightscoutService.latestGlucose(baseURL: rawURL, token: profile.nightscoutToken) {
            nightscoutState = .success(entry)
            nightscoutStatus = NightscoutStatus(
                lastSuccessAt: Date(),
                lastErrorAt: nil,
                lastErrorMessage: nil,
                consecutiveFailures: 0
            )
        } else {
            nightscoutState = .error("No se pudo conectar con Nightscout")
            nightscoutStatus = NightscoutStatus(
                lastSuccessAt: nightscoutStatus.lastSuccessAt,
                lastErrorAt: Date(),
                lastErrorMessage: "No se pudo conectar con Nightscout",
                consecutiveFailures: nightscoutStatus.consecutiveFailures + 1
            )
        }
    }

    private func startNightscoutPolling() {
        nightscoutTask?.cancel()

        guard let profile,
              let rawURL = profile.nightscoutURL,
              !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nightscoutState = .idle
            return
        }

        nightscoutTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshNightscout()
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: dataFileURL.path) else {
            data = .empty
            return
        }

        do {
            let rawData = try Data(contentsOf: dataFileURL)
            let decoder = makeDecoder()
            data = try decoder.decode(AppDataStore.self, from: rawData)
            normalizeAfterImport()
        } catch {
            data = .empty
        }
    }

    private func seedFoodsIfNeeded() {
        let seedFoods = CSVFoodSeeder.loadFoodsFromBundle()
        let merged = CSVFoodSeeder.mergeSeedData(existing: data.foods, seed: seedFoods)
        if merged != data.foods {
            data.foods = merged
            persist()
        }
    }

    private func normalizeAfterImport() {
        data.foods.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        data.meals.sort { $0.date > $1.date }
        data.templates.sort { $0.createdAt > $1.createdAt }

        let foodIDs = Set(data.foods.map(\.id))
        let mealIDs = Set(data.meals.map(\.id))
        let templateIDs = Set(data.templates.map(\.id))

        data.mealItems = data.mealItems.filter { mealIDs.contains($0.mealID) && foodIDs.contains($0.foodID) }
        data.templateItems = data.templateItems.filter { templateIDs.contains($0.templateID) && foodIDs.contains($0.foodID) }
        data.pendingGlucose = data.pendingGlucose.filter { mealIDs.contains($0.mealID) }
    }

    private func persist() {
        do {
            let encoder = makeEncoder()
            let payload = try encoder.encode(data)
            try payload.write(to: dataFileURL, options: [.atomic])
        } catch {
            // Persistencia best-effort
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private func formatGrams(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func buildDailyGoalAlert(afterAdding calculation: CurrentCalculation) -> String? {
        guard let profile else { return nil }

        let start = DateUtils.startOfToday()
        let end = DateUtils.endOfToday()
        let todayMeals = data.meals.filter { $0.date >= start && $0.date <= end }

        let carbsTotal = todayMeals.reduce(0) { $0 + $1.totalCarbs } + calculation.totalCarbs
        let rationsTotal = todayMeals.reduce(0) { $0 + $1.rations } + calculation.rations
        let insulinTotal = todayMeals.reduce(0) { $0 + $1.insulinUnits } + calculation.insulinUnits

        var messages: [String] = []

        if let target = profile.dailyCarbsGoal, target > 0, carbsTotal > target {
            messages.append("Hidratos diarios superados (\(format1(carbsTotal)) g / \(format1(target)) g)")
        }

        if let target = profile.dailyRationsGoal, target > 0, rationsTotal > target {
            messages.append("Raciones diarias superadas (\(format1(rationsTotal)) / \(format1(target)))")
        }

        if let target = profile.dailyInsulinGoal, target > 0, insulinTotal > target {
            messages.append("Insulina diaria superada (\(format1(insulinTotal)) U / \(format1(target)) U)")
        }

        return messages.isEmpty ? nil : messages.joined(separator: " · ")
    }

    private func format1(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func matchesDayFilter(_ date: Date, dayFilter: HistoryDayFilter, calendar: Calendar) -> Bool {
        if dayFilter == .all {
            return true
        }

        let todayStart = calendar.startOfDay(for: Date())
        let oneDay: TimeInterval = 24 * 60 * 60

        let range: (Date, Date)
        switch dayFilter {
        case .all:
            range = (.distantPast, .distantFuture)
        case .today:
            range = (todayStart, todayStart.addingTimeInterval(oneDay - 1))
        case .yesterday:
            let start = todayStart.addingTimeInterval(-oneDay)
            range = (start, start.addingTimeInterval(oneDay - 1))
        case .last7Days:
            let start = todayStart.addingTimeInterval(-6 * oneDay)
            range = (start, todayStart.addingTimeInterval(oneDay - 1))
        case .last30Days:
            let start = todayStart.addingTimeInterval(-29 * oneDay)
            range = (start, todayStart.addingTimeInterval(oneDay - 1))
        }

        return date >= range.0 && date <= range.1
    }
}
