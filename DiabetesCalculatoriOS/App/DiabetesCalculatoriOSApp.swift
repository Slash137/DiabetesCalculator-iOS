import SwiftUI

@main
struct DiabetesCalculatoriOSApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .background {
                store.createAutoBackupIfNeeded()
            }
        }
    }
}
