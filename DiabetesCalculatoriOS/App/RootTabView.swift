import SwiftUI

enum AppTab: Hashable {
    case newMeal
    case history
    case foods
    case profile
}

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab: AppTab = .newMeal
    @State private var showStats = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NewMealView(selectedTab: $selectedTab)
                    .navigationTitle("Nueva")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showStats = true
                            } label: {
                                Image(systemName: "chart.bar.xaxis")
                            }
                            .accessibilityLabel("Abrir estadisticas")
                        }
                    }
            }
            .tabItem {
                Label("Nueva", systemImage: "plus.circle")
            }
            .tag(AppTab.newMeal)

            NavigationStack {
                HistoryView()
                    .navigationTitle("Historial")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showStats = true
                            } label: {
                                Image(systemName: "chart.bar.xaxis")
                            }
                            .accessibilityLabel("Abrir estadisticas")
                        }
                    }
            }
            .tabItem {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)

            NavigationStack {
                FoodsView()
                    .navigationTitle("Alimentos")
            }
            .tabItem {
                Label("Alimentos", systemImage: "fork.knife")
            }
            .tag(AppTab.foods)

            NavigationStack {
                ProfileView()
                    .navigationTitle("Perfil")
            }
            .tabItem {
                Label("Perfil", systemImage: "person")
            }
            .tag(AppTab.profile)
        }
        .sheet(isPresented: $showStats) {
            NavigationStack {
                StatsView()
                    .navigationTitle("Estadisticas")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cerrar") {
                                showStats = false
                            }
                        }
                    }
            }
        }
    }
}
