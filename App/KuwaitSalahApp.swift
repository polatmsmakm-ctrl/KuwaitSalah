import SwiftUI

@main
struct KuwaitSalahApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .tint(Color(red: 0.05, green: 0.45, blue: 0.35))
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active { store.refreshNotifications() }
                }
                .onChange(of: store.prefs) { _, _ in
                    store.refreshNotifications()
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("الأوقات", systemImage: "clock") }
            MosquesView()
                .tabItem { Label("المساجد", systemImage: "building.columns") }
            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape") }
        }
    }
}
