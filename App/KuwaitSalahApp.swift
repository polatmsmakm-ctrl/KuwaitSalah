import SwiftUI

@main
struct KuwaitSalahApp: App {
    @StateObject private var store = Store()
    @StateObject private var quran = QuranStore()
    @StateObject private var adhkar = AdhkarStore()
    @StateObject private var hadith = HadithStore()
    @StateObject private var mushaf = MushafModel()
    @StateObject private var player = RecitationPlayer.shared
    @StateObject private var wird = WirdStore()
    @StateObject private var memo = MemoStore()
    @StateObject private var offline = OfflineStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(quran)
                .environmentObject(adhkar)
                .environmentObject(hadith)
                .environmentObject(mushaf)
                .environmentObject(player)
                .environmentObject(wird)
                .environmentObject(memo)
                .environmentObject(offline)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(store.colorScheme)
                .tint(Theme.accent)
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
    @EnvironmentObject var store: Store

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView()
                .tabItem { Label("الأوقات", systemImage: "clock.fill") }
                .tag(0)
            QuranHomeView()
                .tabItem { Label("القرآن", systemImage: "book.fill") }
                .tag(1)
            AdhkarTab()
                .tabItem { Label("الأذكار", systemImage: "sparkles") }
                .tag(2)
            QiblaView()
                .tabItem { Label("القبلة", systemImage: "location.north.circle.fill") }
                .tag(3)
            MoreView()
                .tabItem { Label("المزيد", systemImage: "ellipsis.circle.fill") }
                .tag(4)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
