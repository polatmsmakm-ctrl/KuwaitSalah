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
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
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
                .tabItem { Label("الأوقات", systemImage: "clock.fill") }
            QiblaView()
                .tabItem { Label("القبلة", systemImage: "location.north.circle.fill") }
            TimetableView()
                .tabItem { Label("الشهر", systemImage: "calendar") }
            TasbihView()
                .tabItem { Label("التسبيح", systemImage: "circle.hexagongrid.fill") }
            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
