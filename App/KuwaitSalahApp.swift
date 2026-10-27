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
    @StateObject private var notes = NotesStore()
    @StateObject private var locator = LocationHelper()
    @Environment(\.scenePhase) private var phase

    private func setupLocator() {
        locator.onKuwait = { r in
            if store.prefs.regionID != r.id { store.prefs.regionID = r.id }
            if store.prefs.place != nil { store.prefs.place = nil }
        }
        locator.onPlace = { p in
            // لا نغيّر إلا إذا تحرّك المستخدم أكثر من ٥ كم (لتفادي إعادة جدولة الإشعارات بلا داعٍ)
            if let old = store.prefs.place,
               old.tz == p.tz,
               Region.distanceKm(old.lat, old.lng, p.lat, p.lng) < 5 { return }
            store.prefs.place = p
        }
        if store.prefs.locMode == 0 { locator.detect(force: false) }
    }

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
                .environmentObject(notes)
                .environmentObject(locator)
                .onAppear { setupLocator() }
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(store.colorScheme)
                .tint(Theme.accent)
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active {
                        if store.prefs.locMode == 0 { locator.detect(force: false) }
                        store.refreshNotifications()
                        LiveActivityManager.sync(region: store.region, calc: store.calc)
                    }
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
