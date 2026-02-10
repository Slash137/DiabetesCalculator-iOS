import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore

    @State private var name = ""
    @State private var gramsPerRation = "10"
    @State private var insulinRatio = "1.0"
    @State private var dailyCarbsGoal = ""
    @State private var dailyRationsGoal = ""
    @State private var dailyInsulinGoal = ""
    @State private var reminder2hEnabled = false
    @State private var nightscoutURL = ""
    @State private var nightscoutToken = ""

    @State private var showMessage = false
    @State private var message = ""

    @State private var exportBackupDocument: BackupJSONDocument?
    @State private var exportCSVDocument: CSVExportDocument?
    @State private var showExportBackup = false
    @State private var showExportCSV = false
    @State private var showImportBackup = false

    var body: some View {
        Form {
            profileSection
            goalsSection
            reminderSection
            nightscoutSection
            backupSection
            MedicalNoticeView()
                .listRowBackground(Color.clear)
        }
        .onAppear {
            loadProfileIntoFields()
        }
        .fileExporter(
            isPresented: $showExportBackup,
            document: exportBackupDocument,
            contentType: .json,
            defaultFilename: backupFileName
        ) { result in
            switch result {
            case .success:
                showInfo("Backup exportado correctamente")
            case .failure(let error):
                showInfo("Error al exportar backup: \(error.localizedDescription)")
            }
        }
        .fileExporter(
            isPresented: $showExportCSV,
            document: exportCSVDocument,
            contentType: .commaSeparatedText,
            defaultFilename: csvFileName
        ) { result in
            switch result {
            case .success:
                showInfo("CSV exportado correctamente")
            case .failure(let error):
                showInfo("Error al exportar CSV: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showImportBackup,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let payload = try Data(contentsOf: url)
                    try store.importBackupPayload(payload)
                    loadProfileIntoFields()
                    showInfo("Backup importado correctamente")
                } catch {
                    showInfo("Error al importar backup: \(error.localizedDescription)")
                }
            case .failure(let error):
                showInfo("Error al abrir archivo: \(error.localizedDescription)")
            }
        }
        .alert("Perfil", isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private var profileSection: some View {
        Section("Perfil") {
            TextField("Nombre", text: $name)
            TextField("Gramos por racion", text: decimalBinding($gramsPerRation))
                .keyboardType(.decimalPad)
            TextField("Ratio insulina/racion", text: decimalBinding($insulinRatio))
                .keyboardType(.decimalPad)

            Button("Guardar perfil") {
                saveProfile()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private var goalsSection: some View {
        Section("Objetivos diarios") {
            TextField("Hidratos (g)", text: decimalBinding($dailyCarbsGoal))
                .keyboardType(.decimalPad)
            TextField("Raciones", text: decimalBinding($dailyRationsGoal))
                .keyboardType(.decimalPad)
            TextField("Insulina (U)", text: decimalBinding($dailyInsulinGoal))
                .keyboardType(.decimalPad)
        }
    }

    private var reminderSection: some View {
        Section("Recordatorio") {
            Toggle("Aviso manual a las 2h", isOn: $reminder2hEnabled)
            Text("Se programa una notificacion local 2 horas despues de guardar la comida.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var nightscoutSection: some View {
        Section("Nightscout") {
            TextField("URL de Nightscout", text: $nightscoutURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            TextField("Token (opcional)", text: $nightscoutToken)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            HStack {
                Button("Refrescar glucosa") {
                    store.refreshNightscoutNow()
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            switch store.nightscoutState {
            case .idle:
                Text("Nightscout no configurado")
                    .foregroundStyle(.secondary)
            case .loading:
                HStack {
                    ProgressView()
                    Text("Actualizando glucosa...")
                        .foregroundStyle(.secondary)
                }
            case .error(let error):
                Text(error)
                    .foregroundStyle(.red)
            case .success(let entry):
                let arrow = NightscoutService.trendArrow(entry.direction)
                Text("\(entry.sgv) mg/dL \(arrow)")
                    .foregroundStyle(.teal)
            }

            if !store.pendingGlucoseTasks.isEmpty {
                Text("Pendientes Nightscout: \(store.pendingGlucoseTasks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Backoff estimado: \(NightscoutRetryPolicy.nextDelayMinutes(for: store.pendingMaxAttempts)) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backupSection: some View {
        Section("Copias de seguridad") {
            Button("Exportar backup JSON") {
                do {
                    exportBackupDocument = try BackupJSONDocument(data: store.exportBackupPayload())
                    showExportBackup = true
                } catch {
                    showInfo("Error al crear backup: \(error.localizedDescription)")
                }
            }

            Button("Importar backup JSON") {
                showImportBackup = true
            }

            Button("Exportar CSV") {
                exportCSVDocument = CSVExportDocument(data: store.exportCSVPayload())
                showExportCSV = true
            }

            Button("Importar ultima copia automatica") {
                do {
                    let imported = try store.importLatestAutoBackup()
                    if imported {
                        loadProfileIntoFields()
                        showInfo("Ultima copia automatica importada")
                    } else {
                        showInfo("No hay copias automaticas disponibles")
                    }
                } catch {
                    showInfo("Error al importar copia automatica: \(error.localizedDescription)")
                }
            }

            if let lastDate = store.latestAutoBackupDate() {
                Text("Ultima copia automatica: \(DateUtils.formatDateTime(lastDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ultima copia automatica: —")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "diabetes_backup_\(formatter.string(from: Date()))"
    }

    private var csvFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return "diabetes_export_\(formatter.string(from: Date()))"
    }

    private func loadProfileIntoFields() {
        let profile = store.profile ?? .default

        name = profile.name
        gramsPerRation = AppFormatters.one(profile.gramsPerRation)
        insulinRatio = AppFormatters.one(profile.insulinRatio)
        dailyCarbsGoal = profile.dailyCarbsGoal.map(AppFormatters.one) ?? ""
        dailyRationsGoal = profile.dailyRationsGoal.map(AppFormatters.one) ?? ""
        dailyInsulinGoal = profile.dailyInsulinGoal.map(AppFormatters.one) ?? ""
        reminder2hEnabled = profile.reminder2hEnabled
        nightscoutURL = profile.nightscoutURL ?? ""
        nightscoutToken = profile.nightscoutToken ?? ""
    }

    private func saveProfile() {
        guard let grams = gramsPerRation.parsedDecimal, grams > 0,
              let ratio = insulinRatio.parsedDecimal, ratio > 0,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showInfo("Completa nombre, gramos por racion y ratio con valores validos")
            return
        }

        let goals = [dailyCarbsGoal.parsedDecimal, dailyRationsGoal.parsedDecimal, dailyInsulinGoal.parsedDecimal]
        if goals.contains(where: { value in
            if let value {
                return value < 0
            }
            return false
        }) {
            showInfo("Los objetivos no pueden ser negativos")
            return
        }

        let existing = store.profile
        let profile = UserProfile(
            id: existing?.id ?? 1,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gramsPerRation: grams,
            insulinRatio: ratio,
            dailyCarbsGoal: dailyCarbsGoal.parsedDecimal,
            dailyRationsGoal: dailyRationsGoal.parsedDecimal,
            dailyInsulinGoal: dailyInsulinGoal.parsedDecimal,
            reminder2hEnabled: reminder2hEnabled,
            nightscoutURL: nightscoutURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : nightscoutURL.trimmingCharacters(in: .whitespacesAndNewlines),
            nightscoutToken: nightscoutToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : nightscoutToken.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? Date()
        )

        store.saveProfile(profile)
        showInfo("Perfil guardado")
    }

    private func decimalBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { newValue in
                if newValue.isEmpty || newValue.range(of: "^\\d*([\\.,]\\d*)?$", options: .regularExpression) != nil {
                    source.wrappedValue = newValue
                }
            }
        )
    }

    private func showInfo(_ text: String) {
        message = text
        showMessage = true
    }
}
